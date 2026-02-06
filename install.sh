#!/bin/bash

function rsync_oac_config()
{
    echo "rsync oac developer config to $1"

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
        rm -rf .opencode
        curl -fsSL https://raw.githubusercontent.com/darrenhinde/OpenAgentsControl/main/install.sh | bash -s developer
        ;;
    * )
        echo "copy global config to $HOME/.config/opencode"
        cp -auv global/* "$HOME/.config/opencode"
        rsync_oac_config "${1:-$HOME/.opencode}"
        ;;
    esac
}
# 调用main函数
main "$@"
