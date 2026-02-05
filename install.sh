#!/bin/bash
set -e

TARGET_DIR="${1:-$HOME/.opencode}"

curl -fsSL https://raw.githubusercontent.com/darrenhinde/OpenAgentsControl/main/install.sh | bash -s developer

cp global/* $HOME/.config/opencode -a

if [ ! -f "$TARGET_DIR/.env" ]; then
    cp .opencode/env.example $TARGET_DIR/.env
fi

rsync -av  --exclude='README.md' \
           --exclude='env.example' \
           --exclude='command/clean.md' \
           --exclude='command/test.md' \
           --exclude='command/validate-repo.md' \
           .opencode/ $TARGET_DIR
