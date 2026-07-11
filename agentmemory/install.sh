#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$HOME/.config/opencode/opencode.json"

if [ ! -f "$CONFIG_FILE" ]; then
    CONFIG_FILE="$HOME/.config/opencode/opencode.jsonc"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Error: $CONFIG_FILE not found"
        exit 1
    fi
fi

# 1. append mcp config for agentmemory
if ! grep -q '"agentmemory"' <<< "$(jq '.mcp // empty' "$CONFIG_FILE")" 2>/dev/null; then
    if command -v jq &>/dev/null; then
        jq '.mcp.agentmemory = {"type": "local", "command": ["npx", "-y", "@agentmemory/mcp"], "enabled": true}' \
            "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"
        mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    fi
fi

# 2. append plugin entry for agentmemory-capture.ts
if ! grep -q 'agentmemory-capture' "$CONFIG_FILE" 2>/dev/null; then
    if command -v jq &>/dev/null; then
        jq '.plugin += ["./plugins/agentmemory-capture.ts"]' \
            "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"
        mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    fi
fi

# 3. copy files
mkdir -p "$HOME/.config/opencode/plugins"
mkdir -p "$HOME/.config/opencode/commands"
mkdir -p "$HOME/.agentmemory"

cp "$SCRIPT_DIR/preferences.json" "$HOME/.agentmemory/"
cp "$SCRIPT_DIR/agentmemory-capture.ts" "$HOME/.config/opencode/plugins/"
cp "$SCRIPT_DIR/commands/"*.md "$HOME/.config/opencode/commands/" 2>/dev/null || true

echo "agentmemory install complete"

echo "配置文件：~/.agentmemory/.env"
echo "启动自动注入：AGENTMEMORY_INJECT_CONTEXT=true"
echo "启动知识图谱： GRAPH_EXTRACTION_ENABLED=true"
echo "启用记忆合并： CONSOLIDATION_ENABLED=true + LLM API Key"
echo "启动自动遗忘： LLM API Key"

