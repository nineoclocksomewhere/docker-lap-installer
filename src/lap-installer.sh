#!/usr/bin/env bash

V_SCRIPT_VERSION="1.0.30"

# First, an introduction
echo -e "\n\033[036m────────────────────────────────────────────────────────────────────────────────\033[0m\n"
echo -ne "\033[036mLet me introduce myself:\033[0m\n\033[0mI am \033[093m$( whoami )\033[0m, \033[093m"
echo -ne $(( $( date +%s ) - $( stat -c %W $HOME ) ))
echo -e "\033[0m seconds old, live at \033[093m${HOME}\033[0m but currently staying at \033[093m$( pwd )\033[0m."
echo -e "\n\033[036m────────────────────────────────────────────────────────────────────────────────\033[0m\n"

# We need to be root
if [[ ! "$( whoami )" == "root" ]]; then
    echo -e "\033[031mError: this script needs to run as the root user, aborting\033[0m"
    echo -e "\n\033[036m────────────────────────────────────────────────────────────────────────────────\033[0m\n"
    exit 1
fi

# Check if the installation is up-to-date
if [[ -f /usr/share/docker/lap-installer.version ]]; then
    V_CURRENT_VERSION=$( cat /usr/share/docker/lap-installer.version )
else
    V_CURRENT_VERSION=""
fi
if [[ "$V_CURRENT_VERSION" == "$V_SCRIPT_VERSION" ]]; then
    echo -e "\033[032mInstallation is up-to-date\033[0m (\033[036mv${V_CURRENT_VERSION}\033[0m)"
    echo -e "\n\033[036m────────────────────────────────────────────────────────────────────────────────\033[0m\n"
    exit 0
fi

# Say why we re-check it all
if [[ ! -f /usr/share/docker/lap-installer.version ]]; then
    echo -e "\033[033mInstallation never executed for this container, installing \033[036mv${V_SCRIPT_VERSION}\033[033m now\033[0m"
else
    rm /usr/share/docker/lap-installer.version > /dev/null 2>&1
    echo -e "\033[033mInstallation outdated (current: \033[091m${V_CURRENT_VERSION}\033[033m, required: \033[092m${V_SCRIPT_VERSION}\033[033m), updating now\033[0m"
fi
echo -e "\n\033[036m────────────────────────────────────────────────────────────────────────────────\033[0m\n"

# User configuration - Part 1/2
echo -e "Checking \033[036muser\033[0m configuration (Part 1/2)"
V_GID="${PGID:-1000}"
V_GROUP="${DOCKER_GROUP_NAME:-docker}"
V_UID="${PUID:-1000}"
V_USER="${DOCKER_USER_NAME:-docker}"
V_SECRET="${DOCKER_USER_SECRET:-secret}"
if [[ $( getent group $V_GROUP | wc -l ) -eq 0 ]]; then
    echo -e "Creating group \033[036m${V_GROUP}\033[0m with GID \033[036m${V_GID}\033[0m"
    groupadd -g $V_GID -o $V_GROUP
else
    echo -e "Group \033[036m${V_GROUP}\033[0m already exists"
fi
getent group $V_GROUP
V_BASHRC_CREATED=0
if id "$V_USER" &>/dev/null; then
    echo -e "User \033[036m${V_USER}\033[0m already exists"
    V_USER_CREATED=0
else
    echo -e "Creating user \033[036m${V_USER}\033[0m with UID \033[036m${V_UID}\033[0m"
    useradd -u $V_UID -g $V_GROUP -s /bin/bash $V_USER
    # Why not using the -m parameter above?
    # -> The docker's home folder could already be created as mounted volume, so we check it later.
    if [[ ! -d /home/$V_USER ]]; then mkdir -p /home/$V_USER; fi
    chown $V_USER:$V_GROUP /home/$V_USER # Just to be sure, always
    usermod -d /home/$V_USER $V_USER
    V_USER_CREATED=1
fi
echo -e "\n\033[036m────────────────────────────────────────────────────────────────────────────────\033[0m\n"

# Basic packages
echo -e "Verifying if \033[036mall basic packages\033[0m are installed"
apt-get update && apt-get install -y \
    coreutils \
    libfreetype6-dev \
    libgd-dev \
    libpng-dev \
    libjpeg-dev \
    libonig-dev \
    libpng-dev \
    libwebp-dev \
    libxml2-dev \
    p7zip \
    sudo \
    ssh \
    coreutils \
    git \
    vim \
    webp \
    wget \
    mariadb-client \
    iputils-ping \
    htop \
    libzip-dev \
    zlib1g \
    cron \
    zip \
    rsync \
    unzip \
    memcached \
    libmemcached-dev
echo -e "\033[032mDone\033[0m"
echo -e "\n\033[036m────────────────────────────────────────────────────────────────────────────────\033[0m\n"

# WKHTMLTOPDF
[[ "$DOCKER_INSTALL_WKHTMLTOPDF" == "" ]] && export DOCKER_INSTALL_WKHTMLTOPDF="no"
echo -e "DOCKER_INSTALL_WKHTMLTOPDF=\033[036m${DOCKER_INSTALL_WKHTMLTOPDF}\033[036m"
if [[ "${DOCKER_INSTALL_WKHTMLTOPDF,,}" =~ ^(y|yes|1|true)$ ]]; then
    echo -e "Installing \033[036mwkhtmltopdf\033[0m"
    apt-get install -y \
        wkhtmltopdf
else
    echo -e "\033[033mSkipping \033[036mwkhtmltopdf\033[033m install\033[0m"
fi
echo -e "\n\033[036m────────────────────────────────────────────────────────────────────────────────\033[0m\n"

# Image Optimizers
[[ "$DOCKER_INSTALL_IMAGE_OPTIMIZERS" == "" ]] && export DOCKER_INSTALL_IMAGE_OPTIMIZERS="yes"
echo -e "DOCKER_INSTALL_IMAGE_OPTIMIZERS=\033[036m${DOCKER_INSTALL_IMAGE_OPTIMIZERS}\033[036m"
if [[ "${DOCKER_INSTALL_IMAGE_OPTIMIZERS,,}" =~ ^(y|yes|1|true)$ ]]; then
    echo -e "Installing \033[036mImage Optimizers\033[0m"
    apt-get install -y \
        jpegoptim \
        gifsicle \
        optipng \
        pngquant
else
    echo -e "\033[033mSkipping \033[036mImage Optimizers\033[033m install\033[0m"
fi
echo -e "\n\033[036m────────────────────────────────────────────────────────────────────────────────\033[0m\n"

# PHP extensions list: https:/127.0.0.1/github.com/mlocati/docker-php-extension-installer#supported-php-extensions
V_PHP_MAJOR_VERSION=$( php -r "echo explode('.', phpversion())[0];" )
V_PHP_MAJOR_VERSION=$(( $V_PHP_MAJOR_VERSION * 1 ))
echo -e "PHP major version: \033[036m${V_PHP_MAJOR_VERSION}\033[0m"
V_PHP_MINOR_VERSION=$( php -r "echo explode('.', phpversion())[1];" )
V_PHP_MINOR_VERSION=$(( $V_PHP_MINOR_VERSION * 1 ))
echo -e "PHP minor version: \033[036m${V_PHP_MINOR_VERSION}\033[0m"
echo

echo -e "Checking \033[036mPHP extensions\033[0m"
if [[ $( php -m | grep 'zip' | wc -l ) -eq 0 ]]; then
    echo -e "\nInstalling PHP extension \033[036mzip\033[0m"
    docker-php-ext-configure zip --with-libzip
    docker-php-ext-install -j$(nproc) zip
else
    echo -e "\nPHP extension \033[036mzip\033[0m already installed"
fi

if [[ $( php -m | grep 'memcached' | wc -l ) -eq 0 ]]; then
    echo -e "\nInstalling PHP extension \033[036mmemcached\033[0m"
    # ref: https://bobcares.com/blog/docker-php-ext-install-memcached/
    # ref: https://github.com/php-memcached-dev/php-memcached/issues/408
    if [[ $V_PHP_MAJOR_VERSION -eq 7 ]]; then
        set -ex \
            && apt-get update \
            && DEBIAN_FRONTEND=noninteractive apt-get install -y libmemcached-dev \
            && rm -rf /var/lib/apt/lists/* \
            && MEMCACHED=/usr/src/php/ext/memcached \
            && mkdir -p "$MEMCACHED" \
            && curl -skL https://github.com/php-memcached-dev/php-memcached/archive/master.tar.gz | tar zxf - --strip-components 1 -C $MEMCACHED \
            && docker-php-ext-configure $MEMCACHED \
            && docker-php-ext-install $MEMCACHED
    fi
else
    echo -e "\nPHP extension \033[036mmemcached\033[0m already installed"
fi

[[ "$DOCKER_INSTALL_PHP_GD" == "" ]] && export DOCKER_INSTALL_PHP_GD="yes"; echo -e "DOCKER_INSTALL_PHP_GD=\033[036m${DOCKER_INSTALL_PHP_GD}\033[036m"
if [[ "${DOCKER_INSTALL_PHP_GD,,}" =~ ^(y|yes|1|true)$ ]]; then
    if [[ $( php -m | grep 'gd' | wc -l ) -eq 0 ]]; then
        echo -e "\nInstalling PHP extension \033[036mgd\033[0m"
        if [[ $V_PHP_MAJOR_VERSION -eq 7 && $V_PHP_MINOR_VERSION -le 3 ]]; then
            docker-php-ext-configure gd --with-freetype-dir=/usr/lib --with-png-dir=/usr/lib --with-jpeg-dir=/usr/lib && docker-php-ext-install -j$(nproc) gd
        else
            docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp && docker-php-ext-install -j$(nproc) gd
        fi
    else
        echo -e "\nPHP extension \033[036mgd\033[0m already installed"
    fi
fi

[[ "$DOCKER_INSTALL_PHP_PDO_MYSQL" == "" ]] && export DOCKER_INSTALL_PHP_PDO_MYSQL="yes"; echo -e "DOCKER_INSTALL_PHP_PDO_MYSQL=\033[036m${DOCKER_INSTALL_PHP_PDO_MYSQL}\033[036m"
if [[ "${DOCKER_INSTALL_PHP_PDO_MYSQL,,}" =~ ^(y|yes|1|true)$ ]]; then
    if [[ $( php -m | grep 'pdo_mysql' | wc -l ) -eq 0 ]]; then
        echo -e "\nInstalling PHP extension \033[036mpdo_mysql\033[0m"
        docker-php-ext-install -j$(nproc) pdo_mysql
    else
        echo -e "\nPHP extension \033[036mpdo_mysql\033[0m already installed"
    fi
fi

[[ "$DOCKER_INSTALL_PHP_MYSQLI" == "" ]] && export DOCKER_INSTALL_PHP_MYSQLI="yes"; echo -e "DOCKER_INSTALL_PHP_MYSQLI=\033[036m${DOCKER_INSTALL_PHP_MYSQLI}\033[036m"
if [[ "${DOCKER_INSTALL_PHP_MYSQLI,,}" =~ ^(y|yes|1|true)$ ]]; then
    if [[ $( php -m | grep 'mysqli' | wc -l ) -eq 0 ]]; then
        echo -e "\nInstalling PHP extension \033[036mmysqli\033[0m"
        docker-php-ext-install -j$(nproc) mysqli
    else
        echo -e "\nPHP extension \033[036mmysqli\033[0m already installed"
    fi
fi

[[ "$DOCKER_INSTALL_PHP_EXIF" == "" ]] && export DOCKER_INSTALL_PHP_EXIF="yes"; echo -e "DOCKER_INSTALL_PHP_EXIF=\033[036m${DOCKER_INSTALL_PHP_EXIF}\033[036m"
if [[ "${DOCKER_INSTALL_PHP_EXIF,,}" =~ ^(y|yes|1|true)$ ]]; then
    if [[ $( php -m | grep 'exif' | wc -l ) -eq 0 ]]; then
        echo -e "\nInstalling PHP extension \033[036mexif\033[0m"
        docker-php-ext-install -j$(nproc) exif
    else
        echo -e "\nPHP extension \033[036mexif\033[0m already installed"
    fi
fi

[[ "$DOCKER_INSTALL_PHP_SOCKETS" == "" ]] && export DOCKER_INSTALL_PHP_SOCKETS="yes"; echo -e "DOCKER_INSTALL_PHP_SOCKETS=\033[036m${DOCKER_INSTALL_PHP_SOCKETS}\033[036m"
if [[ "${DOCKER_INSTALL_PHP_SOCKETS,,}" =~ ^(y|yes|1|true)$ ]]; then
    if [[ $( php -m | grep 'sockets' | wc -l ) -eq 0 ]]; then
        echo -e "\nInstalling PHP extension \033[036msockets\033[0m"
        docker-php-ext-install -j$(nproc) sockets
    else
        echo -e "\nPHP extension \033[036msockets\033[0m already installed"
    fi
fi

[[ "$DOCKER_INSTALL_PHP_SOAP" == "" ]] && export DOCKER_INSTALL_PHP_SOAP="no"; echo -e "DOCKER_INSTALL_PHP_SOAP=\033[036m${DOCKER_INSTALL_PHP_SOAP}\033[036m"
if [[ "${DOCKER_INSTALL_PHP_SOAP,,}" =~ ^(y|yes|1|true)$ ]]; then
    if [[ $( php -m | grep 'soap' | wc -l ) -eq 0 ]]; then
        echo -e "\nInstalling PHP extension \033[036msoap\033[0m"
        docker-php-ext-install -j$(nproc) soap
    else
        echo -e "\nPHP extension \033[036msoap\033[0m already installed"
    fi
fi

echo -e "\n\033[032mDone\033[0m"
echo -e "\n\033[036m────────────────────────────────────────────────────────────────────────────────\033[0m\n"

# Apache mods
echo -e "Checking \033[036mapache mods\033[0m"
if [[ ! -e /etc/apache2/mods-enabled/rewrite.load ]]; then
    a2enmod rewrite
fi
if [[ ! -e /etc/apache2/mods-enabled/headers.load ]]; then
    a2enmod headers
fi
echo -e "\033[032mDone\033[0m"
echo -e "\n\033[036m────────────────────────────────────────────────────────────────────────────────\033[0m\n"

# User configuration - Part 2/2
echo -e "Checking \033[036muser\033[0m configuration (Part 2/2)"
if [[ $V_USER_CREATED -eq 1 ]]; then
    usermod -a -G sudo $V_USER
    usermod -a -G www-data $V_USER
    if [[ ! -f /home/$V_USER/.bashrc ]]; then
        echo -e "Creating \033[036m/home/$V_USER/.bashrc\033[0m"
        touch /home/$V_USER/.bashrc
        V_BASHRC_CREATED=1
    fi
    if [[ -f /home/$V_USER/.bashrc ]]; then
        echo -e "Setting owner \033[036m${V_USER}:${V_GROUP}\033[0m to file \033[036m/home/${V_USER}/.bashrc\033[0m"
        chown $V_USER:$V_GROUP /home/$V_USER/.bashrc
    fi
    echo "${V_USER}:${V_SECRET}" > /tmp/passwd.txt; chpasswd < /tmp/passwd.txt; shred -n 5 /tmp/passwd.txt; rm /tmp/passwd.txt
fi
if [[ -d /home/$V_USER/.ssh ]]; then
    echo -e "Setting owner \033[036m${V_USER}:${V_GROUP}\033[0m to directory \033[036m/home/${V_USER}/.ssh\033[0m"
    chown $V_USER:$V_GROUP /home/$V_USER/.ssh
fi
echo -e "Showing id of user \033[036m$V_USER\033[0m"
id -u "$V_USER"
echo -e "Showing contents of \033[036m/home/$V_USER\033[0m"
ls -la /home/$V_USER
echo -e "\n\033[036m────────────────────────────────────────────────────────────────────────────────\033[0m\n"

# Composer
[[ "$DOCKER_INSTALL_COMPOSER" == "" ]] && export DOCKER_INSTALL_COMPOSER="yes"
echo -e "DOCKER_INSTALL_COMPOSER=\033[036m${DOCKER_INSTALL_COMPOSER}\033[036m"
if [[ "${DOCKER_INSTALL_COMPOSER,,}" =~ ^(y|yes|1|true)$ ]]; then
    echo -e "Installing \033[036mComposer\033[0m"
    echo -n -e "Checking if \033[036mcomposer\033[0m is installed..."
    if [[ -f /usr/local/bin/composer ]]; then
        echo -e "\033[032minstalled\033[0m"
    else
        echo -e "\033[036mnot installed\033[0m, installing now"
        # Prepare a composer installer directory
        mkdir /tmp/composer-installer && cd /tmp/composer-installer
        # https://getcomposer.org/download/
        V_COMPOSER_HASH=$( curl https://composer.github.io/installer.sig )
        php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
        php -r "if (hash_file('sha384', 'composer-setup.php') === '${V_COMPOSER_HASH}') { echo 'Composer installer verified'; } else { echo 'Composer installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
        if [[ -f composer-setup.php ]]; then
            echo -e "Running \033[036mcomposer-setup.php\033[0m"
            php composer-setup.php
            echo -e "Removing \033[036mcomposer-setup.php\033[0m"
            php -r "unlink('composer-setup.php');"
            chmod +x composer.phar
            if [[ ! -d /usr/local/bin ]]; then mkdir -p /usr/local/bin; fi
            mv -f composer.phar /usr/local/bin/composer
            # Cleanup
            echo -e "Cleaning up the composer installer"
            cd && rm -rf /tmp/composer-installer
        else
            echo -e "\033[031mError: installing composer failed, aborting\033[0m"; exit 1
        fi
        if [[ -f /usr/local/bin/composer ]]; then
            echo -e "\033[036mComposer\033[0m is now \033[032minstalled\033[0m!"
        else
            echo -e "\033[031mError: installing composer failed, aborting\033[0m"; exit 1
        fi
    fi
else
    echo -e "\033[033mSkipping \033[036mComposer\033[033m install\033[0m"
fi
echo -e "\n\033[036m────────────────────────────────────────────────────────────────────────────────\033[0m\n"

# NodeJS
[[ "$DOCKER_INSTALL_NODEJS" == "" ]] && export DOCKER_INSTALL_NODEJS="no"
echo -e "DOCKER_INSTALL_NODEJS=\033[036m${DOCKER_INSTALL_NODEJS}\033[036m"
if [[ "${DOCKER_INSTALL_NODEJS,,}" =~ ^(y|yes|1|true)$ ]]; then
    echo -e "Installing \033[036mNodeJS\033[0m"
    V_NODE_USER="${V_USER}"
    if [[ $( su $V_NODE_USER -p -c "which npm" | wc -l ) -eq 0 && ! -d $HOME/.nvm ]]; then
        echo -e "\033[033mNo \033[036mModeJS\033[033m installed for user \033[036m${V_NODE_USER}\033[033m, installing now\033[0m"
        su $V_NODE_USER -p -c "echo; \
            echo -e \"While I am installing \033[036mnode\033[0m I am user \033[036m\$( whoami )\033[0m (\033[032m\$UID\033[0m).\"; \
            if [[ \$( whoami ) == \"root\" ]]; then export HOME=\"/root\"; else export HOME=\"/home/\$( whoami )\"; fi; \
            echo -e \"I just made sure my home directory is \033[036m\$HOME\033[0m.\"; \
            if [[ -f ~/.bashrc && $( cat ~/.bashrc | grep 'export HOME=' | wc -l ) -eq 0 ]]; then echo \"export HOME=\\\"\$HOME\\\"\" >> ~/.bashrc; fi; \
            export NODE_VERSION=\"18.17.1\"; \
            if [[ -f ~/.bashrc && $( cat ~/.bashrc | grep 'export NODE_VERSION=' | wc -l ) -eq 0 ]]; then echo \"export NODE_VERSION=\\\"\$NODE_VERSION\\\"\" >> ~/.bashrc; fi; \
            export NVM_DIR=\"\$HOME/.nvm\"; \
            export NODE_PATH=\"\$NVM_DIR/v\$NODE_VERSION/lib/node_modules\"; \
            if [[ -f ~/.bashrc && $( cat ~/.bashrc | grep 'export NODE_PATH=' | wc -l ) -eq 0 ]]; then echo \"export NODE_PATH=\\\"\$NODE_PATH\\\"\" >> ~/.bashrc; fi; \
            export PATH=\"\$NVM_DIR/versions/node/v\$NODE_VERSION/bin:\$PATH\"; \
            if [[ -f ~/.bashrc && $( cat ~/.bashrc | grep 'export PATH=' | grep '/node'/ | wc -l ) -eq 0 ]]; then echo \"export PATH=\\\"\$PATH\\\"\" >> ~/.bashrc; fi; \
            echo \"Some exports I will use now are:\"; \
            echo -e \"NODE_VERSION: \033[036m\$NODE_VERSION\033[0m\"; \
            echo -e \"NVM_DIR: \033[036m\$NVM_DIR\033[0m\"; \
            echo -e \"NODE_PATH: \033[036m\$NODE_PATH\033[0m\"; \
            echo -e \"PATH: \033[036m\$PATH\033[0m\"; \
            if [[ ! -d \"\$NVM_DIR\" ]]; then mkdir -p \"\$NVM_DIR\"; fi; \
            echo; \
            echo -e \"Downloading the \033[036mnvm installer script\033[0m\"; \
            curl --silent -o- https://raw.githubusercontent.com/creationix/nvm/v0.39.3/install.sh | bash; \
            echo -e \"\033[036mnvm installer script\033[0m downloaded\"; \
            [[ -s \"\$NVM_DIR/nvm.sh\" ]] && \. \"\$NVM_DIR/nvm.sh\"; \
            [[ -s \"\$NVM_DIR/bash_completion\" ]] && \. \"\$NVM_DIR/bash_completion\"; \
            echo; \
            echo -e -n \"\033[036m\$NVM_DIR/nvm.sh\033[0m exists: \033[036m\" && ( ls -1a \"\$NVM_DIR/\" | grep \"nvm.sh\" | wc -l ) && echo -e -n \"\033[0m\"; \
            source \$NVM_DIR/nvm.sh; \
            echo; \
            nvm install \$NODE_VERSION; \
            nvm alias default \$NODE_VERSION; \
            nvm use default; \
            npm install -g npm@latest; \
            npm install -g svgo"
    else
        echo -e "\033[036mModeJS\033[0m already \033[032minstalled\033[0m for user \033[036m$( whoami )\033[0m"
    fi
else
    echo -e "\033[033mSkipping \033[036mModeJS\033[033m install\033[0m"
fi
echo -e "\n\033[036m────────────────────────────────────────────────────────────────────────────────\033[0m\n"

# NodeJS
[[ "$DOCKER_INSTALL_PYTHON3" == "" ]] && export DOCKER_INSTALL_PYTHON3="yes"
echo -e "DOCKER_INSTALL_PYTHON3=\033[036m${DOCKER_INSTALL_PYTHON3}\033[036m"
if [[ "${DOCKER_INSTALL_PYTHON3,,}" =~ ^(y|yes|1|true)$ ]]; then
    echo -e "Installing \033[036mPython3\033[0m"
    apt-get update && apt-get install -y python3
    python3 -V
else
    echo -e "\033[033mSkipping \033[036mPython3\033[033m install\033[0m"
fi
echo -e "\n\033[036m────────────────────────────────────────────────────────────────────────────────\033[0m\n"

# Laravel
[[ "$DOCKER_INSTALL_LARAVEL" == "" ]] && export DOCKER_INSTALL_LARAVEL="no"
echo -e "DOCKER_INSTALL_LARAVEL=\033[036m${DOCKER_INSTALL_LARAVEL}\033[036m"
if [[ "${DOCKER_INSTALL_LARAVEL,,}" =~ ^(y|yes|1|true)$ ]]; then
    echo -e "Installing \033[036mLaravel\033[0m"
    echo -n -e "Checking if the \033[036mlaravel\033[0m installer is installed..."
    if [[ -e /usr/local/bin/laravel ]]; then
        echo -e "\033[032minstalled\033[0m"
    else
        echo
        if [[ ! -f /root/.composer/vendor/laravel/installer/bin/laravel && ! -f /root/.config/composer/vendor/laravel/installer/bin/laravel ]]; then
            echo -e "\nRunning \033[036mComposer require\033[0m"
            composer global require laravel/installer
            echo -e "\033[036mComposer require\033[0m ended\n"
            if [[ ! -f /root/.composer/vendor/laravel/installer/bin/laravel && ! -f /root/.config/composer/vendor/laravel/installer/bin/laravel ]]; then
                echo -e "\033[031mError: installing the laravel installer failed, aborting (1)\033[0m" && exit 1
            fi
        fi
        if [[ -e /root/.composer/vendor/laravel/installer/bin/laravel && ! -e /usr/local/bin/laravel ]]; then
            echo -e "Symlinking \033[036m/root/.composer/vendor/laravel/installer/bin/laravel\033[0m to \033[036m/usr/local/bin/laravel\033[0m"
            ln -s /root/.composer/vendor/laravel/installer/bin/laravel /usr/local/bin/laravel
        elif [[ -e /root/.config/composer/vendor/laravel/installer/bin/laravel && ! -e /usr/local/bin/laravel ]]; then
            echo -e "Symlinking \033[036m/root/.config/composer/vendor/laravel/installer/bin/laravel\033[0m to \033[036m/usr/local/bin/laravel\033[0m"
            ln -s /root/.config/composer/vendor/laravel/installer/bin/laravel /usr/local/bin/laravel
        fi
        if [[ -e /usr/local/bin/laravel ]]; then
            echo -e "The \033[036mlaravel\033[0m installer is now \033[032minstalled\033[0m!"
        else
            echo -e "\033[031mError: installing the laravel installer failed, aborting (2)\033[0m" && exit 1
        fi
    fi
else
    echo -e "\033[033mSkipping \033[036mLaravel\033[033m install\033[0m"
fi
echo -e "\n\033[036m────────────────────────────────────────────────────────────────────────────────\033[0m\n"

# Last changes ... keep them last!
echo -e "Running some final commands before cleaning up the system\033[0m"
if [[ $V_BASHRC_CREATED -eq 1 ]]; then
    echo -e "\033[036mAdding connect redirect when starting bash\033[0m"
    echo "cd /var/www/html" >> /home/$V_USER/.bashrc
fi
echo -e "\033[032mDone\033[0m"
echo -e "\n\033[036m────────────────────────────────────────────────────────────────────────────────\033[0m\n"

# APT cleanup
echo -e "Running \033[036mAPT cleanup\033[0m"
apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false
rm -rf /var/lib/apt/lists/*
echo -e "\033[032mDone\033[0m"
echo -e "\n\033[036m────────────────────────────────────────────────────────────────────────────────\033[0m\n"

# Store the installation script version
echo -e "Updating \033[036minstallation version\033[0m"
if [[ ! -d /usr/share/docker ]]; then mkdir -p /usr/share/docker; fi
echo "$V_SCRIPT_VERSION" > /usr/share/docker/lap-installer.version
V_NEW_VERSION=$( cat /usr/share/docker/lap-installer.version )
echo -e "New stat version: \033[032m${V_NEW_VERSION}\033[0m"
echo -e "Required version: \033[032m${V_SCRIPT_VERSION}\033[0m"
if [[ ! "$V_NEW_VERSION" == "$V_SCRIPT_VERSION" ]]; then
    echo -e "\033[033mWarning: stored stat version mismatch, please debug if you would be so kind\033[0m"
fi
echo -e "\n\033[036m────────────────────────────────────────────────────────────────────────────────\033[0m\n"

exit 0
