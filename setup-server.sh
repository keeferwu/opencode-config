#!/usr/bin/env bash
set -euo pipefail

command -v opencode >/dev/null || { echo "opencode not found" >&2; exit 1; }

DEFAULT_HOST="127.0.0.1"
DEFAULT_PORT=$((4096 + $(id -u) % 200))

OPENCODE_HOST="${OPENCODE_SERVER_HOST:-$DEFAULT_HOST}"
OPENCODE_PORT="${OPENCODE_SERVER_PORT:-$DEFAULT_PORT}"

OPENCODE_BIN="$(command -v opencode)"
UNIT_FILE="$HOME/.config/systemd/user/opencode-server.service"
REG_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/opencode/service.json"

# 1. Stop existing servers so the managed service can take over cleanly.
#    - systemctl stop: 兼容旧脚本生成的前台模式 unit (serve --port ...)
#    - opencode service stop: 停掉 CLI 自动拉起的托管服务 (serve --service)
systemctl --user stop opencode-server.service 2>/dev/null || true
opencode service stop 2>/dev/null || true

# 2. Persist managed-service config. CLI 拉起的服务也读这份配置，端口保持一致
#opencode service set hostname "$OPENCODE_HOST"
#opencode service set port "$OPENCODE_PORT"
#echo "Config:   opencode service set (hostname=${OPENCODE_HOST} port=${OPENCODE_PORT})"

# 3. Install systemd unit in managed service mode
mkdir -p "$HOME/.config/systemd/user"
cat > "$UNIT_FILE" << EOF
[Unit]
Description=OpenCode Background Service (managed)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${OPENCODE_BIN} serve --service
WorkingDirectory=%h
Restart=always
RestartSec=3
Environment=HOME=%h
Environment=PATH=%h/.local/bin:/usr/local/bin:/usr/bin:/bin

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now opencode-server.service

# 4. Wait for the service to register itself, then verify discovery
for _ in $(seq 1 20); do
  [[ -f "$REG_FILE" ]] && break
  sleep 0.5
done

echo "Unit:     $UNIT_FILE"
echo "Command:  ${OPENCODE_BIN} serve --service"
echo "Register: $REG_FILE"
systemctl --user status opencode-server.service --no-pager | head -5 || true
opencode service status || true
