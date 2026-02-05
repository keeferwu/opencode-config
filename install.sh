
curl -fsSL https://raw.githubusercontent.com/darrenhinde/OpenAgentsControl/main/install.sh | bash -s developer

cp global/* ~/.config/opencode/ -a
cp .opencode/env.example ~/.opencode/.env
rsync -av  --exclude='README.md' \
           --exclude='env.example' \
           --exclude='command/clean.md' \
           --exclude='command/test.md' \
           --exclude='command/validate-repo.md' \
           .opencode/ ~/.opencode
