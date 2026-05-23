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

function update_skills()
{
    git clone https://github.com/bahayonghang/drawio-skills.git
    cp -auv drawio-skills/skills/* skills
    rm -rf drawio-skills
}

function main()
{
    if ! which opencode >/dev/null 2>&1; then
        echo "install opencode"
        curl -fsSL https://opencode.ai/install | bash
    fi

    case "$1" in
    --update )
        update_skills
        echo "update OpenAgentsControl developer"
        curl -fsSL https://raw.githubusercontent.com/darrenhinde/OpenAgentsControl/main/install.sh | bash -s developer
        if [ -d .opencode ]; then
            cp developer/opencode.json .opencode
            rm -rf developer
            mv .opencode developer
        fi
        ;;
    --oac )
        rsync_developer_config "${2:-$HOME/.opencode}"
        ;;
    --markitdown )
        git clone https://github.com/microsoft/markitdown
        cd markitdown
        docker build -t markitdown:latest .
        cd -
        rm -rf markitdown
        ;;
    * )
        echo "install global config to $HOME/.config/opencode"
        cp opencode.json "$HOME/.config/opencode"
        cp -auv agents "$HOME/.config/opencode"
        cp -auv rules "$HOME/.config/opencode"

        echo "install codegraph"
        sudo npm install -g @colbymchenry/codegraph
        npx @colbymchenry/codegraph

        echo "install skills to $HOME/.agents/skills"
        # npx skills add Option         Description
        # -g, --global                  Install to user directory instead of project
        # -a, --agent <agents...>       Target specific agents (e.g., claude-code, codex). See Available Agents
        # -s, --skill <skills...>       Install specific skills by name (use '*' for all skills)
        # -l, --list                    List available skills without installing
        # --copy                        Copy files instead of symlinking to agent directories
        # -y, --yes	                    Skip all confirmation prompts
        # --all	                        Install all skills to all agents without prompts

        # Local path
        npx skills add ./skills -g -y --skill drawio
        # GitHub shorthand (owner/repo)
        #npx skills add vercel-labs/skills -g -y --skill find-skills
        if [ -n "$(docker images -q markitdown)" ]; then
            npx skills add ./skills -g -y --skill markitdown
        else
            npx skills add anthropics/skills -g -y --skill pdf --skill docx --skill pptx --skill xlsx
        fi
        # Direct path to a skill in a repo
        #npx skills add https://github.com/bahayonghang/drawio-skills/tree/main/skills/drawio -g -y
        # Any git URL
        #npx skills add git@github.com:vercel-labs/agent-skills.git
        #npx skills update

        echo ""
        echo "options:"
        echo "--update: update OpenAgentsControl developer"
        echo "--oac: install OpenAgentsControl for specific project"
        echo "--markitdown: install markitdown docker"
        ;;
    esac
}
# 调用main函数
main "$@"
