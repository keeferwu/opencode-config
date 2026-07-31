#!/bin/bash

CONFIG_FILE="$HOME/.config/opencode/opencode.json"
if [ ! -f "$CONFIG_FILE" ]; then
    mkdir -p "$(dirname "$CONFIG_FILE")"
    cat > "$CONFIG_FILE" << 'EOF'
{
  "$schema": "https://opencode.ai/config.json"
}
EOF
fi

function use_uv_pip_install()
{
    if ! command -v uv >/dev/null 2>&1; then
        curl -LsSf https://astral.sh/uv/install.sh | sh
    fi
    local project_dir=~/.venv/$1
    local requirement_file=$1/requirements.txt
    # 创建使用 Python 3.11 的虚拟环境，自动下载3.11
    uv venv $project_dir --python 3.11 -c

    if [ -f "$requirement_file" ]; then
        # 批量安装多个包
        uv pip install --python $project_dir/bin/python -r $requirement_file
    else
        # 安装参数中的所有包
        uv pip install --python $project_dir/bin/python "${@:2}"
    fi
    echo "Note: Before use $1, should source $project_dir/bin/activate"
}

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
        if command -v jq &>/dev/null; then
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
                      "context": 200000,
                      "output": 60000
                    }
                  }
                }
            }' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"
            mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
            echo "Added omniroute provider with auto model to $CONFIG_FILE"
        else
            echo "jq not installed, skipping provider config. Add provider manually."
        fi
    fi
    read -p "Do you want to configure omniroute MCP server? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if ! jq -e '.mcp.omniroute' "$CONFIG_FILE" >/dev/null 2>&1; then
            if command -v jq &>/dev/null; then
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
                echo "jq not installed, skipping MCP config. Add MCP config manually."
            fi
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
        cp dcp.jsonc "$HOME/.config/opencode"
        cp oh-my-openagent.jsonc "$HOME/.config/opencode"
    else
        ln -s "$PWD/dcp.jsonc" "$HOME/.config/opencode/dcp.jsonc"
        ln -s "$PWD/oh-my-openagent.jsonc" "$HOME/.config/opencode/oh-my-openagent.jsonc"
    fi

    #npx @colbymchenry/codegraph
    #echo "Install codegraph"
    #npx install @colbymchenry/codegraph

    if ! command -v codebase-memory-mcp >/dev/null 2>&1; then
        echo "Install codebase-memory-mcp"
        #curl -fsSL https://raw.githubusercontent.com/DeusData/codebase-memory-mcp/main/install.sh | bash
        sudo npm install -g codebase-memory-mcp
        sudo codebase-memory-mcp --help
    fi

    if command -v rtk >/dev/null 2>&1; then
        rtk init -g --opencode
        sudo cp $HOME/.local/bin/rtk /usr/local/bin/
    else
        echo "Install rtk"
        curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
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

    case "$1" in
    --oac )
        echo "Install OpenAgentsControl developer..."
        curl -fsSL https://raw.githubusercontent.com/darrenhinde/OpenAgentsControl/main/install.sh | bash -s developer
        if [ -d .opencode ]; then
            rsync_developer_config "${2:-$HOME/.config/opencode}"
            rm .opencode
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
        pip install graphifyy
        if command -v graphify >/dev/null 2>&1; then
            graphify install --platform opencode
            graphify opencode install   #安装常驻助手规则 AGENTS.md 到当前项目
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
    --open-code-review )
        echo "Install open-code-review..."
        sudo npm install -g @alibaba-group/open-code-review
        if command -v ocr >/dev/null 2>&1; then
            #npx skills add alibaba/open-code-review -g -y --skill open-code-review --agent opencode
            ocr config provider          # 选择内置供应商或添加自定义供应商
            ocr config model             # 为当前供应商选择模型
            ocr llm test                 # 测试连通性
        fi
        ;;
    --omo )
        echo "Install oh-my-openagent..."
        sudo npm install -g oh-my-openagent
        if ! grep -q 'oh-my-openagent' "$CONFIG_FILE" 2>/dev/null; then
            if command -v jq &>/dev/null; then
                jq '.plugin += ["oh-my-openagent@latest"]' \
                    "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"
                mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
            fi
        fi
        ;;
    --officecli )
        echo "Install officecli..."
        sudo npm install -g @officecli/officecli
        if command -v officecli >/dev/null 2>&1; then
            officecli install opencode
        fi
        ;;
    --book-to-skill )
        echo "Install book-to-skill..."
        if python3 -c 'import sys; sys.exit(0 if sys.version_info > (3, 9) else 1)'; then
            pip install "book-to-skill[pdf]"
        else
            use_uv_pip_install book-to-skill "book-to-skill[pdf] @ git+https://github.com/virgiliojr94/book-to-skill.git"
        fi
        ;;
    --help )
        echo ""
        echo "options:"
        echo "--oac: install OpenAgentsControl for specific project"
        echo "--omo: install oh-my-openagent, use multi-model agent for coding"
        echo "--markitdown: install markitdown docker, use for translate file to markdown"
        echo "--drawio: install drawio, use for draw diagram"
        echo "--comet: install comet, use for comet openspec and superpowers"
        echo "--graphify: install graphify, use for drawing code knowledge maps"
        echo "--cua: install cua-driver, use for drive native desktop apps in the background"
        echo "--caveman: install caveman, use for save token, similar tool ponytail"
        echo "--agentmemory: install agentmemory, use for agent memory"
        echo "--omniroute: install omniroute, use for llm proxy"
        echo "--open-code-review: install open-code-review, use for review code"
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
