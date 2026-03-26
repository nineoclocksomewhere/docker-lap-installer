#!/usr/bin/env bash
set -e

# Prio 1: provided as argument
if [[ "$1" != "" ]]; then
    COMPOSER_VERSION="$1"
fi
# Prio 2: not provided as argument, env var is not set, try to use env var DOCKER_COMPOSER_VERSION
if [[ "$COMPOSER_VERSION" == "" ]]; then
    COMPOSER_VERSION="${DOCKER_COMPOSER_VERSION:-}"
fi
# Prio 3: use "latest" as fallback
if [[ "$COMPOSER_VERSION" == "" ]]; then
    COMPOSER_VERSION="latest"
fi

echo "Using Composer version: $COMPOSER_VERSION"

if [[ "${COMPOSER_VERSION,,}" == "latest" || "${COMPOSER_VERSION,,}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then

    COMPOSER_BIN="/usr/local/bin/composer-${COMPOSER_VERSION}"

    if [[ ! -f "$COMPOSER_BIN" ]]; then

        echo "Installing Composer version ${COMPOSER_VERSION}"
        mkdir -p /tmp/composer-installer-$COMPOSER_VERSION && cd /tmp/composer-installer-$COMPOSER_VERSION  

        COMPOSER_HASH=$( curl -s https://composer.github.io/installer.sig )
        php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
        php -r "if (hash_file('sha384', 'composer-setup.php') === '${COMPOSER_HASH}') { echo \"Composer installer verified\".PHP_EOL; } else { echo \"Composer installer corrupt\".PHP_EOL; unlink('composer-setup.php'); if (file_exists('composer-setup.php')) { echo \"Removing \".realpath('composer-setup.php').\" failed\".PHP_EOL; } }"

	if [[ -f "composer-setup.php" ]]; then
            echo "Composer installer saved as $( realpath 'composer-setup.php' )"
            echo "Running composer-setup.php"
            echo "For available Composer versions, check: https://github.com/composer/composer/releases"
            if [[ "$COMPOSER_VERSION" != "latest" ]]; then
                echo "Running Composer setup version $COMPOSER_VERSION"
                php composer-setup.php --version="$COMPOSER_VERSION"
            else
                echo "Running latest Composer version setup"
                php composer-setup.php
            fi

            if [[ ! $? -eq 0 ]]; then
                echo -e "\033[031mError: installing Composer failed, aborting\033[0m"
                exit 1
            fi

            echo "Removing composer-setup.php"
            php -r "unlink('composer-setup.php'); if (file_exists('composer-setup.php')) { echo \"Removing \".realpath('composer-setup.php').\" failed\".PHP_EOL; }"

            if [[ -f composer.phar ]]; then
                chmod +x composer.phar
                if [[ ! -d /usr/local/bin ]]; then
                    mkdir -p /usr/local/bin
                fi
                echo "Moving $( realpath composer.phar ) to ${COMPOSER_BIN}"
                mv -f composer.phar "${COMPOSER_BIN}"
                echo "Cleaning up the composer installer"
                cd && rm -rf /tmp/composer-installer-${COMPOSER_VERSION}
            else
                echo -e "\033[031mError: composer.phar not found, aborting\033[0m"
                exit 1
            fi
        else
            echo -e "\033[031mError: installing Composer version ${COMPOSER_VERSION} failed, aborting\033[0m"
            exit 1
        fi

        if [[ -f "${COMPOSER_BIN}" ]]; then
            echo -e "\033[032mComposer version ${COMPOSER_VERSION} is now installed!\033[0m"
            "${COMPOSER_BIN}" --version
        else
            echo -e "\033[031mError: installing Composer version ${COMPOSER_VERSION} failed, aborting\033[0m"
            exit 1
        fi
    fi

    if [[ -f "${COMPOSER_BIN}" ]]; then
        echo "Using composer version ${COMPOSER_VERSION}"
        if [[ -f /usr/local/bin/composer ]]; then
            echo "Removing old composer symlink"
            rm -rf /usr/local/bin/composer
        fi
        ln -s "${COMPOSER_BIN}" /usr/local/bin/composer
        composer --version
    fi

fi