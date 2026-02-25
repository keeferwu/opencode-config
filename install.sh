#!/bin/bash

function rsync_oac_config()
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

    rsync -av  --exclude='bun.lock' \
               --exclude='.gitignore' \
               --exclude='node_modules' \
               --exclude='package.json' \
               --exclude='README.md' \
               --exclude='env.example' \
               --exclude='command/clean.md' \
               --exclude='command/test.md' \
               --exclude='command/validate-repo.md' \
               --exclude='command/openagents' \
               .opencode/ "$target"

    if [ ! -f "$target/.env" ]; then
        cp .opencode/env.example "$target/.env"
    fi
    cp openagent.json "$target/opencode.json"
}

function install_superpowers()
{
    git clone https://github.com/obra/superpowers.git
    mkdir -p "$1/plugins"
    cp superpowers/.opencode/plugins/superpowers.js "$1/plugins"

    mkdir -p "$1/skills/superpowers"
    cp -auv superpowers/skills/* "$1/skills/superpowers"

    rm -rf superpowers
}

function update_global_skills()
{
    git clone https://github.com/anthropics/skills.git anthropics-skills
    cp -auv anthropics-skills/skills/* config/skills
    rm -rf anthropics-skills
}

function main()
{
    if ! which opencode >/dev/null 2>&1; then
        echo "install opencode"
        curl -fsSL https://opencode.ai/install | bash
    fi

    case "$1" in
    --update )
        echo "update global skills"
        update_global_skills
        echo "update OpenAgentsControl developer"
        rm -rf .opencode
        curl -fsSL https://raw.githubusercontent.com/darrenhinde/OpenAgentsControl/main/install.sh | bash -s developer
        ;;
    --superpowers )
        if [ ! -d "$2" ]; then
            echo "dir $2 does not exist"
            exit 1
        fi
        echo "install superpowers to $2/.opencode"
        install_superpowers "$2/.opencode"
        ;;
    --oac )
        rsync_oac_config "${2:-$HOME/.opencode}"
        ;;
    * )
        echo "rsync global config to $HOME/.config/opencode"
        rsync -av --exclude='skills' config/ "$HOME/.config/opencode"
        mkdir -p "$HOME/.config/opencode/skills"
        cp -auv config/skills/skill-creator \
                config/skills/internal-comms \
                config/skills/pdf \
                config/skills/docx \
                config/skills/pptx \
                config/skills/xlsx \
        "$HOME/.config/opencode/skills"

        echo ""
        echo "options:"
        echo "--update: update OpenAgentsControl developer"
        echo "--oac: install OpenAgentsControl to specified dir, use for existing project"
        echo "--superpowers: install superpowers to specified dir, use for create new project"
        ;;
    esac
}
# 调用main函数
main "$@"
