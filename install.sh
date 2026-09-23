#!/bin/bash

CONFIG_DIR="$HOME/.config/opencode"
CONFIG_FILE="$CONFIG_DIR/opencode.json"
if [ ! -f "$CONFIG_FILE" ]; then
    mkdir -p "$(dirname "$CONFIG_FILE")"
    cat > "$CONFIG_FILE" << 'EOF'
{
  "$schema": "https://opencode.ai/config.json"
}
EOF
fi

function rsync_developer_config()
{
    echo "rsync oac developer config to $1"

    if [ ! -d "$1" ]; then
        echo "$1 does not exist"
        exit 1
    fi

    # 判断 $1 是否以 .opencode 结尾
    if [[ "$1" == *.opencode ]]; then
        target="$1"
    else
        target="$1/.opencode"
        mkdir -p "$target"
    fi

    rsync -av  --exclude='README.md' \
               --exclude='env.example' \
               --exclude='config' \
               --exclude='command/clean.md' \
               --exclude='command/test.md' \
               --exclude='command/validate-repo.md' \
               --exclude='command/openagents' \
               --exclude='agent/subagents/development' \
               --exclude='context/development' \
               --exclude='context/openagents-repo' \
               --exclude='context/ui' \
               --exclude='context/core/visual-development.md' \
               --exclude='context/core/workflows/design-iteration*' \
               .opencode/ "$target"

    if [ ! -f "$target/.env" ]; then
        cp .opencode/env.example "$target/.env"
    fi
}

function omniroute_provider_config()
{
    # chunkTimeout：SSEchunk之间的最大等待时间（应对OmniRoute冷启动时的长延迟）
    # headerTimeout：响应头等待时间
    # timeout：整体请求超时时间
    if ! jq -e '.provider.omniroute' "$CONFIG_FILE" >/dev/null 2>&1; then
        jq '.provider.omniroute = {
            "npm": "@ai-sdk/openai-compatible",
            "name": "OmniRoute",
            "options": {
              "baseURL": "http://localhost:20128/v1",
              "apiKey": "{env:OMNIROUTE_API_KEY}",
              "timeout": 120000,
              "headerTimeout": 30000,
              "chunkTimeout": 60000
            },
            "models": {
              "auto": {
                "name": "Auto Combo"
              },
              "auto/best-coding": {
                "name": "Auto Best Coding",
                "tool_call": true,
                "reasoning": true,
                "attachment": true,
                "temperature": true,
                "interleaved": true,
                "limit": {
                  "context": 200000(200k) or 1000000(1M)
                  "output": 60000(200k) or 300000(1M)
                },
                "modalities": {
                  "input": ["text", "pdf", "image"],
                  "output": ["text"]
                }
              }
            }
        }' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"
        mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
        echo "Added omniroute provider with auto model to $CONFIG_FILE"
    fi
    read -p "Do you want to configure omniroute MCP server? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if ! jq -e '.mcp.omniroute' "$CONFIG_FILE" >/dev/null 2>&1; then
            jq '.mcp.omniroute = {
                "type": "remote",
                "url": "http://localhost:20128/api/mcp/sse",
                "headers": {
                    "Authorization": "Bearer omniroute_management_key"
                },
                "enabled": false
            }' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"
            mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
            echo "Added omniroute MCP server to $CONFIG_FILE"
        else
            echo "omniroute MCP server already configured, skipping."
        fi
    fi
    echo ""
    echo "Config file: /usr/lib/node_modules/omniroute/.env"
    echo "  Enable API auth:    REQUIRE_API_KEY=true"
    echo "  Reveal full API key: ALLOW_API_KEY_REVEAL=true"
    echo "  Login password: INITIAL_PASSWORD=CHANGEME"
    echo "  Daily request limit: DEFAULT_RATE_LIMIT_PER_DAY=1000"
    echo ""
}

function export_env()
{
    local var_name=$1
    local var_value=$2
    local env_file=$HOME/.profile

    # skip if the variable is already set in the current environment
    if [ -n "${!var_name}" ]; then
        return 0
    fi

    # skip if the variable already exists in $HOME/.profile
    if [ -f "$env_file" ] && grep -q "^export $var_name=" "$env_file"; then
        return 0
    fi

    echo "export $var_name=$var_value" >> "$env_file"
    echo "Added export $var_name=$var_value to $env_file"
}

function default_config_install()
{
    # remove plugin cache
    rm -rf $HOME/.cache/opencode/packages/*
    if [ "$PWD" != "$HOME/.opencode" ]; then
        echo "Install global config to $CONFIG_DIR"
        rsync -av  --include='tui.json' \
            --include='opencode.jsonc' \
            --include='dcp.jsonc' \
            --include='agents' \
            --include='commands' \
            --include='rules' \
            --include='skills' \
            --include='codebase_memory' \
            --exclude='*' ./  $CONFIG_DIR
    else
        rm -rf "$CONFIG_DIR/dcp.jsonc"
        ln -s "$PWD/dcp.jsonc" "$CONFIG_DIR/dcp.jsonc"
        rm -rf "$CONFIG_DIR/rules"
        ln -s "$PWD/rules" "$CONFIG_DIR/rules"
        rm -rf "$CONFIG_DIR/codebase_memory"
        ln -s "$PWD/codebase_memory" "$CONFIG_DIR/codebase_memory"
    fi

    export_env EDITOR vim
    # Disable all .claude support
    export_env OPENCODE_DISABLE_CLAUDE_CODE true
    # Disable only ~/.claude/CLAUDE.md
    #export_env OPENCODE_DISABLE_CLAUDE_CODE_PROMPT true
    # Disable only .claude/skills
    #export_env OPENCODE_DISABLE_CLAUDE_CODE_SKILLS true
    # Enable .agents/skills
    export_env OPENCODE_DISABLE_EXTERNAL_SKILLS false

    echo "Install skills to $HOME/.agents/skills"
    # npx skills add Option         Description
    # -g, --global                  Install to user directory instead of project
    # -a, --agent <agents...>       Target specific agents (e.g., claude-code, codex). See Available Agents
    # -s, --skill <skills...>       Install specific skills by name (use '*' for all skills)
    # -l, --list                    List available skills without installing
    # --copy                        Copy files instead of symlinking to agent directories
    # -y, --yes	                    Skip all confirmation prompts
    # --all	                        Install all skills to all agents without prompts

    # GitHub shorthand (owner/repo)
    npx skills add vercel-labs/skills -g -y --skill find-skills --agent opencode
    #npx skills add https://github.com/cathrynlavery/diagram-design --skill diagram-design  --agent opencode
    #npx skills add kepano/obsidian-skills -g -y --agent opencode
    #npx skills update
}

function main()
{
    if ! command -v opencode >/dev/null 2>&1; then
        read -p "opencode is not installed. Do you want to install it? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Install opencode"
            if command -v node >/dev/null 2>&1; then
                sudo npm install -g opencode-ai
            else
                curl -fsSL https://opencode.ai/install | bash
            fi
        else
            echo "Skip opencode installation"
        fi
    fi

    if ! command -v jq &>/dev/null; then
        echo "Install jq..."
        if command -v apt-get &>/dev/null; then
            sudo apt-get install -y jq
        elif command -v yum &>/dev/null; then
            sudo yum install -y jq
        elif command -v pacman &>/dev/null; then
            sudo pacman -S jq
        elif command -v brew &>/dev/null; then
            brew install jq
        else
            echo "Cannot install jq: no supported package manager found"
        fi
    fi

    case "$1" in
    --oac )
        echo "Install OpenAgentsControl developer..."
        curl -fsSL https://raw.githubusercontent.com/darrenhinde/OpenAgentsControl/main/install.sh | bash -s developer
        if [ -d .opencode ]; then
            rsync_developer_config "${2:-$CONFIG_DIR}"
            rm .opencode
        fi
        ;;
    --rtk )
        echo "Install rtk..."
        curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
        sudo mv $HOME/.local/bin/rtk /usr/local/bin/
        sudo chown root:root /usr/local/bin/rtk
        sudo chmod 777 /usr/local/bin/rtk
        rtk init -g --opencode
        ;;
    --codebase-memory )
        echo "Install codebase-memory-mcp..."
        curl -fsSL https://raw.githubusercontent.com/DeusData/codebase-memory-mcp/main/install.sh | bash
        sudo mv $HOME/.local/bin/codebase-memory-mcp /usr/local/bin/
        sudo chown root:root /usr/local/bin/codebase-memory-mcp
        sudo chmod 777 /usr/local/bin/codebase-memory-mcp
        if jq -e '.mcp."codebase-memory-mcp"' "$CONFIG_FILE" >/dev/null 2>&1; then
            jq 'del(.mcp."codebase-memory-mcp")' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"
            mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
            mv -f $CONFIG_DIR/AGENTS.md $CONFIG_DIR/codebase_memory/
            mv -f $CONFIG_DIR/skills/codebase-memory $CONFIG_DIR/codebase_memory/skills/
            mv -f $CONFIG_DIR/agents/codebase-memory* $CONFIG_DIR/codebase_memory/agents/
            mv -f $CONFIG_DIR/plugins/cbm-augment.ts $CONFIG_DIR/codebase_memory/plugins/
            echo "Removed codebase-memory-mcp config from $CONFIG_FILE"
        fi
        ;;
    --markitdown )
        echo "Install markitdown docker..."
        git clone https://github.com/microsoft/markitdown
        cd markitdown
        docker build -t markitdown:latest .
        cd -
        rm -rf markitdown
        ;;
    --drawio )
        npx skills add tt-a1i/archify -g -y --skill archify --agent opencode
        echo "Install drawio desktop and skill..."
        npx skills add Agents365-ai/drawio-skill -g -y --skill drawio-skill --agent opencode
        sudo apt-get install xvfb
        sudo snap install drawio
        ;;
    --comet )
        echo "Install openspec and supperpowers for project..."
        sudo npm install -g @rpamis/comet@latest
        sudo npm install -g @fission-ai/openspec@latest
        echo "cd project directory and run: comet init"
        ;;
    --graphify )
        echo "Install graphify..."
        # base Python 3.10+
        if python3 -c 'import sys; sys.exit(0 if sys.version_info > (3, 9) else 1)'; then
            pip install graphifyy
        else
            if ! command -v uv >/dev/null 2>&1; then
                curl -LsSf https://astral.sh/uv/install.sh | sh
            fi
            # use uv env
            uv tool install --python 3.11 graphifyy
        fi
        ;;
    --cua )
        echo "Install computer use agent..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/trycua/cua/main/libs/cua-driver/scripts/install.sh)"
        if command -v cua-driver >/dev/null 2>&1; then
            cua-driver mcp-config --client opencode
        fi
        ;;
    --caveman )
        echo "Install caveman..."
        npx -y github:JuliusBrussee/caveman -- --only opencode
        if ! grep -q '"cavecrew-builder"' "$CONFIG_FILE" 2>/dev/null; then
            jq '.agent["cavecrew-builder"] = {"mode": "subagent"} |
                .agent["cavecrew-investigator"] = {"mode": "subagent"} |
                .agent["cavecrew-reviewer"] = {"mode": "subagent"}' \
            "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"
            mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
        fi
        ;;
    --agentmemory )
        echo "Install agentmemory..."
        sudo npm install -g @agentmemory/agentmemory
        curl -fsSL https://install.iii.dev/iii/main/install.sh | VERSION=0.11.2 sh
        npx git-ripper https://github.com/rohitg00/agentmemory/tree/main/plugin/opencode -o ./agentmemory
        ./agentmemory/install.sh
        ;;
    --omniroute )
        echo "Install omniroute..."
        sudo npm install -g omniroute
        if command -v omniroute >/dev/null 2>&1; then
            #omniroute setup opencode
            # use config provider instead of plugin
            omniroute_provider_config
        fi
        ;;
    --ocr )
        echo "Install open-code-review..."
        sudo npm install -g @alibaba-group/open-code-review
        if command -v ocr >/dev/null 2>&1; then
            curl -fsSL \
                https://raw.githubusercontent.com/alibaba/open-code-review/main/plugins/open-code-review/opencode/open-code-review.ts \
                -o $CONFIG_DIR/plugins/open-code-review.ts
            ocr config provider          # 选择内置供应商或添加自定义供应商
            ocr config model             # 为当前供应商选择模型
            ocr llm test                 # 测试连通性
        fi
        ;;
    --omo )
        echo "Install oh-my-openagent..."
        mkdir -p "$HOME/.omo"
        cp omo.jsonc "$HOME/.omo"
        if ! command -v bunx >/dev/null 2>&1; then
            sudo npm install -g bun
        fi
        mv  $CONFIG_FILE $CONFIG_DIR/opencode.json.backup
        bunx oh-my-openagent install
        mv $CONFIG_DIR/opencode.json.backup $CONFIG_FILE
        rm $HOME/.omo/omo.jsonc.bak* -rf
        rm $CONFIG_DIR/opencode.json.backup* -rf
        export_env LSP_TOOLS_MCP_USER_CONFIG "$HOME/.config/opencode/lsp-client.json"
        ;;
    --officecli )
        echo "Install officecli..."
        sudo apt-get update && sudo apt-get install -y libicu-dev
        sudo npm install -g @officecli/officecli
        if command -v officecli >/dev/null 2>&1; then
            officecli install opencode
        fi
        ;;
    --book-to-skill )
        echo "Install book-to-skill..."
        npx skills add virgiliojr94/book-to-skill -g -y --skill book-to-skill --agent opencode
        if python3 -c 'import sys; sys.exit(0 if sys.version_info > (3, 9) else 1)'; then
            pip install --break-system-packages pypdf docling
        else
            if ! command -v uv >/dev/null 2>&1; then
                curl -LsSf https://astral.sh/uv/install.sh | sh
            fi
            # use uv env
            uv tool install --python 3.11 docling --with pypdf
        fi
        ;;
    --help )
        echo ""
        echo "options:"
        echo "--oac: install OpenAgentsControl for specific project"
        echo "--ocr: install open-code-review, use for review code"
        echo "--omo: install oh-my-openagent, use multi-model agent for coding"
        echo "--rtk: install rtk, use for command output compact"
        echo "--codebase-memory: install codebase-memory-mcp, use for code graph"
        echo "--markitdown: install markitdown docker, use for translate file to markdown"
        echo "--drawio: install drawio, use for draw diagram"
        echo "--comet: install comet, use for comet openspec and superpowers"
        echo "--graphify: install graphify, use for drawing code knowledge maps"
        echo "--cua: install cua-driver, use for drive native desktop apps in the background"
        echo "--caveman: install caveman, use for save token, similar tool ponytail"
        echo "--agentmemory: install agentmemory, use for agent memory"
        echo "--omniroute: install omniroute, use for llm proxy"
        echo "--officecli: instll officecli, use for handle docx, xlsx, pptx document"
        echo "--book-to-skill: install book-to-skill, use for convert book to skill"
        ;;
    * )
        default_config_install
        ;;
    esac
}
# 调用main函数
main "$@"
