#!/bin/bash

# opencode 增强组件安装器
#   交互式: ./install.sh
#   参数式: ./install.sh --omo-slim --rtk ...

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
if ! grep -qF '. "$HOME/.env"' "$HOME/.profile"; then
    cat >> "$HOME/.profile" <<'EOF'
# 环境变量集中在 .env，.profile负责加载（set -a 使其中的赋值自动导出）
if [ -r "$HOME/.env" ]; then
  set -a
  . "$HOME/.env"
  set +a
fi
EOF
fi

# ==================== 通用工具 ====================

if [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null)" -ge 8 ]; then
    C_GREEN=$(tput setaf 2)
    C_YELLOW=$(tput setaf 3)
    C_CYAN=$(tput setaf 6)
    C_BOLD=$(tput bold)
    C_OFF=$(tput sgr0)
else
    C_GREEN=""
    C_YELLOW=""
    C_CYAN=""
    C_BOLD=""
    C_OFF=""
fi

function have()
{
    command -v "$1" >/dev/null 2>&1
}

function rule()
{
    printf "%s\n" "------------------------------------------------------------"
}

# ==================== 基础依赖 ====================

function install_node()
{
    if have node; then
        echo "nodejs already installed, skipping."
        return 0
    fi
    echo "Install nodejs..."
    if have apt; then
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        sudo apt install -y nodejs
    elif have brew; then
        brew install node
    else
        echo "Cannot install nodejs: no supported package manager found"
        return 1
    fi
}

function install_npm()
{
    if have npm; then
        echo "npm already installed, skipping."
        return 0
    fi
    echo "Install npm..."
    if have apt; then
        sudo apt install -y npm
    elif have brew; then
        brew install npm
    else
        echo "Cannot install npm: no supported package manager found"
        return 1
    fi
}

function install_bun()
{
    if have bun; then
        echo "bun already installed, skipping."
        return 0
    fi
    echo "Install bun..."
    sudo npm install -g bun --allow-scripts=bun
}

function install_opencode()
{
    if have opencode; then
        echo "opencode already installed, skipping."
        return 0
    fi
    echo "Install opencode..."
    sudo npm i -g @opencode/cli@latest
    #use for opencode desktop connect opencode server
    mkdir -p $HOME/.opencode/bin
    ln -sfn "$(readlink -f /usr/bin/opencode)" $HOME/.opencode/bin/opencode
    echo "Start opencode server when system setup..."
    ./setup-server.sh
}

function install_omo_native()
{
    echo "Install oh-my-openagent..."
    sudo apt install gh -y
    sudo npm i -g --allow-scripts=@ast-grep/cli @ast-grep/cli
    bunx oh-my-openagent install --platform=native
    if [ -f "$HOME/.bun/bin/omo" ]; then
        $HOME/.bun/bin/omo doctor
    fi
}

function install_jq()
{
    if have jq; then
        echo "jq already installed, skipping."
        return 0
    fi
    echo "Install jq..."
    if command -v apt &>/dev/null; then
        sudo apt install -y jq
    elif command -v yum &>/dev/null; then
        sudo yum install -y jq
    elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm jq
    elif command -v brew &>/dev/null; then
        brew install jq
    else
        echo "Cannot install jq: no supported package manager found"
        return 1
    fi
}

function install_uv_if_needed()
{
    if ! command -v uv >/dev/null 2>&1; then
        curl -LsSf https://astral.sh/uv/install.sh | sh
        export PATH="$HOME/.local/bin:$PATH"
    fi
}

# ==================== 环境检测 ====================

MISSING_DEPS=()

function dep_line()
{
    # $1=command $2=label $3=core(可选, 缺失时是否可自动安装)
    local cmd=$1 label=$2 core=$3 ver
    if have "$cmd"; then
        ver=$("$cmd" --version 2>/dev/null | head -n 1)
        if [ "$cmd" = curl ]; then
            ver=$(printf '%s\n' "$ver" | awk '{print $1, $2}')
        fi
        [ -z "$ver" ] && ver="已安装"
        printf "  %s✓%s %-12s %s\n" "$C_GREEN" "$C_OFF" "$label" "$ver"
    else
        printf "  %s·%s %-12s %s\n" "$C_YELLOW" "$C_OFF" "$label" "未安装"
        if [ "$core" = "core" ]; then
            MISSING_DEPS+=("$cmd")
        fi
    fi
}

function check_env()
{
    MISSING_DEPS=()
    echo ""
    echo "${C_BOLD}[环境检测]${C_OFF}"
    dep_line node "nodejs" core
    dep_line npm "npm" core
    dep_line bun "bun" core
    dep_line opencode "opencode" core
    dep_line jq "jq" core
    rule
    dep_line rsync "rsync"
    dep_line curl "curl"
    dep_line git "git"
    dep_line python3 "python3"
    dep_line docker "docker"
}

function install_env()
{
    local cmd
    for cmd in "$@"; do
        case "$cmd" in
        node)
            install_node
            ;;
        npm)
            install_npm
            ;;
        bun)
            install_bun
            ;;
        opencode)
            install_opencode
            ;;
        jq)
            install_jq
            ;;
        *)
            echo "No installer for $cmd, skipping."
            ;;
        esac
    done
}

function ensure_env()
{
    check_env
    if [ "${#MISSING_DEPS[@]}" -gt 0 ]; then
        echo ""
        read -r -p "是否安装缺失的核心依赖 [${MISSING_DEPS[*]}] ? (Y/n) " reply
        echo ""
        case "$reply" in
        ""|[Yy]*)
            install_env "${MISSING_DEPS[@]}"
            ;;
        *)
            echo "已跳过依赖安装，部分组件可能安装失败"
            ;;
        esac
        check_env
    fi
}

# ==================== 安装项 ====================

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

function set_env()
{
    local var_name=$1
    local var_value=$2
    local env_file=$HOME/.env

    # skip if the variable is already set in the current environment
    if [ -n "${!var_name}" ] || [ ! -f "$env_file" ]; then
        return 0
    fi

    # skip if the variable already exists in env
    if env | grep -q "$var_name"; then
        return 0
    fi

    echo "$var_name=$var_value" >> "$env_file"
    echo "Added $var_name=$var_value to $env_file"
}

function default_config_install()
{
    # remove plugin cache
    rm -rf $HOME/.cache/opencode/npm/*
    rm -rf $HOME/.cache/opencode/packages/*
    if [ "$PWD" != "$HOME/.opencode" ]; then
        echo "Install global config to $CONFIG_DIR"
        rsync -av  --include='cli.json' \
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
        rm -rf "$CONFIG_DIR/cli.json"
        ln -s "$PWD/cli.json" "$CONFIG_DIR/cli.json"
        rm -rf "$CONFIG_DIR/rules"
        ln -s "$PWD/rules" "$CONFIG_DIR/rules"
        rm -rf "$CONFIG_DIR/codebase_memory"
        ln -s "$PWD/codebase_memory" "$CONFIG_DIR/codebase_memory"
    fi

    set_env EDITOR vim
    # Disable all .claude support
    set_env OPENCODE_DISABLE_CLAUDE_CODE true
    # Disable only ~/.claude/CLAUDE.md
    #set_env OPENCODE_DISABLE_CLAUDE_CODE_PROMPT true
    # Disable only .claude/skills
    #set_env OPENCODE_DISABLE_CLAUDE_CODE_SKILLS true
    # Enable .agents/skills
    set_env OPENCODE_DISABLE_EXTERNAL_SKILLS false

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

function install_archify()
{
    echo "Install archify skill..."
    npx skills add tt-a1i/archify -g -y --skill archify --agent opencode
}

function install_rtk()
{
    echo "Install rtk..."
    curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
    sudo cp $HOME/.local/bin/rtk /usr/local/bin/
    sudo chown root:root /usr/local/bin/rtk
    sudo chmod 777 /usr/local/bin/rtk
    rtk init -g --opencode
}

function install_codebase_memory()
{
    echo "Install codebase-memory-mcp..."
    curl -fsSL https://raw.githubusercontent.com/DeusData/codebase-memory-mcp/main/install.sh | bash -s -- --clients=opencode
    sudo rm $HOME/.local/bin/install.sh
    sudo cp $HOME/.local/bin/codebase-memory-mcp /usr/local/bin/
    sudo chown root:root /usr/local/bin/codebase-memory-mcp
    sudo chmod 777 /usr/local/bin/codebase-memory-mcp
    if jq -e '.mcp."codebase-memory-mcp"' "$CONFIG_FILE" >/dev/null 2>&1; then
        jq 'del(.mcp."codebase-memory-mcp")' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"
        mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
        mv -f $CONFIG_DIR/AGENTS.md $CONFIG_DIR/codebase_memory/
        mv -f $CONFIG_DIR/agents/codebase-memory* $CONFIG_DIR/codebase_memory/agents/
        mv -f $CONFIG_DIR/plugins/cbm-augment.ts $CONFIG_DIR/codebase_memory/plugins/
        rm -rf $CONFIG_DIR/codebase_memory/skills/codebase-memory
        mv -f $CONFIG_DIR/skills/codebase-memory $CONFIG_DIR/codebase_memory/skills/codebase-memory
        echo "Removed codebase-memory-mcp config from $CONFIG_FILE"
    fi
}

function install_markitdown()
{
    echo "Install markitdown docker..."
    if ! have docker; then
        echo "docker not found, please install docker first"
        return 1
    fi
    git clone https://github.com/microsoft/markitdown
    cd markitdown
    docker build -t markitdown:latest .
    cd - >/dev/null
    rm -rf markitdown
}

function install_drawio()
{
    echo "Install drawio desktop and skill..."
    npx skills add Agents365-ai/drawio-skill -g -y --skill drawio-skill --agent opencode
    if have apt; then
        sudo apt install -y xvfb
    fi
    sudo snap install drawio
}

function install_comet()
{
    echo "Install openspec and supperpowers for project..."
    sudo npm install -g @rpamis/comet@latest
    sudo npm install -g @fission-ai/openspec@latest
    echo "cd project directory and run: comet init"
}

function install_graphify()
{
    echo "Install graphify..."
    # base Python 3.10+
    if python3 -c 'import sys; sys.exit(0 if sys.version_info > (3, 9) else 1)'; then
        pip install --break-system-packages graphifyy
    else
        install_uv_if_needed
        # use uv env
        uv tool install --python 3.11 graphifyy
    fi
}

function install_cua()
{
    echo "Install computer use agent..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/trycua/cua/main/libs/cua-driver/scripts/install.sh)"
    if command -v cua-driver >/dev/null 2>&1; then
        cua-driver mcp-config --client opencode
    fi
}

function install_caveman()
{
    echo "Install caveman..."
    npx -y github:JuliusBrussee/caveman -- --only opencode
    if ! grep -q '"cavecrew-builder"' "$CONFIG_FILE" 2>/dev/null; then
        jq '.agent["cavecrew-builder"] = {"mode": "subagent"} |
            .agent["cavecrew-investigator"] = {"mode": "subagent"} |
            .agent["cavecrew-reviewer"] = {"mode": "subagent"}' \
        "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"
        mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    fi
}

function install_agentmemory()
{
    echo "Install agentmemory..."
    sudo npm install -g @agentmemory/agentmemory
    npx git-ripper https://github.com/rohitg00/agentmemory/tree/main/plugin/opencode -o ./agentmemory
    ./agentmemory/install.sh
}

function install_omniroute()
{
    echo "Install omniroute..."
    sudo npm install -g omniroute
    if command -v omniroute >/dev/null 2>&1; then
        #omniroute setup opencode
        # use config provider instead of plugin
        omniroute_provider_config
    fi
}

function install_ocr()
{
    echo "Install open-code-review..."
    sudo npm install -g @alibaba-group/open-code-review
    if command -v ocr >/dev/null 2>&1; then
        mkdir -p "$CONFIG_DIR/plugins"
        curl -fsSL \
        https://raw.githubusercontent.com/alibaba/open-code-review/main/plugins/open-code-review/opencode/open-code-review.ts \
        -o $CONFIG_DIR/plugins/open-code-review.ts
        ocr config provider          # 选择内置供应商或添加自定义供应商
        ocr config model             # 为当前供应商选择模型
        ocr llm test                 # 测试连通性
    fi
}

function install_omo_slim()
{
    echo "Install oh-my-opencode-slim..."
    bunx oh-my-opencode-slim@latest install
    # 把 omo-slim.json 融合进已有的 oh-my-opencode-slim.json
    local src="$PWD/omo-slim.json"
    local dst="$CONFIG_DIR/oh-my-opencode-slim.json"
    if [ -f "$dst" ]; then
        jq -s '.[0] * .[1]' "$dst" "$src" > "${dst}.tmp" && mv "${dst}.tmp" "$dst"
        echo "Merged omo-slim.json into $dst"
    fi
    bunx oh-my-opencode-slim@latest doctor
    set_env OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS true
    set_env OPENCODE_ENABLE_EXA 1
}

function install_officecli()
{
    echo "Install officecli..."
    sudo apt update && sudo apt install -y libicu-dev
    sudo npm install -g @officecli/officecli
    if command -v officecli >/dev/null 2>&1; then
        officecli install codex  # install skill to ~/.agents/skills
    fi
}

function install_book_to_skill()
{
    echo "Install book-to-skill..."
    npx skills add virgiliojr94/book-to-skill -g -y --skill book-to-skill --agent opencode
    if python3 -c 'import sys; sys.exit(0 if sys.version_info > (3, 9) else 1)'; then
        pip install --break-system-packages pypdf docling
    else
        install_uv_if_needed
        # use uv env
        uv tool install --python 3.11 docling --with pypdf
    fi
}

function install_browser_skill()
{
    echo "Install browser-skill (Tencent BrowserSkill)..."
    curl -fsSL https://raw.githubusercontent.com/Tencent/BrowserSkill/main/install.sh | sh
    bsk --version
    # install skill to ~/.agents/skills
    bsk install-skill --harness codex --json
    bsk doctor || echo "doctor reported issues: extension not connected is expected until you install it."
    echo ""
    echo "Remaining manual step: install the browser extension, open the popup and enable the connection."
    echo "  Chrome: https://chromewebstore.google.com/detail/hhcmgoofomhgciiibhipgmgkgnoenaoi"
    echo "  Edge:   https://microsoftedge.microsoft.com/addons/detail/browserskill/emacgiaaaiojkkpkddmmdfhmokgmnikg"
    echo ""
    echo "Then start a NEW opencode session so it can discover the browser-skill."
}

# ==================== 安装项元数据与状态 ====================

# 格式: key|显示名|说明
# 注意: default_config_install 不是组件, 每次运行安装器都会自动执行
INSTALL_ITEMS=(
"rtk|rtk|压缩命令输出, 节省 token"
"codebase_memory|codebase-memory|代码图谱 MCP"
"omo_slim|oh-my-opencode-slim|多模型 agent 编排插件"
"omo_native|oh-my-openagent|多模型 agent 编排 (native)"
"omniroute|OmniRoute|LLM 代理"
"ocr|open-code-review|代码评审"
"officecli|officecli|处理 docx/xlsx/pptx"
"caveman|caveman|省 token 的精简工具集"
"comet|comet + openspec|规范化开发流程 + superpowers"
"graphify|graphify|绘制代码知识图谱"
"markitdown|markitdown|文件转 markdown (docker)"
"drawio|drawio|绘制图表 (desktop + skill)"
"cua|cua-driver|后台驱动桌面应用"
"agentmemory|agentmemory|agent 记忆"
"archify|archify|绘制架构/流程/时序图 skill"
"book_to_skill|book-to-skill|书籍/文档转 skill"
"browser_skill|browser-skill|接管已登录浏览器的自动化 skill"
)

function item_meta()
{
    # $1=记录 $2=字段(1=key 2=显示名 3=说明)
    local a b c
    IFS='|' read -r a b c <<< "$1"
    case "$2" in
    1) printf '%s' "$a" ;;
    2) printf '%s' "$b" ;;
    3) printf '%s' "$c" ;;
    esac
}

ITEM_CMD=""

function item_installed()
{
    # 返回 0 表示该组件已安装
    # 若已安装的是可执行文件, 则把命令名写入全局变量 ITEM_CMD(供打印版本号使用)
    ITEM_CMD=""
    case "$1" in
    rtk)
        have rtk && ITEM_CMD=rtk
        ;;
    codebase_memory)
        have codebase-memory-mcp && ITEM_CMD=codebase-memory-mcp
        ;;
    omo_native)
        have omo && ITEM_CMD=omo
        ;;
    omo_slim)
        # 从插件安装目录判断(兼容 npm/ 与 packages/ 两种缓存布局及新旧包名)
        local cache d found=""
        cache="${XDG_CACHE_HOME:-$HOME/.cache}/opencode"
        for d in \
            "$cache"/npm/oh-my-opencode-slim@latest/*/node_modules/oh-my-opencode-slim \
            "$cache"/packages/oh-my-opencode-slim@latest/node_modules/oh-my-opencode-slim
        do
            [ -f "$d/package.json" ] && { found=1; break; }
        done
        [ -n "$found" ] || return 1
        ;;
    omniroute)
        have omniroute && ITEM_CMD=omniroute
        ;;
    ocr)
        have ocr && ITEM_CMD=ocr
        ;;
    officecli)
        have officecli && ITEM_CMD=officecli
        ;;
    caveman)
        jq -e '.agent["cavecrew-builder"]' "$CONFIG_FILE" >/dev/null 2>&1
        ;;
    comet)
        have comet && ITEM_CMD=comet
        ;;
    graphify)
        have graphify && ITEM_CMD=graphify
        ;;
    markitdown)
        [ -n "$(docker images -q markitdown:latest 2>/dev/null)" ]
        ;;
    drawio)
        if have drawio; then
            ITEM_CMD=drawio
        elif have draw.io; then
            ITEM_CMD=draw.io
        elif snap list drawio 2>/dev/null | grep -q drawio; then
            ITEM_CMD=drawio
        else
            return 1
        fi
        ;;
    cua)
        have cua-driver && ITEM_CMD=cua-driver
        ;;
    agentmemory)
        have agentmemory && ITEM_CMD=agentmemory
        ;;
    archify)
        [ -d "$HOME/.agents/skills/archify" ]
        ;;
    book_to_skill)
        [ -d "$HOME/.agents/skills/book-to-skill" ] || [ -d "$CONFIG_DIR/skills/book-to-skill" ]
        ;;
    browser_skill)
        have bsk && [ -f "$HOME/.agents/skills/browser-skill/SKILL.md" ] && ITEM_CMD=bsk
        ;;
    *)
        return 1
        ;;
    esac
}

function run_item()
{
    # $1=key
    local key=$1
    case "$key" in
    rtk)
        install_rtk
        ;;
    codebase_memory)
        install_codebase_memory
        ;;
    omo_native)
        install_omo_native
        ;;
    omo_slim)
        install_omo_slim
        ;;
    omniroute)
        install_omniroute
        ;;
    ocr)
        install_ocr
        ;;
    officecli)
        install_officecli
        ;;
    caveman)
        install_caveman
        ;;
    comet)
        install_comet
        ;;
    graphify)
        install_graphify
        ;;
    markitdown)
        install_markitdown
        ;;
    drawio)
        install_drawio
        ;;
    cua)
        install_cua
        ;;
    agentmemory)
        install_agentmemory
        ;;
    archify)
        install_archify
        ;;
    book_to_skill)
        install_book_to_skill
        ;;
    browser_skill)
        install_browser_skill
        ;;
    *)
        echo "Unknown item: $key"
        return 1
        ;;
    esac
}

# ==================== 交互式菜单 ====================

function dwidth()
{
    # 显示宽度: 中日韩等宽字符按 2 列计算
    printf '%s' "$1" | LC_ALL=C awk '{ b = length($0); c = gsub(/[\200-\277]/, ""); printf "%d", b - int(c / 2) }'
}

function pad()
{
    # $1=文本 $2=目标显示宽度
    local text=$1 width=$2
    local pad
    pad=$(($(dwidth "$text") > width ? 0 : width - $(dwidth "$text")))
    printf '%s%*s' "$text" "$pad" ''
}

function print_menu()
{
    local i=0 rec key mark color name ver desc
    local W_NUM=4 W_MARK=12 W_NAME=28
    echo ""
    echo "${C_BOLD}可安装组件${C_OFF}   (${C_GREEN}✓${C_OFF} 已安装 / ${C_YELLOW}·${C_OFF} 未安装)"
    rule
    for rec in "${INSTALL_ITEMS[@]}"; do
        i=$((i + 1))
        key=$(item_meta "$rec" 1)
        name=$(item_meta "$rec" 2)
        desc=$(item_meta "$rec" 3)
        if item_installed "$key"; then
            mark="✓ 已安装"
            color="$C_GREEN"
            # 已安装且为可执行文件时追加版本号
            if [ -n "$ITEM_CMD" ]; then
                ver=$("$ITEM_CMD" --version 2>/dev/null | head -n 1)
                if [[ "$ver" =~ ([0-9]+(\.[0-9]+)+([.-][0-9A-Za-z]+)*) ]]; then
                    ver="${BASH_REMATCH[1]}"
                fi
                [ -n "$ver" ] && name="$name ($ver)"
            fi
        else
            mark="· 未安装"
            color="$C_YELLOW"
        fi
        printf "%*d) %s%s%s  %s  %s\n" \
            "$W_NUM" "$i" \
            "$color" "$(pad "$mark" "$W_MARK")" "$C_OFF" \
            "$(pad "$name" "$W_NAME")" "$desc"
    done
    rule
    echo "  a = 安装全部未安装组件    l = 刷新列表    q = 退出"
}

function contains_index()
{
    local needle=$1
    shift
    local item
    for item in "$@"; do
        [ "$item" = "$needle" ] && return 0
    done
    return 1
}

function interactive_menu()
{
    local answer tok n idx i key rec
    local -a targets=()

    if [ ! -t 0 ]; then
        echo "非交互终端: 请使用参数模式, 例如 ./install.sh --omo-slim  (查看 ./install.sh --help)"
        return 1
    fi

    while true; do
        print_menu
        targets=()
        read -r -p "请输入要安装的组件编号(空格分隔多个, 如 1 3): " answer
        answer=${answer//,/ }
        if [ -z "$answer" ] || [ "$answer" = "q" ] || [ "$answer" = "Q" ] || [ "$answer" = "0" ]; then
            break
        fi
        if [ "$answer" = "l" ] || [ "$answer" = "L" ]; then
            continue
        fi
        if [ "$answer" = "a" ] || [ "$answer" = "A" ]; then
            for i in "${!INSTALL_ITEMS[@]}"; do
                key=$(item_meta "${INSTALL_ITEMS[$i]}" 1)
                item_installed "$key" || targets+=("$i")
            done
        else
            for tok in $answer; do
                if ! [[ "$tok" =~ ^[0-9]+$ ]]; then
                    echo "忽略无效输入: $tok"
                    continue
                fi
                n=$((10#$tok))
                if [ "$n" -lt 1 ] || [ "$n" -gt "${#INSTALL_ITEMS[@]}" ]; then
                    echo "忽略超出范围的编号: $tok"
                    continue
                fi
                idx=$((n - 1))
                contains_index "$idx" "${targets[@]:-}" || targets+=("$idx")
            done
        fi

        if [ "${#targets[@]}" -eq 0 ]; then
            echo "没有选择任何组件"
            continue
        fi

        local total=${#targets[@]}
        local done_count=0
        for idx in "${targets[@]}"; do
            done_count=$((done_count + 1))
            rec="${INSTALL_ITEMS[$idx]}"
            key=$(item_meta "$rec" 1)
            echo ""
            rule
            echo "${C_CYAN}[$done_count/$total] $(item_meta "$rec" 2)${C_OFF}"
            rule
            if ! run_item "$key"; then
                echo "${C_YELLOW}[失败] $key${C_OFF}"
            fi
        done
        echo ""
        rule
        echo "本轮完成, 继续选择其他组件"
    done

    echo ""
    echo "退出安装器"
}

# ==================== 入口 ====================

function print_help()
{
    echo ""
    echo "opencode 增强组件安装器"
    echo ""
    echo "用法:"
    echo "  ./install.sh                 进入交互式安装列表"
    echo "  ./install.sh --list          仅打印安装列表与当前状态"
    echo "  ./install.sh --env           只检查并安装基础依赖 (nodejs/npm/bun/opencode/jq)"
    echo "  ./install.sh --<component>   安装指定组件, 可组合多个"
    echo ""
    echo "每次运行都会先检测基础依赖, 并同步默认配置:"
    echo "  rsync 配置到 ~/.config/opencode, 并安装全局 skills"
    echo "  --list / --help / --env 不会执行默认配置同步"
    echo ""
    echo "options:"
    echo "  --rtk:                   安装 rtk, 压缩命令输出以节省 token"
    echo "  --codebase-memory:       安装 codebase-memory-mcp, 提供代码图谱"
    echo "  --omo-slim:              安装 oh-my-opencode-slim, 多模型 agent 编排插件"
    echo "  --omo-native:            安装 oh-my-openagent, 多模型 agent 编排 (native)"
    echo "  --omniroute:             安装 omniroute, 作为 LLM 代理"
    echo "  --ocr:                   安装 open-code-review, 用于代码评审"
    echo "  --officecli:             安装 officecli, 处理 docx/xlsx/pptx 文档"
    echo "  --caveman:               安装 caveman, 省 token 的精简工具集"
    echo "  --comet:                 安装 comet, 含 openspec 与 superpowers 流程"
    echo "  --graphify:              安装 graphify, 绘制代码知识图谱"
    echo "  --markitdown:            安装 markitdown docker, 把文件转 markdown"
    echo "  --drawio:                安装 drawio, 绘制图表"
    echo "  --cua:                   安装 cua-driver, 后台驱动桌面应用"
    echo "  --agentmemory:           安装 agentmemory, 为 agent 提供记忆"
    echo "  --archify:               安装 archify skill, 绘制架构/流程/时序图"
    echo "  --book-to-skill:         安装 book-to-skill, 把书籍/文档转成 skill"
    echo "  --browser-skill:         安装 Tencent BrowserSkill, 复用浏览器登录态做自动化"
    echo ""
}

function flag_to_key()
{
    # $1=命令行参数 -> 输出 key (未知则返回 1)
    case "$1" in
    --rtk)
        echo "rtk"
        ;;
    --codebase-memory)
        echo "codebase_memory"
        ;;
    --omo-native)
        echo "omo_native"
        ;;
    --omo-slim)
        echo "omo_slim"
        ;;
    --omniroute)
        echo "omniroute"
        ;;
    --ocr)
        echo "ocr"
        ;;
    --officecli)
        echo "officecli"
        ;;
    --caveman)
        echo "caveman"
        ;;
    --comet)
        echo "comet"
        ;;
    --graphify)
        echo "graphify"
        ;;
    --markitdown)
        echo "markitdown"
        ;;
    --drawio)
        echo "drawio"
        ;;
    --cua)
        echo "cua"
        ;;
    --agentmemory)
        echo "agentmemory"
        ;;
    --archify)
        echo "archify"
        ;;
    --book-to-skill)
        echo "book_to_skill"
        ;;
    --browser-skill)
        echo "browser_skill"
        ;;
    *)
        return 1
        ;;
    esac
}

function main()
{
    case "${1:-}" in
    --help | -h)
        print_help
        return 0
        ;;
    --list | -l)
        check_env
        print_menu
        return 0
        ;;
    --env)
        ensure_env
        return 0
        ;;
    esac

    local arg key
    local -a keys=()
    for arg in "$@"; do
        if key=$(flag_to_key "$arg"); then
            keys+=("$key")
        else
            echo "Unknown option: $arg"
            print_help
            return 1
        fi
    done

    if [ "$#" -eq 0 ] && [ ! -t 0 ]; then
        echo "非交互终端: 请使用参数模式, 例如 ./install.sh --omo-slim  (查看 ./install.sh --help)"
        return 1
    fi

    # 依赖检测
    ensure_env

    if [ "$#" -eq 0 ]; then
        echo ""
        rule
        echo "${C_BOLD}同步默认配置${C_OFF}"
        rule
        default_config_install
        interactive_menu
        return $?
    fi

    for key in "${keys[@]}"; do
        rule
        echo "$key"
        rule
        run_item "$key"
    done
}

# 调用main函数
main "$@"
