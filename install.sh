#!/bin/bash

function copy_oac_config()
{
    echo "copy oac developer config to $1"

    if [ ! -d "$1" ]; then
         mkdir -p "$1"
    fi

    if [ ! -f "$1/.env" ]; then
        cp .opencode/env.example "$1/.env"
    fi

    rsync -av  --exclude='README.md' \
               --exclude='env.example' \
               --exclude='command/clean.md' \
               --exclude='command/test.md' \
               --exclude='command/validate-repo.md' \
               .opencode/ "$1"
}

function main()
{
    case "$1" in
    -u )
        echo "update OpenAgentsControl developer"
        curl -fsSL https://raw.githubusercontent.com/darrenhinde/OpenAgentsControl/main/install.sh | bash -s developer
        ;;
    -g )
        echo "copy global config to $HOME/.config/opencode"
        cp global/* "$HOME/.config/opencode" -a
        ;;
    -l )
        copy_oac_config "${2:-$HOME/.opencode}"
        ;;
    * )
        curl -fsSL https://raw.githubusercontent.com/darrenhinde/OpenAgentsControl/main/install.sh | bash -s developer
        cp global/* "$HOME/.config/opencode" -a
        copy_oac_config "${1:-$HOME/.opencode}"
        ;;
    esac
}
# 调用main函数
main "$@"
