#!/usr/bin/env bash
set -e

# Prio 1: provided as argument
if [[ "$1" != "" ]]; then
    NODE_VERSION="$1"
elif [[ "$NODE_VERSION" == "" ]]; then
    NODE_VERSION="${DOCKER_FORCE_NODE_VERSION:-}"
    if [[ -z "$NODE_VERSION" && -f /var/www/html/.nvmrc ]]; then
        NODE_VERSION="$(< /var/www/html/.nvmrc tr -d '[:space:]')"
    fi
    if [[ -z "$NODE_VERSION" ]]; then
        NODE_VERSION="${DOCKER_NODE_VERSION:-}"
    fi
    NODE_VERSION="${NODE_VERSION:-lts/hydrogen}"
fi

echo "Using NodeJS version: $NODE_VERSION"

USERS=("docker")

for V_NODE_USER in "${USERS[@]}"; do
    su -l $V_NODE_USER -c "
        set -e
        export HOME=$(eval echo "~$V_NODE_USER")
        NVM_DIR=\"\$HOME/.nvm\"

        # Install nvm if missing
        if [[ ! -s \"\$NVM_DIR/nvm.sh\" ]]; then
            echo 'Installing nvm for user $V_NODE_USER'
            curl -s -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.6/install.sh | bash
        fi

        # Source nvm.sh
        if [[ -s \"\$NVM_DIR/nvm.sh\" ]]; then
            . \"\$NVM_DIR/nvm.sh\"
        else
            echo 'ERROR: nvm.sh not found for user $V_NODE_USER' >&2
            exit 1
        fi

        # Install Node version if missing
        if ! nvm ls \"$NODE_VERSION\" >/dev/null 2>&1; then
            echo \"Installing NodeJS $NODE_VERSION for $V_NODE_USER\"
            nvm install \"$NODE_VERSION\"
        fi

        nvm alias default \"$NODE_VERSION\"
        nvm use default

        # Disabled
        # npm_config_engine_strict=false npm install -g npm@latest
    "
done
