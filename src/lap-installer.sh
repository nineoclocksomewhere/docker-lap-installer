#!/usr/bin/env bash

F_LOG() {
    local V_MSG="$*"
    local V_LOGFILE="/var/log/lap-installer.log"
    echo -e "$V_MSG"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${V_MSG}" >> "$V_LOGFILE"
}
F_LINE() {
    echo -e "\n\033[036m────────────────────────────────────────────────────────────────────────────────\033[0m\n"
}

# First, an introduction
F_LINE
echo -ne "Let me introduce myself:\nI am $( whoami ), "
echo -ne $(( $( date +%s ) - $( stat -c %W $HOME ) ))
echo -e " seconds old, live at ${HOME} but currently staying at $( pwd )."
F_LINE

# We need to be root
if [[ ! "$( whoami )" == "root" ]]; then
    echo -e "Error: this script needs to run as the root user, aborting"
    F_LINE
    exit 1
fi

# Check if the installation is up-to-date
V_SCRIPT_FILE=$( readlink -f "$0" )
V_SCRIPT_MD5SUM=$( md5sum $V_SCRIPT_FILE )
V_REQUIRED_SCRIPT_HASH=${V_SCRIPT_MD5SUM%% *}
if [[ -f /usr/share/docker/lap-installer.hash ]]; then
    V_INSTALLED_SCRIPT_HASH=$( cat /usr/share/docker/lap-installer.hash )
else
    V_INSTALLED_SCRIPT_HASH=""
fi
if [[ "$V_INSTALLED_SCRIPT_HASH" == "$V_REQUIRED_SCRIPT_HASH" ]]; then
    F_LOG "Installation is up-to-date \033[090m(script hash ${V_INSTALLED_SCRIPT_HASH})\033[0m"
    F_LINE
    exit 0
fi

# Say why we re-check it all
if [[ ! -f /usr/share/docker/lap-installer.hash ]]; then
    F_LOG "Installation never executed for this container \033[090m(required hash: ${V_REQUIRED_SCRIPT_HASH})\033[0m], installing now"
else
    rm /usr/share/docker/lap-installer.hash > /dev/null 2>&1
    F_LOG "Installation outdated \033[090m(required hash: ${V_REQUIRED_SCRIPT_HASH}, installed hash: ${V_INSTALLED_SCRIPT_HASH})\033[0m, updating now"
fi
F_LINE

# Check if we need to switch to Debian archive repositories
if [[ ! "${DOCKER_USE_DEBIAN_ARCHIVE,,}" =~ ^(y|yes|1|true)$ ]]; then
    V_DEB_CODENAME=$(lsb_release -sc)
    V_DEB_MAIN_URL="http://deb.debian.org/debian/dists/${V_DEB_CODENAME}/Release"
    V_DEB_ARCHIVE_URL="http://archive.debian.org/debian/dists/${V_DEB_CODENAME}/Release"
    if curl --silent --head --fail "$V_DEB_MAIN_URL" > /dev/null; then
        echo -e "\033[032m${V_DEB_CODENAME} is still on the main Debian mirrors\033[0m"
    else
        if curl --silent --head --fail "$V_DEB_ARCHIVE_URL" > /dev/null; then
            echo "\033[033mWarning: the Debian ${V_DEB_CODENAME} codebase has been archived\033[0m"
            DOCKER_USE_DEBIAN_ARCHIVE="true"
        else
            echo "\033[031mError: could not find ${V_DEB_CODENAME} in main or archive mirrors\033[0m"
            exit 1
        fi
    fi
fi
if [[ "${DOCKER_USE_DEBIAN_ARCHIVE,,}" =~ ^(y|yes|1|true)$ ]]; then
    ## echo we are using DEBIAN archive repositories
    echo -ne "\033[1;33mSwitching to Debian archive repositories...\033[0m\n"
    
    F_LOG "Switching to Debian archive repositories"

    sed -i 's|http://deb.debian.org/debian|http://archive.debian.org/debian|g' /etc/apt/sources.list
    sed -i 's|http://security.debian.org/debian-security|http://archive.debian.org/debian-security|g' /etc/apt/sources.list

    echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid-until

    F_LOG "Debian archive repositories set and valid-until check disabled"

    # Update the package list
    apt-get update

    F_LINE
fi

# Custom before installer script?
which lap-installer-before
if [[ $? -eq 0 ]]; then
    F_LOG "Running installer before script"
    bash lap-installer-before
    if [[ ! $? -eq 0 ]]; then
        F_LOG "Error: before installer failed, aborting"
        exit 1
    fi
    F_LINE
fi

# User configuration - Part 1/2
F_LOG "Checking user configuration (Part 1/2)"
V_GID="${PGID:-1000}"
V_GROUP="${DOCKER_GROUP_NAME:-docker}"
V_UID="${PUID:-1000}"
V_USER="${DOCKER_USER_NAME:-docker}"
V_SECRET="${DOCKER_USER_SECRET:-secret}"
if [[ $( getent group $V_GROUP | wc -l ) -eq 0 ]]; then
    F_LOG "Creating group ${V_GROUP} with GID ${V_GID}"
    groupadd -g $V_GID -o $V_GROUP
else
    F_LOG "Group ${V_GROUP} already exists"
fi
getent group $V_GROUP
V_BASHRC_CREATED=0
if id "$V_USER" &>/dev/null; then
    F_LOG "User ${V_USER} already exists"
    V_USER_CREATED=0
else
    F_LOG "Creating user ${V_USER} with UID ${V_UID}"
    useradd -u $V_UID -g $V_GROUP -s /bin/bash $V_USER
    # Why not using the -m parameter above?
    # -> The docker's home folder could already be created as mounted volume, so we check it later.
    if [[ ! -d /home/$V_USER ]]; then mkdir -p /home/$V_USER; fi
    chown $V_USER:$V_GROUP /home/$V_USER # Just to be sure, always
    usermod -d /home/$V_USER $V_USER
    V_USER_CREATED=1
fi
F_LINE

# Basic packages
F_LOG "Verifying if all basic packages are installed"
# https://askubuntu.com/a/1500085
if [[ -d /var/lib/dpkg/updates ]]; then
    if [[ "$(ls -A /var/lib/dpkg/updates)" ]]; then
        rm /var/lib/dpkg/updates/*
    else
        F_LOG "/var/lib/dpkg/updates is empty, nothing to remove"
    fi
fi

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
F_LOG "Done"
F_LINE

# Locales
F_LOG "Installing and updating locales"
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
F_LOG "Generating locales"
locale-gen

F_LINE

# WKHTMLTOPDF
[[ "$DOCKER_INSTALL_WKHTMLTOPDF" == "" ]] && export DOCKER_INSTALL_WKHTMLTOPDF="no"
F_LOG "DOCKER_INSTALL_WKHTMLTOPDF=${DOCKER_INSTALL_WKHTMLTOPDF}"
if [[ "${DOCKER_INSTALL_WKHTMLTOPDF,,}" =~ ^(y|yes|1|true)$ ]]; then
    F_LOG "Installing wkhtmltopdf"
    apt-get install -y \
        wkhtmltopdf
else
    F_LOG "Skipping wkhtmltopdf install"
fi
F_LINE

# Image Optimizers
[[ "$DOCKER_INSTALL_IMAGE_OPTIMIZERS" == "" ]] && export DOCKER_INSTALL_IMAGE_OPTIMIZERS="yes"
F_LOG "DOCKER_INSTALL_IMAGE_OPTIMIZERS=${DOCKER_INSTALL_IMAGE_OPTIMIZERS}"
if [[ "${DOCKER_INSTALL_IMAGE_OPTIMIZERS,,}" =~ ^(y|yes|1|true)$ ]]; then
    F_LOG "Installing Image Optimizers"
    apt-get install -y \
        jpegoptim \
        gifsicle \
        optipng \
        pngquant
else
    F_LOG "Skipping Image Optimizers install"
fi
F_LINE

# PHP extensions list: https:/127.0.0.1/github.com/mlocati/docker-php-extension-installer#supported-php-extensions
V_PHP_MAJOR_VERSION=$( php -r "echo explode('.', phpversion())[0];" )
V_PHP_MAJOR_VERSION=$(( $V_PHP_MAJOR_VERSION * 1 ))
F_LOG "PHP major version: ${V_PHP_MAJOR_VERSION}"
V_PHP_MINOR_VERSION=$( php -r "echo explode('.', phpversion())[1];" )
V_PHP_MINOR_VERSION=$(( $V_PHP_MINOR_VERSION * 1 ))
F_LOG "PHP minor version: ${V_PHP_MINOR_VERSION}"
echo

F_LOG "Checking PHP extensions"
if [[ $( php -m | grep 'zip' | wc -l ) -eq 0 ]]; then
    F_LOG "Installing PHP extension zip"
    docker-php-ext-configure zip --with-libzip
    docker-php-ext-install -j$(nproc) zip
else
    F_LOG "PHP extension zip already installed"
fi

if [[ $( php -m | grep 'memcached' | wc -l ) -eq 0 ]]; then
    F_LOG "Installing PHP extension memcached"
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
    F_LOG "PHP extension memcached already installed"
fi

if [[ "$DOCKER_INSTALL_PHP_BCMATH" == "" ]]; then
    export DOCKER_INSTALL_PHP_BCMATH="no"
fi
F_LOG "DOCKER_INSTALL_PHP_BCMATH=${DOCKER_INSTALL_PHP_BCMATH}"
if [[ "${DOCKER_INSTALL_PHP_BCMATH,,}" =~ ^(y|yes|1|true)$ ]]; then
    if [[ $( php -m | grep 'bcmath' | wc -l ) -eq 0 ]]; then
        F_LOG "Installing PHP extension bcmath"
        docker-php-ext-install -j$(nproc) bcmath
    else
        F_LOG "PHP extension bcmath already installed"
    fi
fi

if [[ "$DOCKER_INSTALL_PHP_GD" == "" ]]; then
    export DOCKER_INSTALL_PHP_GD="yes"
fi
F_LOG "DOCKER_INSTALL_PHP_GD=${DOCKER_INSTALL_PHP_GD}"
if [[ "${DOCKER_INSTALL_PHP_GD,,}" =~ ^(y|yes|1|true)$ ]]; then
    if [[ $( php -m | grep 'gd' | wc -l ) -eq 0 ]]; then
        F_LOG "Installing PHP extension gd"
        if [[ $V_PHP_MAJOR_VERSION -eq 7 && $V_PHP_MINOR_VERSION -le 3 ]]; then
            docker-php-ext-configure gd --with-freetype-dir=/usr/lib --with-png-dir=/usr/lib --with-jpeg-dir=/usr/lib && docker-php-ext-install -j$(nproc) gd
        else
            docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp && docker-php-ext-install -j$(nproc) gd
        fi
    else
        F_LOG "PHP extension gd already installed"
    fi
fi

if [[ "$DOCKER_INSTALL_PHP_IMAGICK" == "" ]]; then
    export DOCKER_INSTALL_PHP_IMAGICK="yes"
fi
F_LOG "DOCKER_INSTALL_PHP_IMAGICK=${DOCKER_INSTALL_PHP_IMAGICK}"
if [[ "${DOCKER_INSTALL_PHP_IMAGICK,,}" =~ ^(y|yes|1|true)$ ]]; then
    if [[ $( php -m | grep 'imagick' | wc -l ) -eq 0 ]]; then
        F_LOG "Installing PHP extension imagick"
        F_LOG "Updating packages"
        apt update
        F_LOG "Installing imagemagick packages"
        apt install imagemagick libmagickwand-dev gcc make -y
        (
            cd /var/tmp
            F_LOG "Cloning imagick source repository"
            git clone https://github.com/Imagick/imagick.git
            cd imagick
            git checkout $(git tag | grep ^3 | sort -V | tail -n 1)
            phpize
            F_LOG "Coniguring imagick"
            ./configure
            F_LOG "Making imagick"
            make
            F_LOG "Installing imagick"
            make install
            mkdir -p /usr/local/etc/php/conf.d > /dev/null 2>&1
            echo "extension=imagick.so" | tee /usr/local/etc/php/conf.d/20-imagick.ini


        )
    else
        F_LOG "PHP extension imagick already installed"
    fi
fi

if [[ "$DOCKER_INSTALL_PHP_PDO_MYSQL" == "" ]]; then
    export DOCKER_INSTALL_PHP_PDO_MYSQL="yes"
fi
F_LOG "DOCKER_INSTALL_PHP_PDO_MYSQL=${DOCKER_INSTALL_PHP_PDO_MYSQL}"
if [[ "${DOCKER_INSTALL_PHP_PDO_MYSQL,,}" =~ ^(y|yes|1|true)$ ]]; then
    if [[ $( php -m | grep 'pdo_mysql' | wc -l ) -eq 0 ]]; then
        F_LOG "Installing PHP extension pdo_mysql"
        docker-php-ext-install -j$(nproc) pdo_mysql
    else
        F_LOG "PHP extension pdo_mysql already installed"
    fi
fi

if [[ "$DOCKER_INSTALL_PHP_MYSQLI" == "" ]]; then
    export DOCKER_INSTALL_PHP_MYSQLI="yes"
fi
F_LOG "DOCKER_INSTALL_PHP_MYSQLI=${DOCKER_INSTALL_PHP_MYSQLI}"
if [[ "${DOCKER_INSTALL_PHP_MYSQLI,,}" =~ ^(y|yes|1|true)$ ]]; then
    if [[ $( php -m | grep 'mysqli' | wc -l ) -eq 0 ]]; then
        F_LOG "Installing PHP extension mysqli"
        docker-php-ext-install -j$(nproc) mysqli
    else
        F_LOG "PHP extension mysqli already installed"
    fi
fi

if [[ "$DOCKER_INSTALL_PHP_EXIF" == "" ]]; then
    export DOCKER_INSTALL_PHP_EXIF="yes"
fi
F_LOG "DOCKER_INSTALL_PHP_EXIF=${DOCKER_INSTALL_PHP_EXIF}"
if [[ "${DOCKER_INSTALL_PHP_EXIF,,}" =~ ^(y|yes|1|true)$ ]]; then
    if [[ $( php -m | grep 'exif' | wc -l ) -eq 0 ]]; then
        F_LOG "Installing PHP extension exif"
        docker-php-ext-install -j$(nproc) exif
    else
        F_LOG "PHP extension exif already installed"
    fi
fi

if [[ "$DOCKER_INSTALL_PHP_INTL" == "" ]]; then
    export DOCKER_INSTALL_PHP_INTL="yes"
fi
F_LOG "DOCKER_INSTALL_PHP_INTL=${DOCKER_INSTALL_PHP_INTL}"
if [[ "${DOCKER_INSTALL_PHP_INTL,,}" =~ ^(y|yes|1|true)$ ]]; then
    if [[ $( php -m | grep 'intl' | wc -l ) -eq 0 ]]; then
        F_LOG "Installing PHP extension intl"
        docker-php-ext-install -j$(nproc) intl
    else
        F_LOG "PHP extension intl already installed"
    fi
fi

if [[ "$DOCKER_INSTALL_PHP_SOCKETS" == "" ]]; then
    export DOCKER_INSTALL_PHP_SOCKETS="yes"
fi
F_LOG "DOCKER_INSTALL_PHP_SOCKETS=${DOCKER_INSTALL_PHP_SOCKETS}"
if [[ "${DOCKER_INSTALL_PHP_SOCKETS,,}" =~ ^(y|yes|1|true)$ ]]; then
    if [[ $( php -m | grep 'sockets' | wc -l ) -eq 0 ]]; then
        F_LOG "Installing PHP extension sockets"
        docker-php-ext-install -j$(nproc) sockets
    else
        F_LOG "PHP extension sockets already installed"
    fi
fi

if [[ "$DOCKER_INSTALL_PHP_SOAP" == "" ]]; then
    export DOCKER_INSTALL_PHP_SOAP="no"
fi
F_LOG "DOCKER_INSTALL_PHP_SOAP=${DOCKER_INSTALL_PHP_SOAP}"
if [[ "${DOCKER_INSTALL_PHP_SOAP,,}" =~ ^(y|yes|1|true)$ ]]; then
    if [[ $( php -m | grep 'soap' | wc -l ) -eq 0 ]]; then
        F_LOG "Installing PHP extension soap"
        docker-php-ext-install -j$(nproc) soap
    else
        F_LOG "PHP extension soap already installed"
    fi
fi

if [[ "$DOCKER_INSTALL_PHP_SODIUM" == "" ]]; then
    export DOCKER_INSTALL_PHP_SODIUM="no"
fi
F_LOG "DOCKER_INSTALL_PHP_SODIUM=${DOCKER_INSTALL_PHP_SODIUM}"
if [[ "${DOCKER_INSTALL_PHP_SODIUM,,}" =~ ^(y|yes|1|true)$ ]]; then
    if [[ $( php -m | grep 'sodium' | wc -l ) -eq 0 ]]; then
        F_LOG "Installing PHP extension sodium"
        docker-php-ext-install -j$(nproc) sodium
    else
        F_LOG "PHP extension sodium already installed"
    fi
fi

F_LOG "\nDone"
F_LINE

# Apache mods
F_LOG "Checking apache mods"
if [[ ! -e /etc/apache2/mods-enabled/rewrite.load ]]; then
    a2enmod rewrite
fi
if [[ ! -e /etc/apache2/mods-enabled/headers.load ]]; then
    a2enmod headers
fi
F_LOG "Done"
F_LINE

# User configuration - Part 2/2
F_LOG "Checking user configuration (Part 2/2)"
if [[ $V_USER_CREATED -eq 1 ]]; then
    usermod -a -G sudo $V_USER
    usermod -a -G www-data $V_USER
    if [[ ! -f /home/$V_USER/.bashrc ]]; then
        F_LOG "Creating /home/$V_USER/.bashrc"
        touch /home/$V_USER/.bashrc
        V_BASHRC_CREATED=1
    fi
    if [[ -f /home/$V_USER/.bashrc ]]; then
        F_LOG "Setting owner ${V_USER}:${V_GROUP} to file /home/${V_USER}/.bashrc"
        chown $V_USER:$V_GROUP /home/$V_USER/.bashrc
    fi
    echo "${V_USER}:${V_SECRET}" > /tmp/passwd.txt; chpasswd < /tmp/passwd.txt; shred -n 5 /tmp/passwd.txt; rm /tmp/passwd.txt
fi
if [[ -d /home/$V_USER/.ssh ]]; then
    F_LOG "Setting owner ${V_USER}:${V_GROUP} to directory /home/${V_USER}/.ssh"
    chown $V_USER:$V_GROUP /home/$V_USER/.ssh
fi
F_LOG "Showing id of user $V_USER"
id -u "$V_USER"
F_LOG "Showing contents of /home/$V_USER"
ls -la /home/$V_USER
V_USER_PATH=$( su - docker -c ". ~/.bashrc; echo \$PATH" )
F_LOG "${V_USER}'s \$PATH is /home/${V_USER_PATH}"
F_LINE

# Composer
[[ "$DOCKER_INSTALL_COMPOSER" == "" ]] && export DOCKER_INSTALL_COMPOSER="yes"
F_LOG "DOCKER_INSTALL_COMPOSER=${DOCKER_INSTALL_COMPOSER}"
if [[ "${DOCKER_INSTALL_COMPOSER,,}" =~ ^(y|yes|1|true)$ ]]; then
    F_LOG "Installing Composer"
    F_LOG "Checking if Composer is installed"
    if [[ -f /usr/local/bin/composer ]]; then
        F_LOG "Installed"
    else
        F_LOG "Not installed, installing now"

        # Prepare a composer installer directory
        mkdir -p /tmp/composer-installer && cd /tmp/composer-installer

        # https://getcomposer.org/download/
        V_COMPOSER_HASH=$( curl -s https://composer.github.io/installer.sig )
        php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
        php -r "if (hash_file('sha384', 'composer-setup.php') === '${V_COMPOSER_HASH}') { echo \"Composer installer verified\".PHP_EOL; } else { echo \"Composer installer corrupt\".PHP_EOL; unlink('composer-setup.php'); if (file_exists('composer-setup.php')) { echo \"Removing \".realpath('composer-setup.php').\" failed\".PHP_EOL; } }"

        if [[ -f "composer-setup.php" ]]; then
            F_LOG "Composer installer saved as $( realpath 'composer-setup.php' )"
            F_LOG "Running composer-setup.php"

            F_LOG "For available Composer versions, check: https://github.com/composer/composer/releases"
            if [[ "$DOCKER_COMPOSER_VERSION" != "" ]]; then
                F_LOG "Installing Composer version $DOCKER_COMPOSER_VERSION"
                php composer-setup.php --version="$DOCKER_COMPOSER_VERSION"
            else
                F_LOG "Installing latest Composer version"
                php composer-setup.php
            fi

            if [[ ! $? -eq 0 ]]; then
                F_LOG "Error: installing Composer failed, aborting"
                exit 1
            fi

            F_LOG "Removing composer-setup.php"
            php -r "unlink('composer-setup.php'); if (file_exists('composer-setup.php')) { echo \"Removing \".realpath('composer-setup.php').\" failed\".PHP_EOL; }"

            if [[ -f composer.phar ]]; then
                chmod +x composer.phar
                if [[ ! -d /usr/local/bin ]]; then
                    mkdir -p /usr/local/bin
                fi
                F_LOG "Moving $( realpath composer.phar ) to /usr/local/bin/composer"
                mv -f composer.phar /usr/local/bin/composer
                F_LOG "Cleaning up the composer installer"
                cd && rm -rf /tmp/composer-installer
            else
                F_LOG "Error: composer.phar not found, aborting"
                exit 1
            fi
        else
            F_LOG "Error: installing Composer failed, aborting"
            exit 1
        fi

        if [[ -f /usr/local/bin/composer ]]; then
            F_LOG "Composer is now installed!"
            /usr/local/bin/composer --version
        else
            F_LOG "Error: installing Composer failed, aborting"
            exit 1
        fi
    fi
else
    F_LOG "Skipping Composer install"
fi
F_LINE

# NodeJS
[[ "$DOCKER_INSTALL_NODEJS" == "" ]] && export DOCKER_INSTALL_NODEJS="no"
F_LOG "DOCKER_INSTALL_NODEJS=${DOCKER_INSTALL_NODEJS}"
if [[ "${DOCKER_INSTALL_NODEJS,,}" =~ ^(y|yes|1|true)$ ]]; then
    F_LOG "Installing NodeJS"
    V_NODE_USER="${V_USER}"
    if [[ $( su $V_NODE_USER -p -c "which npm" | wc -l ) -eq 0 && ! -d $HOME/.nvm ]]; then
        F_LOG "No ModeJS installed for user ${V_NODE_USER}, installing now"
        su $V_NODE_USER -p -c "echo; \
            echo -e \"While I am installing node I am user \$( whoami ) (\$UID).\"; \
            if [[ \$( whoami ) == \"root\" ]]; then export HOME=\"/root\"; else export HOME=\"/home/\$( whoami )\"; fi; \
            echo -e \"I just made sure my home directory is \$HOME.\"; \
            if [[ -f ~/.bashrc && $( cat ~/.bashrc | grep 'export HOME=' | wc -l ) -eq 0 ]]; then echo \"export HOME=\\\"\$HOME\\\"\" >> ~/.bashrc; fi; \
            export NODE_VERSION=\"18.17.1\"; \
            if [[ -f ~/.bashrc && $( cat ~/.bashrc | grep 'export NODE_VERSION=' | wc -l ) -eq 0 ]]; then echo \"export NODE_VERSION=\\\"\$NODE_VERSION\\\"\" >> ~/.bashrc; fi; \
            export NVM_DIR=\"\$HOME/.nvm\"; \
            export NODE_PATH=\"\$NVM_DIR/v\$NODE_VERSION/lib/node_modules\"; \
            if [[ -f ~/.bashrc && $( cat ~/.bashrc | grep 'export NODE_PATH=' | wc -l ) -eq 0 ]]; then echo \"export NODE_PATH=\\\"\$NODE_PATH\\\"\" >> ~/.bashrc; fi; \
            export PATH=\"\$NVM_DIR/versions/node/v\$NODE_VERSION/bin:\$PATH\"; \
            if [[ -f ~/.bashrc && $( cat ~/.bashrc | grep 'export PATH=' | grep '/node'/ | wc -l ) -eq 0 ]]; then echo \"export PATH=\\\"\$PATH\\\"\" >> ~/.bashrc; fi; \
            echo \"Some exports I will use now are:\"; \
            echo -e \"NODE_VERSION: \$NODE_VERSION\"; \
            echo -e \"NVM_DIR: \$NVM_DIR\"; \
            echo -e \"NODE_PATH: \$NODE_PATH\"; \
            echo -e \"PATH: \$PATH\"; \
            if [[ ! -d \"\$NVM_DIR\" ]]; then mkdir -p \"\$NVM_DIR\"; fi; \
            echo; \
            echo -e \"Downloading the nvm installer script\"; \
            curl --silent -o- https://raw.githubusercontent.com/creationix/nvm/v0.39.3/install.sh | bash; \
            echo -e \"nvm installer script downloaded\"; \
            [[ -s \"\$NVM_DIR/nvm.sh\" ]] && \. \"\$NVM_DIR/nvm.sh\"; \
            [[ -s \"\$NVM_DIR/bash_completion\" ]] && \. \"\$NVM_DIR/bash_completion\"; \
            echo; \
            echo -e -n \"\$NVM_DIR/nvm.sh exists: \" && ( ls -1a \"\$NVM_DIR/\" | grep \"nvm.sh\" | wc -l ) && echo -e -n \"\"; \
            source \$NVM_DIR/nvm.sh; \
            echo; \
            nvm install \$NODE_VERSION; \
            nvm alias default \$NODE_VERSION; \
            nvm use default; \
            npm install -g npm@latest; \
            npm install -g svgo"
        if [[ ! $? -eq 0 ]]; then
            F_LOG "Error: installing node failed, aborting"
            exit 1
        fi
    else
        F_LOG "ModeJS already installed for user $( whoami )"
    fi
else
    F_LOG "Skipping ModeJS install"
fi
F_LINE

# Python
[[ "$DOCKER_INSTALL_PYTHON3" == "" ]] && export DOCKER_INSTALL_PYTHON3="yes"
F_LOG "DOCKER_INSTALL_PYTHON3=${DOCKER_INSTALL_PYTHON3}"
if [[ "${DOCKER_INSTALL_PYTHON3,,}" =~ ^(y|yes|1|true)$ ]]; then
    F_LOG "Installing Python3"
    apt-get update && apt-get install -y python3
    python3 -V
else
    F_LOG "Skipping Python3 install"
fi
F_LINE

# Slatedocs
[[ "$DOCKER_INSTALL_SLATE" == "" ]] && export DOCKER_INSTALL_SLATE="no"
F_LOG "DOCKER_INSTALL_SLATE=${DOCKER_INSTALL_SLATE}"
if [[ "${DOCKER_INSTALL_SLATE,,}" =~ ^(y|yes|1|true)$ ]]; then
    F_LOG "Installing Slate"
    apt-get update -y && apt-get install -y ruby ruby-dev build-essential libffi-dev zlib1g-dev liblzma-dev nodejs patch bundler
    if [[ -d /slate ]]; then
        echo "Removing old /slate directory"
        rm -rf /slate
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
    echo '#!/usr/bin/env bash' > /usr/local/bin/slate
    echo 'CUSTOM_SOURCE="$1"' >> /usr/local/bin/slate
    echo 'if [[ ! -d "$CUSTOM_SOURCE" ]]; then' >> /usr/local/bin/slate
    echo '    echo -e "Error: invalid source directory provided"' >> /usr/local/bin/slate
    echo '    exit 1' >> /usr/local/bin/slate
    echo 'fi' >> /usr/local/bin/slate
    echo 'CUSTOM_OUTPUT="$2"' >> /usr/local/bin/slate
    echo 'if [[ "$CUSTOM_OUTPUT" == "" ]]; then' >> /usr/local/bin/slate
    echo '    echo -e "Error: invalid output directory provided"' >> /usr/local/bin/slate
    echo '    exit 1' >> /usr/local/bin/slate
    echo 'fi' >> /usr/local/bin/slate
    echo 'if [[ -e /slate/source ]]; then' >> /usr/local/bin/slate
    echo '    if [[ -d /slate/source ]]; then' >> /usr/local/bin/slate
    echo '        rm -rf /slate/source' >> /usr/local/bin/slate
    echo '    else' >> /usr/local/bin/slate
    echo '        rm /slate/source' >> /usr/local/bin/slate
    echo '    fi' >> /usr/local/bin/slate
    echo 'fi' >> /usr/local/bin/slate
    echo 'ln -sf "$CUSTOM_SOURCE" /slate/source' >> /usr/local/bin/slate
    echo 'PWD=$( pwd )' >> /usr/local/bin/slate
    echo 'cd /slate' >> /usr/local/bin/slate
    echo 'bundle exec middleman build --build-dir="$CUSTOM_OUTPUT"' >> /usr/local/bin/slate
    echo 'rm /slate/source' >> /usr/local/bin/slate
    echo 'cd "$PWD"' >> /usr/local/bin/slate
    echo 'exit 0' >> /usr/local/bin/slate
    chmod +x /usr/local/bin/slate
    cd "$V_PWD"
else
    F_LOG "Skipping Slate install"
fi
F_LINE

# Laravel
[[ "$DOCKER_INSTALL_LARAVEL" == "" ]] && export DOCKER_INSTALL_LARAVEL="no"
F_LOG "DOCKER_INSTALL_LARAVEL=${DOCKER_INSTALL_LARAVEL}"
if [[ "${DOCKER_INSTALL_LARAVEL,,}" =~ ^(y|yes|1|true)$ ]]; then
    F_LOG "Checking if the laravel installer is installed"
    V_LARAVEL_BIN="/usr/local/bin/laravel"
    if [[ -e "$V_LARAVEL_BIN" ]]; then
        F_LOG "Installed"
    else
        F_LOG "Installing the laravel installer for user \033[036${V_USER}"
        V_LARAVEL_BIN_COMPOSER="/home/${V_USER}/.composer/vendor/laravel/installer/bin/laravel"
        V_LARAVEL_BIN_CONFIG="/home/${V_USER}/.config/composer/vendor/laravel/installer/bin/laravel"
        if [[ ! -f "$V_LARAVEL_BIN_COMPOSER" && ! -f "$V_LARAVEL_BIN_CONFIG" ]]; then
            F_LOG "\nRunning Composer require for user ${V_USER}"
            su - docker -c ". /home/${V_USER}/.bashrc; composer global require laravel/installer"
            F_LOG "Composer require ended\n"
            if [[ ! -f "$V_LARAVEL_BIN_COMPOSER" && ! -f "$V_LARAVEL_BIN_CONFIG" ]]; then
                F_LOG "Error: installing the laravel installer failed, ${V_LARAVEL_BIN_COMPOSER} and ${V_LARAVEL_BIN_CONFIG} not found"
                exit 1
            fi
        fi
        if [[ -e "$V_LARAVEL_BIN_COMPOSER" && ! -e "$V_LARAVEL_BIN" ]]; then
            F_LOG "Symlinking ${V_LARAVEL_BIN_COMPOSER} to ${V_LARAVEL_BIN}"
            ln -s "$V_LARAVEL_BIN_COMPOSER" "$V_LARAVEL_BIN"
        elif [[ -e "$V_LARAVEL_BIN_CONFIG" && ! -e "$V_LARAVEL_BIN" ]]; then
            F_LOG "Symlinking ${V_LARAVEL_BIN_CONFIG} to ${V_LARAVEL_BIN}"
            ln -s "$V_LARAVEL_BIN_CONFIG" "$V_LARAVEL_BIN"
        else
            F_LOG "Error: installing the laravel installer failed, ${V_LARAVEL_BIN_COMPOSER} and ${V_LARAVEL_BIN_CONFIG} not found"
            exit 1
        fi
        if [[ -e "$V_LARAVEL_BIN" ]]; then
            F_LOG "The laravel installer is now installed!"
        else
            F_LOG "Error: installing the laravel installer failed, ${$V_LARAVEL_BIN} not found"
            exit 1
        fi
    fi
else
    F_LOG "Skipping Laravel install"
fi
F_LINE

# Last changes ... keep them last!
F_LOG "Running some final commands before cleaning up the system"
if [[ $V_BASHRC_CREATED -eq 1 ]]; then
    
    F_LOG "Adding .bash_aliases to .bashrc file"
    echo "" >> /home/$V_USER/.bashrc
    echo "if [ -f ~/.bash_aliases ]; then" >> /home/$V_USER/.bashrc
    echo "    . ~/.bash_aliases" >> /home/$V_USER/.bashrc
    echo "fi" >> /home/$V_USER/.bashrc

    F_LOG "Adding connect redirect when starting bash"
    
    echo "" >> /home/$V_USER/.bashrc    
    echo "cd /var/www/html" >> /home/$V_USER/.bashrc
fi
F_LOG "Done"
F_LINE

# Custom after installer script?
which lap-installer-after
if [[ $? -eq 0 ]]; then
    bash lap-installer-after
    if [[ ! $? -eq 0 ]]; then
        F_LOG "Error: after installer failed, aborting"
        exit 1
    fi
    F_LINE
fi

# APT cleanup
F_LOG "Running APT cleanup"
apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false
rm -rf /var/lib/apt/lists/*
F_LOG "Done"
F_LINE

# Store the installation script version
F_LOG "Updating installation version"
if [[ ! -d /usr/share/docker ]]; then mkdir -p /usr/share/docker; fi
echo "$V_REQUIRED_SCRIPT_HASH" > /usr/share/docker/lap-installer.hash
V_NEW_SCRIPT_HASH=$( cat /usr/share/docker/lap-installer.hash )
F_LOG "New script hash: ${V_NEW_SCRIPT_HASH}"
F_LOG "Required script hash: ${V_REQUIRED_SCRIPT_HASH}"
if [[ ! "$V_NEW_SCRIPT_HASH" == "$V_REQUIRED_SCRIPT_HASH" ]]; then
    F_LOG "Warning: stored script hash mismatch (please debug if you would be so kind)"
fi
F_LINE

exit 0