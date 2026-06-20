#!/bin/bash

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
               developer/ "$target"

    if [ ! -f "$target/.env" ]; then
        cp developer/env.example "$target/.env"
    fi
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
            mv .opencode developer
        fi
        rsync_developer_config "${2:-$HOME/.opencode}"
        ;;
    --markitdown )
        git clone https://github.com/microsoft/markitdown
        cd markitdown
        docker build -t markitdown:latest .
        cd -
        rm -rf markitdown
        ;;
    --drawio )
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
    --usat )
        curl -fsSL https://raw.githubusercontent.com/Lum1104/Understand-Anything/main/install.sh | bash -s opencode
        echo "Create $HOME/.understand-anything/repo"
        echo "Create link $HOME/.understand-anything-plugin"
        echo "Create link $HOME/.agents/skills/undstand*"
        ;;
    --graphify )
        # base Python 3.10+
        pip install graphifyy
        graphify install --platform opencode
        graphify opencode install   #安装常驻助手规则 AGENTS.md 到当前项目
        ;;
    --context7 )
        # install context7 mcp
        npx ctx7 setup --opencode
        ;;
    --help )
        echo ""
        echo "options:"
        echo "--oac: install OpenAgentsControl for specific project"
        echo "--markitdown: install markitdown docker, use for translate file to markdown"
        echo "--drawio: install drawio, use for draw diagram"
        echo "--comet: install comet, use for comet openspec and superpowers"
        echo "--usat: install understand-anything, use for understand code"
        echo "--graphify: install graphify, use for drawing knowledge maps"
        echo "--context7: install context7 mcp, use for up-to-date library docs"
        ;;
    * )
        echo "Install global config to $HOME/.config/opencode"
        cp opencode.json "$HOME/.config/opencode"
        cp opencode-mem.jsonc "$HOME/.config/opencode"
        cp -auv agents "$HOME/.config/opencode"
        cp -auv commands "$HOME/.config/opencode"
        cp -auv rules "$HOME/.config/opencode"
        cp -auv skills "$HOME/.config/opencode"
        # remove plugin cache
        rm -rf $HOME/.cache/opencode/packages/*

        #npx @colbymchenry/codegraph
        #rm -rf $HOME/.config/opencode/commands/codebase.md
        #echo "Install codegraph"
        #sudo npm install -g @colbymchenry/codegraph

        #curl -fsSL https://raw.githubusercontent.com/DeusData/codebase-memory-mcp/main/install.sh | bash
        rm -rf $HOME/.config/opencode/commands/codegraph.md
        echo "Install codebase-memory-mcp"
        sudo npm install -g codebase-memory-mcp

        # base rust
        echo "Install rtk"
        curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
        if which rtk >/dev/null 2>&1; then
            rtk init -g --opencode
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
        npx skills add Agents365-ai/drawio-skill -g -y --skill drawio-skill --agent opencode
        npx skills add mattpocock/skills -g -y --skill improve-codebase-architecture --skill codebase-design --skill grilling --skill domain-modeling --agent opencode
        #npx skills add kepano/obsidian-skills -g -y --agent opencode
        #npx skills add anthropics/skills -g -y --skill pdf --skill docx --skill pptx --skill xlsx --agent opencode
        # Direct path to a skill in a repo
        #npx skills add https://github.com/bahayonghang/drawio-skills/tree/main/skills/drawio -g -y
        #npx skills update

        echo "Start opencode and ask:'check ~/.cache/opencode/packages/opencode-mem@latest work or not'"
        ;;
    esac
}
# 调用main函数
main "$@"
