#!/bin/bash

CONFIG_FILE="$HOME/.config/opencode/opencode.json"
if [ ! -f "$CONFIG_FILE" ]; then
    CONFIG_FILE="$HOME/.config/opencode/opencode.jsonc"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Error: $CONFIG_FILE not found"
        exit 1
    fi
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

function default_config_install()
{
    # remove plugin cache
    rm -rf $HOME/.cache/opencode/packages/*
    if [ "$PWD" != "$HOME/.opencode" ]; then
        echo "Install global config to $HOME/.config/opencode"
        cp opencode.jsonc "$HOME/.config/opencode"
        cp tui.json "$HOME/.config/opencode"
        cp -auv agents "$HOME/.config/opencode"
        cp -auv commands "$HOME/.config/opencode"
        cp -auv rules "$HOME/.config/opencode"
        cp -auv skills "$HOME/.config/opencode"
    fi

    #npx @colbymchenry/codegraph
    #echo "Install codegraph"
    #npx install @colbymchenry/codegraph

    #curl -fsSL https://raw.githubusercontent.com/DeusData/codebase-memory-mcp/main/install.sh | bash
    echo "Install codebase-memory-mcp"
    sudo npm install -g codebase-memory-mcp

    # base rust
    echo "Install rtk"
    curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
    if which rtk >/dev/null 2>&1; then
        rtk init -g --opencode
        sudo cp $HOME/.local/bin/rtk /usr/local/bin/
    fi

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
    #npx skills add mattpocock/skills -g -y --skill improve-codebase-architecture --skill codebase-design --skill grilling --skill domain-modeling --agent opencode
    #npx skills add kepano/obsidian-skills -g -y --agent opencode
    #npx skills add anthropics/skills -g -y --skill pdf --skill docx --skill pptx --skill xlsx --agent opencode
    #npx skills update
}

function main()
{
    if ! which opencode >/dev/null 2>&1; then
        echo "install opencode"
        if which node >/dev/null 2>&1; then
            sudo npm install -g opencode-ai
        else
            curl -fsSL https://opencode.ai/install | bash
        fi
    fi

    case "$1" in
    --oac )
        echo "update OpenAgentsControl developer"
        curl -fsSL https://raw.githubusercontent.com/darrenhinde/OpenAgentsControl/main/install.sh | bash -s developer
        if [ -d .opencode ]; then
            rsync_developer_config "${2:-$HOME/.config/opencode}"
            rm .opencode
        fi
        ;;
    --markitdown )
        git clone https://github.com/microsoft/markitdown
        cd markitdown
        docker build -t markitdown:latest .
        cd -
        rm -rf markitdown
        ;;
    --drawio )
        npx skills add Agents365-ai/drawio-skill -g -y --skill drawio-skill --agent opencode
        sudo apt-get install xvfb
        sudo snap install drawio
        ;;
    --comet )
        sudo npm install -g @rpamis/comet@latest
        sudo npm install -g @fission-ai/openspec@latest
        echo "Install openspec and supperpowers for project:"
        echo "cd your-project"
        echo "comet init"
        ;;
    --graphify )
        # base Python 3.10+
        pip install graphifyy
        graphify install --platform opencode
        graphify opencode install   #安装常驻助手规则 AGENTS.md 到当前项目
        ;;
    --cua )
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/trycua/cua/main/libs/cua-driver/scripts/install.sh)"
        cua-driver mcp-config --client opencode
        ;;
    --caveman )
        npx -y github:JuliusBrussee/caveman -- --only opencode
        if ! grep -q '"cavecrew-builder"' "$CONFIG_FILE" 2>/dev/null; then
            if command -v jq &>/dev/null; then
                jq '.agent["cavecrew-builder"] = {"mode": "subagent"} |
                    .agent["cavecrew-investigator"] = {"mode": "subagent"} |
                    .agent["cavecrew-reviewer"] = {"mode": "subagent"}' \
                    "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"
                mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
            fi
        fi
        ;;
    --agentmemory )
        sudo npm install -g @agentmemory/agentmemory
        curl -fsSL https://install.iii.dev/iii/main/install.sh | VERSION=0.11.2 sh
        npx git-ripper https://github.com/rohitg00/agentmemory/tree/main/plugin/opencode -o ./agentmemory
        ./agentmemory/install.sh
        ;;
    --omniroute )
        sudo npm install -g omniroute
        sudo npm install -g @ai-sdk/openai-compatible
        #if which omniroute >/dev/null 2>&1; then
        #    omniroute setup opencode
        #    echo "run omniroute, login web create apikey"
        #    echo "run opencode auth login --provider omniroute"
        #fi
        # use config provider instead of plugin
        if ! grep -q '"omniroute"' "$CONFIG_FILE" 2>/dev/null; then
            if command -v jq &>/dev/null; then
                jq '.provider.omniroute = {
                    "npm": "@ai-sdk/openai-compatible",
                    "name": "OmniRoute",
                    "options": {
                        "baseURL": "http://localhost:20128/v1",
                        "apiKey": "sk_omniroute"
                    },
                    "models": {
                        "auto": { "name": "auto-combo" }
                    }
                }' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"
                mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
                echo "Added omniroute provider with auto model to $CONFIG_FILE"
            else
                echo "jq not installed, skipping provider config. Add provider manually."
            fi
            echo ""
            echo "Config file: /usr/lib/node_modules/omniroute/.env"
            echo "  Enable API auth:    REQUIRE_API_KEY=true"
            echo "  Reveal full API key: ALLOW_API_KEY_REVEAL=true"
            echo "  Login password: INITIAL_PASSWORD=CHANGEME"
            echo "  Daily request limit: DEFAULT_RATE_LIMIT_PER_DAY=1000"
            echo ""
            echo "Reset auto routing:  sqlite3 ~/.omniroute/storage.sqlite \"DELETE FROM key_value WHERE namespace='lkgp' AND key='auto:auto'\""
        fi
        ;;
    --open-code-review )
        sudo npm install -g @alibaba-group/open-code-review
        if which ocr >/dev/null 2>&1; then
            npx skills add alibaba/open-code-review -g -y --skill open-code-review --agent opencode
            ocr config provider          # 选择内置供应商或添加自定义供应商
            ocr config model             # 为当前供应商选择模型
            ocr llm test                 # 测试连通性
        fi
        ;;
    --help )
        echo ""
        echo "options:"
        echo "--oac: install OpenAgentsControl for specific project"
        echo "--markitdown: install markitdown docker, use for translate file to markdown"
        echo "--drawio: install drawio, use for draw diagram"
        echo "--comet: install comet, use for comet openspec and superpowers"
        echo "--graphify: install graphify, use for drawing code knowledge maps"
        echo "--cua: install cua, use for drive native desktop apps in the background"
        echo "--caveman: install caveman, use for save token, similar tool ponytail"
        echo "--agentmemory: install agentmemory, use for agent memory"
        echo "--omniroute: install omniroute, use for llm proxy"
        echo "--open-code-review: install open-code-review, use for review code"
        ;;
    * )
        default_config_install
        ;;
    esac
}
# 调用main函数
main "$@"
