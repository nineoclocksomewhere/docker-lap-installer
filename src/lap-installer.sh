#!/usr/bin/env bash

V_SCRIPT_VERSION="1.0.46"

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

# Custom before installer script?
which lap-installer-before
if [[ $? -eq 0 ]]; then
    bash lap-installer-before
    if [[ ! $? -eq 0 ]]; then
        echo -e "\033[031mError: before installer failed, aborting\033[0m"
        exit 1
    fi
    echo -e "\n\033[036m────────────────────────────────────────────────────────────────────────────────\033[0m\n"
fi

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
# https://askubuntu.com/a/1500085
if [[ -d /var/lib/dpkg/updates ]]; then
    rm /var/lib/dpkg/updates/*
fi
apt-get update
apt-get -y upgrade
apt-get install -y \
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
    nano \
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
    libmemcached-dev \
    pv
echo -e "\033[032mDone\033[0m"
echo -e "\n\033[036m────────────────────────────────────────────────────────────────────────────────\033[0m\n"

# Locales
echo -e "Installing and updating \033[036mlocales\033[0m"
# Install locales package
apt-get install -y locales
# Uncomment locales for inclusion in generation
if [[ -f /etc/locale.gen ]]; then
    sed -i 's/^# *\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen
    sed -i 's/^# *\(nl_BE.UTF-8 UTF-8\)/\1/' /etc/locale.gen
    sed -i 's/^# *\(nl_NL.UTF-8 UTF-8\)/\1/' /etc/locale.gen
    sed -i 's/^# *\(fr_BE.UTF-8 UTF-8\)/\1/' /etc/locale.gen
    sed -i 's/^# *\(fr_FR.UTF-8 UTF-8\)/\1/' /etc/locale.gen
    sed -i 's/^# *\(de_DE.UTF-8 UTF-8\)/\1/' /etc/locale.gen
fi
# Generate locales
locale-gen

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
    echo -e "Installing PHP extension \033[036mzip\033[0m"
    docker-php-ext-configure zip --with-libzip
    docker-php-ext-install -j$(nproc) zip
else
    echo -e "PHP extension \033[036mzip\033[0m already installed"
fi

if [[ $( php -m | grep 'memcached' | wc -l ) -eq 0 ]]; then
    echo -e "Installing PHP extension \033[036mmemcached\033[0m"
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
    echo -e "PHP extension \033[036mmemcached\033[0m already installed"
fi

if [[ "$DOCKER_INSTALL_PHP_BCMATH" == "" ]]; then
    export DOCKER_INSTALL_PHP_BCMATH="no"
fi
echo -e "DOCKER_INSTALL_PHP_BCMATH=\033[036m${DOCKER_INSTALL_PHP_BCMATH}\033[0m"
if [[ "${DOCKER_INSTALL_PHP_BCMATH,,}" =~ ^(y|yes|1|true)$ ]]; then
    if [[ $( php -m | grep 'bcmath' | wc -l ) -eq 0 ]]; then
        echo -e "Installing PHP extension \033[036mbcmath\033[0m"
        docker-php-ext-install -j$(nproc) bcmath
    else
        echo -e "PHP extension \033[036mbcmath\033[0m already installed"
    fi
fi

if [[ "$DOCKER_INSTALL_PHP_GD" == "" ]]; then
    export DOCKER_INSTALL_PHP_GD="yes"
fi
echo -e "DOCKER_INSTALL_PHP_GD=\033[036m${DOCKER_INSTALL_PHP_GD}\033[0m"
if [[ "${DOCKER_INSTALL_PHP_GD,,}" =~ ^(y|yes|1|true)$ ]]; then
    if [[ $( php -m | grep 'gd' | wc -l ) -eq 0 ]]; then
        echo -e "Installing PHP extension \033[036mgd\033[0m"
        if [[ $V_PHP_MAJOR_VERSION -eq 7 && $V_PHP_MINOR_VERSION -le 3 ]]; then
            docker-php-ext-configure gd --with-freetype-dir=/usr/lib --with-png-dir=/usr/lib --with-jpeg-dir=/usr/lib && docker-php-ext-install -j$(nproc) gd
        else
            docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp && docker-php-ext-install -j$(nproc) gd
        fi
    else
        echo -e "PHP extension \033[036mgd\033[0m already installed"
    fi
fi

if [[ "$DOCKER_INSTALL_PHP_PDO_MYSQL" == "" ]]; then
    export DOCKER_INSTALL_PHP_PDO_MYSQL="yes"
fi
echo -e "DOCKER_INSTALL_PHP_PDO_MYSQL=\033[036m${DOCKER_INSTALL_PHP_PDO_MYSQL}\033[0m"
if [[ "${DOCKER_INSTALL_PHP_PDO_MYSQL,,}" =~ ^(y|yes|1|true)$ ]]; then
    if [[ $( php -m | grep 'pdo_mysql' | wc -l ) -eq 0 ]]; then
        echo -e "Installing PHP extension \033[036mpdo_mysql\033[0m"
        docker-php-ext-install -j$(nproc) pdo_mysql
    else
        echo -e "PHP extension \033[036mpdo_mysql\033[0m already installed"
    fi
fi

if [[ "$DOCKER_INSTALL_PHP_MYSQLI" == "" ]]; then
    export DOCKER_INSTALL_PHP_MYSQLI="yes"
fi
echo -e "DOCKER_INSTALL_PHP_MYSQLI=\033[036m${DOCKER_INSTALL_PHP_MYSQLI}\033[0m"
if [[ "${DOCKER_INSTALL_PHP_MYSQLI,,}" =~ ^(y|yes|1|true)$ ]]; then
    if [[ $( php -m | grep 'mysqli' | wc -l ) -eq 0 ]]; then
        echo -e "Installing PHP extension \033[036mmysqli\033[0m"
        docker-php-ext-install -j$(nproc) mysqli
    else
        echo -e "PHP extension \033[036mmysqli\033[0m already installed"
    fi
fi

if [[ "$DOCKER_INSTALL_PHP_EXIF" == "" ]]; then
    export DOCKER_INSTALL_PHP_EXIF="yes"
fi
echo -e "DOCKER_INSTALL_PHP_EXIF=\033[036m${DOCKER_INSTALL_PHP_EXIF}\033[0m"
if [[ "${DOCKER_INSTALL_PHP_EXIF,,}" =~ ^(y|yes|1|true)$ ]]; then
    if [[ $( php -m | grep 'exif' | wc -l ) -eq 0 ]]; then
        echo -e "Installing PHP extension \033[036mexif\033[0m"
        docker-php-ext-install -j$(nproc) exif
    else
        echo -e "PHP extension \033[036mexif\033[0m already installed"
    fi
fi

if [[ "$DOCKER_INSTALL_PHP_INTL" == "" ]]; then
    export DOCKER_INSTALL_PHP_INTL="yes"
fi
echo -e "DOCKER_INSTALL_PHP_INTL=\033[036m${DOCKER_INSTALL_PHP_INTL}\033[0m"
if [[ "${DOCKER_INSTALL_PHP_INTL,,}" =~ ^(y|yes|1|true)$ ]]; then
    if [[ $( php -m | grep 'intl' | wc -l ) -eq 0 ]]; then
        echo -e "Installing PHP extension \033[036mintl\033[0m"
        docker-php-ext-install -j$(nproc) intl
    else
        echo -e "PHP extension \033[036mintl\033[0m already installed"
    fi
fi

if [[ "$DOCKER_INSTALL_PHP_SOCKETS" == "" ]]; then
    export DOCKER_INSTALL_PHP_SOCKETS="yes"
fi
echo -e "DOCKER_INSTALL_PHP_SOCKETS=\033[036m${DOCKER_INSTALL_PHP_SOCKETS}\033[0m"
if [[ "${DOCKER_INSTALL_PHP_SOCKETS,,}" =~ ^(y|yes|1|true)$ ]]; then
    if [[ $( php -m | grep 'sockets' | wc -l ) -eq 0 ]]; then
        echo -e "Installing PHP extension \033[036msockets\033[0m"
        docker-php-ext-install -j$(nproc) sockets
    else
        echo -e "PHP extension \033[036msockets\033[0m already installed"
    fi
fi

if [[ "$DOCKER_INSTALL_PHP_SOAP" == "" ]]; then
    export DOCKER_INSTALL_PHP_SOAP="no"
fi
echo -e "DOCKER_INSTALL_PHP_SOAP=\033[036m${DOCKER_INSTALL_PHP_SOAP}\033[0m"
if [[ "${DOCKER_INSTALL_PHP_SOAP,,}" =~ ^(y|yes|1|true)$ ]]; then
    if [[ $( php -m | grep 'soap' | wc -l ) -eq 0 ]]; then
        echo -e "Installing PHP extension \033[036msoap\033[0m"
        docker-php-ext-install -j$(nproc) soap
    else
        echo -e "PHP extension \033[036msoap\033[0m already installed"
    fi
fi

if [[ "$DOCKER_INSTALL_PHP_SODIUM" == "" ]]; then
    export DOCKER_INSTALL_PHP_SODIUM="no"
fi
echo -e "DOCKER_INSTALL_PHP_SODIUM=\033[036m${DOCKER_INSTALL_PHP_SODIUM}\033[0m"
if [[ "${DOCKER_INSTALL_PHP_SODIUM,,}" =~ ^(y|yes|1|true)$ ]]; then
    if [[ $( php -m | grep 'sodium' | wc -l ) -eq 0 ]]; then
        echo -e "Installing PHP extension \033[036msodium\033[0m"
        docker-php-ext-install -j$(nproc) sodium
    else
        echo -e "PHP extension \033[036msodium\033[0m already installed"
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
V_USER_PATH=$( su - docker -c ". ~/.bashrc; echo \$PATH" )
echo -e "\033[036m${V_USER}\033[0m's \$PATH is \033[036m/home/${V_USER_PATH}\033[0m"
echo -e "\n\033[036m────────────────────────────────────────────────────────────────────────────────\033[0m\n"

# Composer
[[ "$DOCKER_INSTALL_COMPOSER" == "" ]] && export DOCKER_INSTALL_COMPOSER="yes"
echo -e "DOCKER_INSTALL_COMPOSER=\033[036m${DOCKER_INSTALL_COMPOSER}\033[0m"
if [[ "${DOCKER_INSTALL_COMPOSER,,}" =~ ^(y|yes|1|true)$ ]]; then
    echo -e "Installing \033[036mComposer\033[0m"
    echo -e "Checking if \033[036mcomposer\033[0m is installed"
    if [[ -f /usr/local/bin/composer ]]; then
        echo -e "\033[032mInstalled\033[0m"
    else
        echo -e "\033[036mNot installed\033[0m, installing now"
        # Prepare a composer installer directory
        mkdir /tmp/composer-installer && cd /tmp/composer-installer
        # https://getcomposer.org/download/
        V_COMPOSER_HASH=$( curl https://composer.github.io/installer.sig )
        php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
        php -r "if (hash_file('sha384', 'composer-setup.php') === '${V_COMPOSER_HASH}') { echo \"\\033[032mComposer installer verified\\033[0m\".PHP_EOL; } else { echo \"\\033[031mComposer installer corrupt\\033[0m\".PHP_EOL; unlink('composer-setup.php'); if (file_exists('composer-setup.php')) { echo \"\\033[031mRemoving \".realpath('composer-setup.php').\" failed\\033[0m\".PHP_EOL; } }"
        if [[ -f "composer-setup.php" ]]; then
            echo -e "Composer installer saved as \033[036m$( realpath 'composer-setup.php' )\033[0m"
            echo -e "Running \033[036mcomposer-setup.php\033[0m"
            php composer-setup.php
            if [[ ! $? -eq 0 ]]; then
                echo -e "\033[031mError: installing composer failed, aborting\033[0m"
                exit 1
            fi
            echo -e "Removing \033[036mcomposer-setup.php\033[0m"
            php -r "unlink('composer-setup.php'); if (file_exists('composer-setup.php')) { echo \"\\033[031mRemoving \".realpath('composer-setup.php').\" failed\\033[0m\".PHP_EOL; }"
            if [[ -f composer.phar ]]; then
                chmod +x composer.phar
                if [[ ! -d /usr/local/bin ]]; then
                    mkdir -p /usr/local/bin
                fi
                echo -e "Moving \033[036m$( realpath composer.phar )\033[0m to \033[036m/usr/local/bin/composer\033[0m"
                mv -f composer.phar /usr/local/bin/composer
                echo -e "Cleaning up the composer installer"
                cd && rm -rf /tmp/composer-installer
            else
                echo -e "\033[031mError: composer.phar not found, aborting\033[0m"
                exit 1
            fi
        else
            echo -e "\033[031mError: installing composer failed, aborting\033[0m"
            exit 1
        fi
        if [[ -f /usr/local/bin/composer ]]; then
            echo -e "\033[036mComposer\033[0m is now \033[032minstalled\033[0m!"
        else
            echo -e "\033[031mError: installing composer failed, aborting\033[0m"
            exit 1
        fi
    fi
else
    echo -e "\033[033mSkipping \033[036mComposer\033[033m install\033[0m"
fi
echo -e "\n\033[036m────────────────────────────────────────────────────────────────────────────────\033[0m\n"

# NodeJS
[[ "$DOCKER_INSTALL_NODEJS" == "" ]] && export DOCKER_INSTALL_NODEJS="no"
echo -e "DOCKER_INSTALL_NODEJS=\033[036m${DOCKER_INSTALL_NODEJS}\033[0m"
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
        if [[ ! $? -eq 0 ]]; then
            echo -e "\033[031mError: installing node failed, aborting\033[0m"
            exit 1
        fi
    else
        echo -e "\033[036mModeJS\033[0m already \033[032minstalled\033[0m for user \033[036m$( whoami )\033[0m"
    fi
else
    echo -e "\033[033mSkipping \033[036mModeJS\033[033m install\033[0m"
fi
echo -e "\n\033[036m────────────────────────────────────────────────────────────────────────────────\033[0m\n"

# Python
[[ "$DOCKER_INSTALL_PYTHON3" == "" ]] && export DOCKER_INSTALL_PYTHON3="yes"
echo -e "DOCKER_INSTALL_PYTHON3=\033[036m${DOCKER_INSTALL_PYTHON3}\033[0m"
if [[ "${DOCKER_INSTALL_PYTHON3,,}" =~ ^(y|yes|1|true)$ ]]; then
    echo -e "Installing \033[036mPython3\033[0m"
    apt-get update && apt-get install -y python3
    python3 -V
else
    echo -e "\033[033mSkipping \033[036mPython3\033[033m install\033[0m"
fi
echo -e "\n\033[036m────────────────────────────────────────────────────────────────────────────────\033[0m\n"

# Slatedocs
[[ "$DOCKER_INSTALL_SLATE" == "" ]] && export DOCKER_INSTALL_SLATE="no"
echo -e "DOCKER_INSTALL_SLATE=\033[036m${DOCKER_INSTALL_SLATE}\033[0m"
if [[ "${DOCKER_INSTALL_SLATE,,}" =~ ^(y|yes|1|true)$ ]]; then
    echo -e "Installing \033[036mSlate\033[0m"
    apt-get update -y && apt-get install -y ruby ruby-dev build-essential libffi-dev zlib1g-dev liblzma-dev nodejs patch
    V_GEM_OK=0
    gem update --system
    if [[ $? -eq 0 ]]; then
        gem install bundler
        if [[ $? -eq 0 ]]; then
            V_GEM_OK=1
        fi
    fi
    if [[ $V_GEM_OK -eq 0 ]]; then
        echo -e "\033[033mInstall using gem failed, trying bundler\033[0m"
        apt-get install -y bundler
    fi
    mkdir /slate
    chmod 0775 /slate
    chown docker:docker /slate
    su -c "git clone git@github.com:slatedocs/slate.git /slate/" docker
    if [[ -d /slate/.git ]]; then
        rm -rf /slate/.git
    fi
    if [[ -d /slate/source ]]; then
        rm -rf /slate/source
    fi
    V_PWD=$( pwd )
    cd /slate
    su -c "bundle config set --local path 'vendor/bundle'" docker
    su -c "bundle install" docker
    su -c "npm install" docker
    echo '#!/usr/bin/env bash' > /usr/local/bin/slate
    echo 'CUSTOM_SOURCE="$1"' >> /usr/local/bin/slate
    echo 'CUSTOM_OUTPUT="$2"' >> /usr/local/bin/slate
    echo 'if [[ -d "$CUSTOM_SOURCE" ]]; then' >> /usr/local/bin/slate
    echo '    ln -sf "$CUSTOM_SOURCE" /slate/source' >> /usr/local/bin/slate
    echo 'fi' >> /usr/local/bin/slate
    echo 'cd /slate' >> /usr/local/bin/slate
    echo 'bundle exec middleman build --build-dir="$CUSTOM_OUTPUT"' >> /usr/local/bin/slate
    echo 'exit 0' >> /usr/local/bin/slate
    chmod +x /usr/local/bin/slate
    cd "$V_PWD"
else
    echo -e "\033[033mSkipping \033[036mSlate\033[033m install\033[0m"
fi
echo -e "\n\033[036m────────────────────────────────────────────────────────────────────────────────\033[0m\n"

# Laravel
[[ "$DOCKER_INSTALL_LARAVEL" == "" ]] && export DOCKER_INSTALL_LARAVEL="no"
echo -e "DOCKER_INSTALL_LARAVEL=\033[036m${DOCKER_INSTALL_LARAVEL}\033[0m"
if [[ "${DOCKER_INSTALL_LARAVEL,,}" =~ ^(y|yes|1|true)$ ]]; then
    echo -e "Checking if the \033[036mlaravel installer\033[0m is installed"
    V_LARAVEL_BIN="/usr/local/bin/laravel"
    if [[ -e "$V_LARAVEL_BIN" ]]; then
        echo -e "\033[032mInstalled\033[0m"
    else
        echo -e "Installing the \033[036mlaravel installer\033[0m for user \033[036${V_USER}\033[0m"
        V_LARAVEL_BIN_COMPOSER="/home/${V_USER}/.composer/vendor/laravel/installer/bin/laravel"
        V_LARAVEL_BIN_CONFIG="/home/${V_USER}/.config/composer/vendor/laravel/installer/bin/laravel"
        if [[ ! -f "$V_LARAVEL_BIN_COMPOSER" && ! -f "$V_LARAVEL_BIN_CONFIG" ]]; then
            echo -e "\nRunning \033[036mComposer require\033[0m for user \033[036m${V_USER}\033[0m"
            su - docker -c ". /home/${V_USER}/.bashrc; composer global require laravel/installer"
            echo -e "\033[036mComposer require\033[0m ended\n"
            if [[ ! -f "$V_LARAVEL_BIN_COMPOSER" && ! -f "$V_LARAVEL_BIN_CONFIG" ]]; then
                echo -e "\033[031mError: installing the laravel installer failed, ${V_LARAVEL_BIN_COMPOSER} and ${V_LARAVEL_BIN_CONFIG} not found\033[0m"
                exit 1
            fi
        fi
        if [[ -e "$V_LARAVEL_BIN_COMPOSER" && ! -e "$V_LARAVEL_BIN" ]]; then
            echo -e "Symlinking \033[036m${V_LARAVEL_BIN_COMPOSER}\033[0m to \033[036m${V_LARAVEL_BIN}\033[0m"
            ln -s "$V_LARAVEL_BIN_COMPOSER" "$V_LARAVEL_BIN"
        elif [[ -e "$V_LARAVEL_BIN_CONFIG" && ! -e "$V_LARAVEL_BIN" ]]; then
            echo -e "Symlinking \033[036m${V_LARAVEL_BIN_CONFIG}\033[0m to \033[036m${V_LARAVEL_BIN}\033[0m"
            ln -s "$V_LARAVEL_BIN_CONFIG" "$V_LARAVEL_BIN"
        else
            echo -e "\033[031mError: installing the laravel installer failed, ${V_LARAVEL_BIN_COMPOSER} and ${V_LARAVEL_BIN_CONFIG} not found\033[0m"
            exit 1
        fi
        if [[ -e "$V_LARAVEL_BIN" ]]; then
            echo -e "The \033[036mlaravel\033[0m installer is now \033[032minstalled\033[0m!"
        else
            echo -e "\033[031mError: installing the laravel installer failed, ${$V_LARAVEL_BIN} not found\033[0m"
            exit 1
        fi
    fi
else
    echo -e "\033[033mSkipping \033[036mLaravel\033[033m install\033[0m"
fi
echo -e "\n\033[036m────────────────────────────────────────────────────────────────────────────────\033[0m\n"

# Last changes ... keep them last!
echo -e "Running some final commands before cleaning up the system\033[0m"
if [[ $V_BASHRC_CREATED -eq 1 ]]; then
    
    echo -e "\033[036mAdding .bash_aliases to .bashrc file\033[0m"
    echo "" >> /home/$V_USER/.bashrc
    echo "if [ -f ~/.bash_aliases ]; then" >> /home/$V_USER/.bashrc
    echo "    . ~/.bash_aliases" >> /home/$V_USER/.bashrc
    echo "fi" >> /home/$V_USER/.bashrc

    echo -e "\033[036mAdding connect redirect when starting bash\033[0m"
    
    echo "" >> /home/$V_USER/.bashrc    
    echo "cd /var/www/html" >> /home/$V_USER/.bashrc
fi
echo -e "\033[032mDone\033[0m"
echo -e "\n\033[036m────────────────────────────────────────────────────────────────────────────────\033[0m\n"

# Custom after installer script?
which lap-installer-after
if [[ $? -eq 0 ]]; then
    bash lap-installer-after
    if [[ ! $? -eq 0 ]]; then
        echo -e "\033[031mError: after installer failed, aborting\033[0m"
        exit 1
    fi
    echo -e "\n\033[036m────────────────────────────────────────────────────────────────────────────────\033[0m\n"
fi

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
