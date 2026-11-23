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

# 容器里常以 root 运行且没有 sudo: 用同名函数兜底, 免去逐处改写
if ! have sudo; then
    if [ "$(id -u)" -eq 0 ]; then
        sudo()
        {
            # 跳过 sudo 自身的选项(如 -E), 其余参数原样执行
            while [ "${1#-}" != "$1" ]; do shift; done
            "$@"
        }
        # 让 agentmemory/install.sh 等子脚本也能用上这个兜底
        export -f sudo
    else
        echo "警告: 未找到 sudo 且当前不是 root, 需要提权的安装会失败" >&2
    fi
fi

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
    sudo npm i -g @opencode/cli@latest --allow-scripts=@opencode/cli
    #use for opencode desktop connect opencode server
    mkdir -p $HOME/.opencode/bin
    ln -sfn "$(readlink -f /usr/bin/opencode)" $HOME/.opencode/bin/opencode

    opencode --completions bash > opencode-completion
    sudo mv opencode-completion /usr/share/bash-completion/completions/opencode
    sudo chown root:root /usr/share/bash-completion/completions/opencode

    if have systemctl && [ -d /run/systemd/system ]; then
        echo "Start opencode server when system setup..."
        ./setup-server.sh
    else
        echo "未检测到 systemd, 跳过 opencode 服务自启配置"
    fi
}

function install_tools()
{
    # 通用包安装: 包名与命令名一致时直接复用, 逐个安装并跳过已安装的
    local tool rc
    local -a failed=()
    if have apt; then
        # 容器/minimal 镜像的索引为空, 整轮只刷新一次, 失败也继续尝试安装
        sudo apt update || true
    fi
    for tool in "$@"; do
        if have "$tool"; then
            echo "$tool already installed, skipping."
            continue
        fi
        echo "Install $tool..."
        rc=0
        if have apt; then
            sudo apt install -y "$tool" || rc=1
        elif have dnf; then
            sudo dnf install -y "$tool" || rc=1
        elif have yum; then
            # EL7 的 jq 只在 EPEL 中, 先补上 epel-release
            if [ "$tool" = jq ] && ! rpm -q epel-release >/dev/null 2>&1; then
                sudo yum install -y epel-release || rc=1
            fi
            [ "$rc" -eq 0 ] && { sudo yum install -y "$tool" || rc=1; }
        elif have pacman; then
            sudo pacman -S --noconfirm --needed "$tool" || rc=1
        elif have brew; then
            brew install "$tool" || rc=1
            if [ "$tool" = curl ]; then
                # brew 的 curl 是 keg-only, 不会链接进 PATH
                echo "Note: brew curl is keg-only, add it to PATH if needed:"
                echo "  export PATH=\"$(brew --prefix)/opt/curl/bin:\$PATH\""
            fi
        else
            echo "Cannot install $tool: no supported package manager found"
            rc=1
        fi
        if [ "$rc" -ne 0 ]; then
            failed+=("$tool")
        fi
    done
    if [ "${#failed[@]}" -gt 0 ]; then
        echo "Failed to install: ${failed[*]}"
        return 1
    fi
}

function install_python3()
{
    if have python3 && have pip; then
        echo "python3 already installed, skipping."
        return 0
    fi
    echo "Install python3..."
    if have apt; then
        # 容器/minimal 镜像的索引为空, 先刷新一次
        sudo apt update || true
        sudo apt install -y python3 python3-dev python3-pip || return 1
    elif have dnf; then
        sudo dnf install -y python3 python3-devel python3-pip || return 1
    elif have yum; then
        sudo yum install -y python3 python3-devel python3-pip || return 1
    elif have pacman; then
        sudo pacman -S --noconfirm python python-pip python-setuptools || return 1
    elif have brew; then
        brew install python3 || return 1
    else
        echo "Cannot install python3: no supported package manager found"
        return 1
    fi
}

function pip_supports_break_system_packages()
{
    # --break-system-packages 从 pip 23.0.1 开始支持
    local ver
    ver=$(pip --version 2>/dev/null | awk '{print $2}')
    [ -n "$ver" ] || return 1
    printf '%s\n%s\n' "$ver" "23.0.1" | sort -V -C -r
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
    # $1=command $2=label
    local cmd=$1 label=$2 ver
    if have "$cmd"; then
        ver=$("$cmd" --version 2>/dev/null | head -n 1)
        case "$cmd" in
        curl | pip)
            # 只保留前两段, 避免带上路径等冗长描述
            ver=$(printf '%s\n' "$ver" | awk '{print $1, $2}')
            ;;
        esac
        [ -z "$ver" ] && ver="已安装"
        printf "  %s✓%s %-12s %s\n" "$C_GREEN" "$C_OFF" "$label" "$ver"
    else
        printf "  %s·%s %-12s %s\n" "$C_YELLOW" "$C_OFF" "$label" "未安装"
        MISSING_DEPS+=("$cmd")
    fi
}

function check_env()
{
    MISSING_DEPS=()
    echo ""
    echo "${C_BOLD}[环境检测]${C_OFF}"
    # 系统工具优先检测/安装: node/npm/opencode 等安装脚本依赖 curl/git
    dep_line jq "jq"
    dep_line curl "curl"
    dep_line git "git"
    dep_line rsync "rsync"
    dep_line tar "tar"
    dep_line python3 "python3"
    dep_line pip "pip"
    rule
    dep_line node "nodejs"
    dep_line npm "npm"
    dep_line bun "bun"
    dep_line opencode "opencode"
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
        python3 | pip)
            install_python3
            ;;
        jq | curl | git | rsync | tar)
            install_tools "$cmd"
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
    if ! jq -e '.providers.omniroute' "$CONFIG_FILE" >/dev/null 2>&1; then
        jq '.providers.omniroute = {
            "name": "OmniRoute",
            "package": "aisdk:@ai-sdk/openai-compatible",
            "settings": {
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
                "capabilities": {
                  "tools": true,
                  "temperature": true,
                  "reasoning": {
                    "supported": true
                  },
                  "input": ["text", "pdf", "image"],
                  "output": ["text"]
                },
                "limit": {
                  "context": 1000000,
                  "output": 300000
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
        if ! jq -e '.mcp.servers.omniroute' "$CONFIG_FILE" >/dev/null 2>&1; then
            jq '.mcp.servers.omniroute = {
                "type": "remote",
                "url": "http://localhost:20128/api/mcp/sse",
                "headers": {
                    "Authorization": "Bearer <omniroute_management_key>"
                },
                "disabled": true
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

    # skip if the variable already exists in the .env file
    if grep -q "^${var_name}=" "$env_file"; then
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
            --include='agents' \
            --include='commands' \
            --include='rules' \
            --include='skills' \
            --include='codebase_memory' \
            --exclude='*' ./  $CONFIG_DIR
    else
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
    npx skills add mattpocock/skills -g -y --skill grilling --skill diagnosing-bugs --skill  writing-for-agents --agent opencode
    npx skills add keeferwu/agent-skills -g -y --skill send-email --agent opencode
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

function install_codegraph()
{
    echo "Install codegraph..."
    sudo npm install -g @colbymchenry/codegraph --allow-scripts=@colbymchenry/codegraph
    if command -v codegraph >/dev/null 2>&1; then
        codegraph --version
        echo ""
        echo "为项目安装 codegraph MCP:"
        echo "  codegraph install --target=opencode --location=local"
        echo ""
    fi
}

function install_codebase_memory()
{
    echo "Install codebase-memory-mcp..."
    curl -fsSL https://raw.githubusercontent.com/DeusData/codebase-memory-mcp/main/install.sh | bash -s -- --clients=opencode
    sudo rm $HOME/.local/bin/install.sh
    sudo cp $HOME/.local/bin/codebase-memory-mcp /usr/local/bin/
    sudo chown root:root /usr/local/bin/codebase-memory-mcp
    sudo chmod 777 /usr/local/bin/codebase-memory-mcp
    if jq -e '.mcp.servers."codebase-memory-mcp" or .mcp."codebase-memory-mcp"' "$CONFIG_FILE" >/dev/null 2>&1; then
        jq 'del(.mcp.servers."codebase-memory-mcp", .mcp."codebase-memory-mcp")' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"
        mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
        mv -f $CONFIG_DIR/AGENTS.md $CONFIG_DIR/codebase_memory/
        mv -f $CONFIG_DIR/agents/codebase-memory* $CONFIG_DIR/codebase_memory/agents/
        mv -f $CONFIG_DIR/plugins/cbm-augment.ts $CONFIG_DIR/codebase_memory/plugins/
        rm -rf $CONFIG_DIR/codebase_memory/skills/codebase-memory
        mv -f $CONFIG_DIR/skills/codebase-memory $CONFIG_DIR/codebase_memory/skills/codebase-memory
        echo "Removed codebase-memory-mcp config from $CONFIG_FILE"
    fi
}

function install_drawio()
{
    echo "Install drawio desktop and skill..."
    if have snap; then
        sudo snap install drawio
    else
        echo "未找到 snap, 跳过 drawio 桌面版安装"
        return 1
    fi
    if have apt; then
        sudo apt update || true
        sudo apt install -y xvfb
    elif have dnf; then
        sudo dnf install -y xorg-x11-server-Xvfb
    elif have yum; then
        sudo yum install -y xorg-x11-server-Xvfb
    elif have pacman; then
        sudo pacman -S --noconfirm --needed xorg-server-xvfb
    fi
    npx skills add Agents365-ai/drawio-skill -g -y --skill drawio-skill --agent opencode
}

function install_graphify()
{
    echo "Install graphify..."
    # base Python 3.10+
    if python3 -c 'import sys; sys.exit(0 if sys.version_info > (3, 9) else 1)'; then
        local rc=0
        if pip_supports_break_system_packages; then
            pip install --break-system-packages graphifyy || rc=1
        else
            pip install graphifyy || rc=1
        fi
        if [ "$rc" -ne 0 ]; then
            # system site-packages not writable: fall back to an isolated user install
            install_uv_if_needed
            uv tool install --python 3.11 graphifyy || return 1
        fi
    else
        install_uv_if_needed
        # use uv env
        uv tool install --python 3.11 graphifyy
    fi
    if command -v graphify >/dev/null 2>&1; then
        echo ""
        echo "在 opencode 中注册 graphify skill:"
        echo "  graphify install --platform opencode --project  # 仅当前项目"
        echo ""
    fi
}

function install_speckit()
{
    echo "Install speckit..."
    # requires Python 3.11+
    if python3 -c 'import sys; sys.exit(0 if sys.version_info > (3, 10) else 1)'; then
        local rc=0
        if pip_supports_break_system_packages; then
            pip install --break-system-packages specify-cli || rc=1
        else
            pip install specify-cli || rc=1
        fi
        if [ "$rc" -ne 0 ]; then
            # system site-packages not writable: fall back to an isolated user install
            install_uv_if_needed
            uv tool install --python 3.11 specify-cli || return 1
        fi
    else
        install_uv_if_needed
        # use uv env
        uv tool install --python 3.11 specify-cli
    fi
    if command -v specify >/dev/null 2>&1; then
        echo ""
        echo "在项目中初始化 speckit:"
        echo "  specify init <new-project> --integration opencode   # 新项目"
        echo ""
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
        jq '.agents["cavecrew-builder"] = {"mode": "subagent"} |
            .agents["cavecrew-investigator"] = {"mode": "subagent"} |
            .agents["cavecrew-reviewer"] = {"mode": "subagent"}' \
        "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"
        mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    fi
}

function install_agentmemory()
{
    echo "Install agentmemory..."
    sudo npm install -g @agentmemory/agentmemory --allow-scripts=@agentmemory/agentmemory
    npx git-ripper https://github.com/rohitg00/agentmemory/tree/main/plugin/opencode -o ./agentmemory
    ./agentmemory/install.sh
}

function install_omniroute()
{
    echo "Install omniroute..."
    sudo npm install -g omniroute --allow-scripts=omniroute
    if command -v omniroute >/dev/null 2>&1; then
        #omniroute setup opencode
        # use config provider instead of plugin
        omniroute_provider_config
    fi
}

function install_ocr()
{
    echo "Install open-code-review..."
    sudo npm install -g @alibaba-group/open-code-review --allow-scripts=@alibaba-group/open-code-review
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

function install_openspec()
{
    echo "Install openspec..."
    sudo npm install -g @fission-ai/openspec
    if command -v openspec >/dev/null 2>&1; then
        openspec --version
        echo ""
        echo "在项目中初始化 openspec:"
        echo "  openspec init --tools opencode"
        echo ""
    fi
}

function install_omo_slim()
{
    echo "Install oh-my-opencode-slim..."
    bunx oh-my-opencode-slim@latest install
    # 把 omo-slim-profile.json 融合进已有的 oh-my-opencode-slim.json
    local src="$PWD/omo-slim-profile.json"
    local dst="$CONFIG_DIR/oh-my-opencode-slim.json"
    if [ -f "$src" ] && [ -f "$dst" ]; then
        jq -s '.[0] * .[1]' "$dst" "$src" > "${dst}.tmp" \
            && mv "${dst}.tmp" "$dst" \
            && echo "Merged omo-slim-profile.json into $dst"
    fi
    bunx oh-my-opencode-slim@latest doctor
    # 默认情况下关闭slim
    set_env OH_MY_OPENCODE_SLIM_DISABLE 1
    set_env OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS true
    set_env OPENCODE_ENABLE_EXA 1
}

function install_officecli()
{
    echo "Install officecli..."
    if have apt; then
        # libicu 是 officecli(.NET) 的运行时依赖
        sudo apt update || true
        sudo apt install -y libicu-dev
    elif have dnf; then
        sudo dnf install -y libicu
    elif have yum; then
        sudo yum install -y libicu
    elif have pacman; then
        sudo pacman -S --noconfirm --needed icu
    fi
    sudo npm install -g @officecli/officecli --allow-scripts=@officecli/officecli
    if command -v officecli >/dev/null 2>&1; then
        officecli install codex  # install skill to ~/.agents/skills
    fi
}

function install_book_to_skill()
{
    echo "Install book-to-skill..."
    npx skills add virgiliojr94/book-to-skill -g -y --skill book-to-skill --agent opencode
    if python3 -c 'import sys; sys.exit(0 if sys.version_info > (3, 9) else 1)'; then
        if pip_supports_break_system_packages; then
            pip install --break-system-packages pypdf docling
        else
            pip install pypdf docling
        fi
    else
        install_uv_if_needed
        # use uv env
        uv tool install --python 3.11 docling --with pypdf
    fi
}

function install_plannotator()
{
    echo "Install plannotator..."
    # --minimal: 只装二进制, 不写 skills/hooks/各 agent 集成
    curl -fsSL https://plannotator.ai/install.sh | bash -s -- --minimal
    if ! have plannotator; then
        echo "plannotator 不可用: 安装失败, 或 $HOME/.local/bin 不在 PATH 中"
        return 1
    fi
    # --minimal 不装 agent-terminal 运行时, 单独补(annotate 模式的内置终端, 需要 node/npm)
    plannotator install-runtime agent-terminal \
        || echo "agent-terminal 运行时安装失败, annotate 模式将没有内置终端"

    # 最后一步: 幂等写入 OpenCode 插件配置
    jq --arg pkg "@plannotator/opencode" \
       --arg latest "@plannotator/opencode@latest" \
       --argjson opts '{"workflow":"plan-agent","planningAgents":["plan","orchestrator"]}' '
        .plugin = (((.plugin // []) | map(select(
            if type == "array" then (.[0] // "" | startswith($pkg) | not)
            elif type == "string" then (startswith($pkg) | not)
            else true end
        ))) + [[$latest, $opts]])
    ' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE" \
        && echo "Configured plannotator plugin in $CONFIG_FILE"
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
"codegraph|codegraph|代码图谱(适合单一代码库, 查询调用链与依赖)"
"codebase_memory|codebase-memory|代码图谱(适合多语言混合代码库, 整理依赖关系)"
"omo_slim|oh-my-opencode-slim|多模型 agent 编排插件"
"omniroute|omniroute|LLM 网关统一管理APIKEY"
"ocr|open-code-review|代码质量评审"
"openspec|openspec|规范驱动开发(旧项目:提案/规范/归档)"
"speckit|speckit|规范驱动开发(新项目:规格→计划→任务→实现)"
"officecli|officecli|处理 docx/xlsx/pptx"
"caveman|caveman|压缩上下文内容 节省token"
"graphify|graphify|绘制代码知识图谱(包含项目文档和资料)"
"drawio|drawio|绘制图表 (desktop + skill)"
"cua|cua-driver|后台驱动桌面应用"
"agentmemory|agentmemory|agent 记忆"
"archify|archify-skill|绘制架构/流程/时序图 skill"
"book_to_skill|book-to-skill|书籍/文档转 skill"
"browser_skill|browser-skill|接管已登录浏览器的自动化 skill"
"plannotator|plannotator|plan/代码评审 UI (浏览器标注)"
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
    codegraph)
        have codegraph && ITEM_CMD=codegraph
        ;;
    codebase_memory)
        have codebase-memory-mcp && ITEM_CMD=codebase-memory-mcp
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
    openspec)
        have openspec && ITEM_CMD=openspec
        ;;
    speckit)
        have specify && ITEM_CMD=specify
        ;;
    officecli)
        have officecli && ITEM_CMD=officecli
        ;;
    caveman)
        jq -e '.agents["cavecrew-builder"]' "$CONFIG_FILE" >/dev/null 2>&1
        ;;
    graphify)
        have graphify && ITEM_CMD=graphify
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
    plannotator)
        have plannotator && ITEM_CMD=plannotator
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
    codegraph)
        install_codegraph
        ;;
    codebase_memory)
        install_codebase_memory
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
    openspec)
        install_openspec
        ;;
    speckit)
        install_speckit
        ;;
    officecli)
        install_officecli
        ;;
    caveman)
        install_caveman
        ;;
    graphify)
        install_graphify
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
    plannotator)
        install_plannotator
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
    echo "  ./install.sh --env           检查并安装基础依赖"
    echo "  ./install.sh --<component>   安装指定组件, 可组合多个"
    echo ""
    echo "每次运行都会先检测基础依赖, 并同步默认配置:"
    echo "  rsync 配置到 ~/.config/opencode, 并安装全局 skills"
    echo "  --list / --help / --env 不会执行默认配置同步"
    echo ""
    echo "options:"
    echo "  --rtk:                   安装 rtk, 压缩命令输出以节省 token"
    echo "  --codegraph:             安装 codegraph, 生成代码图谱(适合单一代码库架构, 查询调用链与依赖)"
    echo "  --codebase-memory:       安装 codebase-memory-mcp, 生成代码图谱(适合多语言混合代码库, 整理依赖关系)"
    echo "  --omo-slim:              安装 oh-my-opencode-slim, 多模型 agent 编排插件"
    echo "  --omniroute:             安装 omniroute, 用于LLM 网关统一管理APIKEY"
    echo "  --ocr:                   安装 open-code-review, 用于代码评审"
    echo "  --openspec:              安装 openspec, 规范驱动开发(旧项目:提案/规范/归档)"
    echo "  --speckit:               安装 speckit, 规范驱动开发(新项目:规格→计划→任务→实现)"
    echo "  --officecli:             安装 officecli, 处理 docx/xlsx/pptx 文档"
    echo "  --caveman:               安装 caveman, 压缩上下文内容 节省token"
    echo "  --graphify:              安装 graphify, 绘制代码知识图谱(包含项目文档和资料)"
    echo "  --drawio:                安装 drawio, 绘制图表"
    echo "  --cua:                   安装 cua-driver, 后台驱动桌面应用"
    echo "  --agentmemory:           安装 agentmemory, 为 agent 提供记忆"
    echo "  --archify-skill:         安装 archify skill, 绘制架构/流程/时序图"
    echo "  --book-to-skill:         安装 book-to-skill, 把书籍/文档转成 skill"
    echo "  --browser-skill:         安装 Tencent BrowserSkill, 复用浏览器登录态做自动化"
    echo "  --plannotator:           安装 plannotator, plan/代码评审 UI(浏览器标注)"
    echo ""
}

function flag_to_key()
{
    # $1=命令行参数 -> 输出 key (未知则返回 1)
    case "$1" in
    --rtk)
        echo "rtk"
        ;;
    --codegraph)
        echo "codegraph"
        ;;
    --codebase-memory)
        echo "codebase_memory"
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
    --openspec)
        echo "openspec"
        ;;
    --speckit)
        echo "speckit"
        ;;
    --officecli)
        echo "officecli"
        ;;
    --caveman)
        echo "caveman"
        ;;
    --graphify)
        echo "graphify"
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
    --archify-skill)
        echo "archify"
        ;;
    --book-to-skill)
        echo "book_to_skill"
        ;;
    --browser-skill)
        echo "browser_skill"
        ;;
    --plannotator)
        echo "plannotator"
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
