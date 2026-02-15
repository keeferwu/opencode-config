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

    if [ ! -f "$target/.env" ]; then
        cp .opencode/env.example "$target/.env"
    fi
    cp openagent.json "$target/opencode.json"

    rsync -av  --exclude='README.md' \
               --exclude='env.example' \
               --exclude='command/clean.md' \
               --exclude='command/test.md' \
               --exclude='command/validate-repo.md' \
               --exclude='command/openagents' \
               .opencode/ "$target"
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
