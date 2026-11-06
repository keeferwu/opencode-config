#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$HOME/.config/opencode/opencode.json"

if [ ! -f "$CONFIG_FILE" ]; then
    mkdir -p "$(dirname "$CONFIG_FILE")"
    cat > "$CONFIG_FILE" << 'EOF'
{
  "$schema": "https://opencode.ai/config.json"
}
EOF
    echo "Created $CONFIG_FILE"
fi

# 1. set mcp config for agentmemory
if ! jq -e '.mcp.servers.agentmemory' "$CONFIG_FILE" >/dev/null 2>&1; then
    if command -v jq &>/dev/null; then
        STANDALONE_MJS="/usr/lib/node_modules/@agentmemory/agentmemory/dist/standalone.mjs"
        if [ ! -f "$STANDALONE_MJS" ]; then
            jq '.mcp.servers.agentmemory = {"type": "local", "command": ["npx", "-y", "@agentmemory/mcp"], "disabled": false}' \
                "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"
        else
            #use global standalone.mjs instead of npx, because npx cache slowly
            jq --arg mjs "$STANDALONE_MJS" \
            '.mcp.servers.agentmemory = {"type": "local", "command": ["node", $mjs], "environment": {"AGENTMEMORY_URL": "http://localhost:3111", "AGENTMEMORY_TOOLS": "core"}, "disabled": false}' \
                "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"
        fi
        mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    fi
fi

# 2. append plugin entry for agentmemory-capture.ts
#if ! grep -q 'agentmemory-capture' "$CONFIG_FILE" 2>/dev/null; then
#    if command -v jq &>/dev/null; then
#        jq '.plugins += ["./plugins/agentmemory-capture.ts"]' \
#            "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"
#        mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
#    fi
#fi

# 3. copy files
mkdir -p "$HOME/.config/opencode/plugins"
mkdir -p "$HOME/.config/opencode/commands"
mkdir -p "$HOME/.agentmemory"

cp "$SCRIPT_DIR/preferences.json" "$HOME/.agentmemory/"
cp "$SCRIPT_DIR/agentmemory-capture.ts" "$HOME/.config/opencode/plugins/"
cp "$SCRIPT_DIR/commands/"*.md "$HOME/.config/opencode/commands/" 2>/dev/null || true

# 4. install systemd service for auto-start
AGENTMEMORY_BIN="$(command -v agentmemory 2>/dev/null)"
III_BIN="$HOME/.agentmemory/bin/iii"
SERVICE_FILE="/etc/systemd/system/agentmemory.service"

if [ ! -x "$AGENTMEMORY_BIN" ]; then
    echo "Please install agentmemory first: sudo npm install -g @agentmemory/agentmemory"
    exit 1
fi

if [ ! -f "$III_BIN" ]; then
    read -p "If you only want to use a shared agentmemory server, no iii install. [Y/n] " ch
    ch=${ch:-Y} # 如果用户直接按回车，则使用默认值 'Y'
    if [[ $ch =~ ^[Yy]$ ]]; then
        CLI=/usr/lib/node_modules/@agentmemory/agentmemory/dist/cli.mjs
        VERSION=$(grep -oE 'const III_RELEASE_SHA256 = \{ "[0-9]+\.[0-9]+\.[0-9]+"' "$CLI" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        echo "agentmemory pins iii v$VERSION"
        mkdir -p ~/.agentmemory/bin
        curl -fsSL --connect-timeout 15 --max-time 300 \
          -o ~/.agentmemory/bin/iii-download.tar.gz \
          "https://ghfast.top/https://github.com/iii-hq/iii/releases/download/iii/v$VERSION/iii-x86_64-unknown-linux-gnu.tar.gz"
        cd ~/.agentmemory/bin && tar -xzf iii-download.tar.gz && rm -f iii-download.tar.gz && chmod +x iii
        ./iii --version
    fi
fi

if [ ! -f "$SERVICE_FILE" ]; then
    echo "Creating systemd service: $SERVICE_FILE"
    sudo tee "$SERVICE_FILE" > /dev/null << EOF
[Unit]
Description=AgentMemory Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$(whoami)
Group=$(id -gn)
WorkingDirectory=$HOME/.agentmemory
ExecStart=$AGENTMEMORY_BIN
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=agentmemory

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable agentmemory.service
    echo "Systemd service created and enabled"
else
    echo "Systemd service already exists: $SERVICE_FILE"
fi

# 5. start or restart agentmemory service
if systemctl is-active --quiet agentmemory.service; then
    echo "Restarting agentmemory service..."
    sudo systemctl restart agentmemory.service
else
    echo "Starting agentmemory service..."
    sudo systemctl start agentmemory.service
fi

echo ""
echo "=========================================="
echo "agentmemory install complete"
echo "=========================================="
echo ""
echo "Service status:"
systemctl is-active agentmemory.service && echo "  Status: running" || echo "  Status: stopped"
echo ""
echo "Ports:"
echo "  REST API:  http://localhost:3111"
echo "  Streams:   http://localhost:3112"
echo "  WebSocket: http://localhost:49134"
echo "  Viewer:    http://localhost:3113"
echo ""
echo "Config files: ~/.agentmemory/.env"
agentmemory init
echo "  Enable all tools:       AGENTMEMORY_TOOLS=all"
echo "  Enable slots tools:     AGENTMEMORY_SLOTS=true"
echo "  Auto context injection: AGENTMEMORY_INJECT_CONTEXT=true"
echo "  Knowledge graph:        GRAPH_EXTRACTION_ENABLED=true"
echo "  Memory consolidation:   CONSOLIDATION_ENABLED=true + LLM API Key"
echo "  Auto forgetting:        LLM API Key"
echo ""
echo "Management commands:"
echo "  systemctl status agentmemory     - check status"
echo "  sudo systemctl restart agentmemory - restart service"
echo "  journalctl -u agentmemory -f     - view logs"
echo ""
