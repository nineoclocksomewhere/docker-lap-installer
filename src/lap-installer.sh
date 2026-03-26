#!/usr/bin/env bash

F_LOG() {
    local V_MSG="$*"
    local V_LOGFILE="/tmp/lap-installer/boot.log"
    echo -e "$V_MSG"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${V_MSG}" >> "$V_LOGFILE"
}
F_LINE() {
    echo -e "\n\033[036m────────────────────────────────────────────────────────────────────────────────\033[0m\n"
}
F_GET_CODENAME() {
    local CODENAME=""
    # 1. Try lsb_release if available
    if command -v lsb_release >/dev/null 2>&1; then
        CODENAME=$(lsb_release -sc 2>/dev/null)
        if [ -n "$CODENAME" ]; then
            echo "$CODENAME"
            return 0
        fi
    fi
    # 2. Try /etc/os-release
    if [ -r /etc/os-release ]; then
        CODENAME=$(grep -E '^VERSION_CODENAME=' /etc/os-release | cut -d= -f2)
        if [ -n "$CODENAME" ]; then
            echo "$CODENAME"
            return 0
        fi
    fi
    # 3. Try /etc/debian_version
    if [ -r /etc/debian_version ]; then
        local VERSION
        VERSION=$(cut -d. -f1 /etc/debian_version)
        case "$VERSION" in
            12) CODENAME="bookworm" ;;
            11) CODENAME="bullseye" ;;
            10) CODENAME="buster" ;;
            9)  CODENAME="stretch" ;;
            8)  CODENAME="jessie" ;;
            7)  CODENAME="wheezy" ;;
        esac
        if [[ -n "$CODENAME" ]]; then
            echo "$CODENAME"
            return 0
        fi
    fi
    # 4. If everything failed → exit with error
    echo -e "\033[031mError: could not determine Debian codename\033[0m" >&2
    exit 1
}

if [[ ! -d /tmp/lap-installer ]]; then
    mkdir -p /tmp/lap-installer
    chmod 0775 /tmp/lap-installer
fi

# ────────────────────────────────────────────────────────────────────────────────
F_LINE
# ────────────────────────────────────────────────────────────────────────────────

# First, an introduction
echo -ne "Let me introduce myself:\nI am $( whoami ), "
echo -ne $(( $( date +%s ) - $( stat -c %W $HOME ) ))
echo -e " seconds old, live at ${HOME} but currently staying at $( pwd )."

# ────────────────────────────────────────────────────────────────────────────────
F_LINE
# ────────────────────────────────────────────────────────────────────────────────

# We need to be root
if [[ ! "$( whoami )" == "root" ]]; then
    echo -e "Error: this script needs to run as the root user, aborting"
    exit 1
fi

# Check if the installation is up-to-date
V_SCRIPT_FILE=$( readlink -f "$0" )
V_SCRIPT_MD5SUM=$( md5sum $V_SCRIPT_FILE )
V_REQUIRED_SCRIPT_HASH=${V_SCRIPT_MD5SUM%% *}
F_LOG "Using required script hash \033[036m${V_REQUIRED_SCRIPT_HASH}\033[0m"
if [[ -f /usr/share/docker/lap-installer.hash ]]; then
    V_INSTALLED_SCRIPT_HASH=$( cat /usr/share/docker/lap-installer.hash )
    F_LOG "Using installed script hash \033[036m${V_INSTALLED_SCRIPT_HASH}\033[0m"
else
    V_INSTALLED_SCRIPT_HASH=""
    F_LOG "No installed script hash found"
fi

V_INSTALLATION_UP_TO_DATE=0
if [[ "$V_INSTALLED_SCRIPT_HASH" == "$V_REQUIRED_SCRIPT_HASH" ]]; then
    F_LOG "Installation is up-to-date"
    V_INSTALLATION_UP_TO_DATE=1
fi

if [[ ! "$V_INSTALLATION_UP_TO_DATE" -eq 1 ]]; then

    # ────────────────────────────────────────────────────────────────────────────────
    F_LINE
    # ────────────────────────────────────────────────────────────────────────────────

    # Say why we re-check it all
    if [[ ! -f /usr/share/docker/lap-installer.hash ]]; then
        F_LOG "Installation never executed for this container \033[090m(required hash: ${V_REQUIRED_SCRIPT_HASH})\033[0m, installing now"
    else
        rm /usr/share/docker/lap-installer.hash > /dev/null 2>&1
        F_LOG "Installation outdated \033[090m(required hash: ${V_REQUIRED_SCRIPT_HASH}, installed hash: ${V_INSTALLED_SCRIPT_HASH})\033[0m, updating now"
    fi

    # ────────────────────────────────────────────────────────────────────────────────
    F_LINE
    # ────────────────────────────────────────────────────────────────────────────────

    # Check if we need to switch to Debian archive repositories
    if [[ ! "${DOCKER_USE_DEBIAN_ARCHIVE,,}" =~ ^(y|yes|1|true)$ ]]; then
        V_DEB_CODENAME=$( F_GET_CODENAME )
        V_DEB_MAIN_URL="http://deb.debian.org/debian/dists/${V_DEB_CODENAME}/Release"
        V_DEB_ARCHIVE_URL="http://archive.debian.org/debian/dists/${V_DEB_CODENAME}/Release"
        if curl --silent --head --fail "$V_DEB_MAIN_URL" > /dev/null; then
            echo -e "\033[032m${V_DEB_CODENAME} is still on the main Debian mirrors\033[0m"
        else
            if curl --silent --head --fail "$V_DEB_ARCHIVE_URL" > /dev/null; then
                echo -e "\033[033mWarning: the Debian ${V_DEB_CODENAME} codebase has been archived\033[0m"
                DOCKER_USE_DEBIAN_ARCHIVE="true"
            else
                echo -e "\033[031mError: could not find ${V_DEB_CODENAME} in main or archive mirrors\033[0m"
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
    else
        echo -e "\033[032mUsing Debian's active repositories\033[0m"
    fi
    echo
    echo -e "Using APT sources:\033[036m"
    if [[ -f /etc/apt/sources.list ]]; then
        cat /etc/apt/sources.list | egrep "^deb(\-)?"
    fi
    if [[ -d /etc/apt/sources.list.d && $(ls -1 /etc/apt/sources.list.d/* | wc -l) -gt 0 ]]; then
        cat /etc/apt/sources.list.d/* | egrep "^deb(\-)?"
    fi
    apt-get update
    echo -ne "\033[0m"

    # ────────────────────────────────────────────────────────────────────────────────
    F_LINE
    # ────────────────────────────────────────────────────────────────────────────────

    # Serve maintenance page with busybox temporarily
    [[ "$DOCKER_INSTALL_BUSYBOX" == "" ]] && export DOCKER_INSTALL_BUSYBOX="yes"
    F_LOG "DOCKER_INSTALL_BUSYBOX=${DOCKER_INSTALL_BUSYBOX}"
    if [[ "${DOCKER_INSTALL_BUSYBOX,,}" =~ ^(y|yes|1|true)$ ]]; then
        cat <<EOL > /tmp/lap-installer/index.html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Starting Up...</title>
<style>
    body {
    margin: 0;
    background: #1e1e1e;
    color: #ccc;
    font-family: "Fira Code", monospace;
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 2em;
    }
    h1 {
    color: #fff;
    margin-bottom: 0.5em;
    }
    #log-container {
    background: #121212;
    border: 1px solid #444;
    border-radius: 8px;
    color: #00CC00;
    width: 100%;
    max-width: 960px;
    height: 400px;
    overflow-y: auto;
    padding: 1em;
    box-shadow: 0 0 10px rgba(0,0,0,0.5);
    white-space: pre-wrap;
    font-size: .85rem;
    }
    .footer {
    margin-top: 1em;
    font-size: 0.9em;
    color: #666;
    }
</style>
</head>
<body>
<h1>🛠 Starting the container...</h1>
<div id="log-container">Loading logs...</div>
<div class="footer">Logs update every 3 seconds</div>
<script>
    async function fetchLogs() {
    try {
        const res = await fetch('/boot.log', { cache: 'no-store' });
        if (! res?.ok || (res.status < 200) || (res.status > 299)) {
            throw new Error("File not found");
        }
        const text = await res.text();
        document.getElementById('log-container').textContent = text;
        document.getElementById('log-container').scrollTop = document.getElementById('log-container').scrollHeight;
    } catch (err) {
        document.getElementById('log-container').textContent = "Unable to load logs. Make sure boot.log is available.";
        clearInterval(window.fetch_timer);
        setTimeout("location.reload();", 3000);
    }
    }
    window.fetch_timer = setInterval(fetchLogs, 3000);
    fetchLogs();
</script>
</body>
</html>
EOL
        apt-get -y install busybox
        busybox httpd -f -p 80 -h /tmp/lap-installer &
        TEMP_SERVER_PID=$!
        sleep 1
    fi

    # ────────────────────────────────────────────────────────────────────────────────
    F_LINE
    # ────────────────────────────────────────────────────────────────────────────────

    # Custom before installer script?
    if command -v lap-installer-before >/dev/null 2>&1; then
        bash lap-installer-before || { F_LOG "Error: before installer failed, aborting"; exit 1; }
    else
        F_LOG "No installer before script"
    fi

    # ────────────────────────────────────────────────────────────────────────────────
    F_LINE
    # ────────────────────────────────────────────────────────────────────────────────

    # User configuration - Part 1/2
    F_LOG "Checking user configuration (Part 1/2)"
    V_GID="${PGID:-1000}"
    V_GROUP="${DOCKER_OWNER_GROUP:-docker}"
    V_UID="${PUID:-1000}"
    V_USER="${DOCKER_OWNER_USER:-docker}"
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

    # ────────────────────────────────────────────────────────────────────────────────
    F_LINE
    # ────────────────────────────────────────────────────────────────────────────────

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

    apt install --no-install-recommends -y \
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
        pv \
        tree
    F_LOG "Done"

    # ────────────────────────────────────────────────────────────────────────────────
    F_LINE
    # ────────────────────────────────────────────────────────────────────────────────

    # Locales
    F_LOG "Installing and updating locales"
    # Install locales package
    apt install --no-install-recommends -y locales
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

    # ────────────────────────────────────────────────────────────────────────────────
    F_LINE
    # ────────────────────────────────────────────────────────────────────────────────

    # WKHTMLTOPDF
    [[ "$DOCKER_INSTALL_WKHTMLTOPDF" == "" ]] && export DOCKER_INSTALL_WKHTMLTOPDF="no"
    F_LOG "DOCKER_INSTALL_WKHTMLTOPDF=${DOCKER_INSTALL_WKHTMLTOPDF}"
    if [[ "${DOCKER_INSTALL_WKHTMLTOPDF,,}" =~ ^(y|yes|1|true)$ ]]; then
        F_LOG "Installing wkhtmltopdf"
        apt install --no-install-recommends -y \
            wkhtmltopdf
    else
        F_LOG "Skipping wkhtmltopdf install"
    fi

    # ────────────────────────────────────────────────────────────────────────────────
    F_LINE
    # ────────────────────────────────────────────────────────────────────────────────

    # Image Optimizers
    [[ "$DOCKER_INSTALL_IMAGE_OPTIMIZERS" == "" ]] && export DOCKER_INSTALL_IMAGE_OPTIMIZERS="yes"
    F_LOG "DOCKER_INSTALL_IMAGE_OPTIMIZERS=${DOCKER_INSTALL_IMAGE_OPTIMIZERS}"
    if [[ "${DOCKER_INSTALL_IMAGE_OPTIMIZERS,,}" =~ ^(y|yes|1|true)$ ]]; then
        F_LOG "Installing Image Optimizers"
        apt install --no-install-recommends -y \
            jpegoptim \
            gifsicle \
            optipng \
            pngquant
    else
        F_LOG "Skipping Image Optimizers install"
    fi

    # ────────────────────────────────────────────────────────────────────────────────
    F_LINE
    # ────────────────────────────────────────────────────────────────────────────────

    # PHP extensions list: https:/127.0.0.1/github.com/mlocati/docker-php-extension-installer#supported-php-extensions
    V_PHP_MAJOR_VERSION=$( php -r "echo explode('.', phpversion())[0];" )
    V_PHP_MAJOR_VERSION=$(( $V_PHP_MAJOR_VERSION * 1 ))
    F_LOG "PHP major version: ${V_PHP_MAJOR_VERSION}"
    V_PHP_MINOR_VERSION=$( php -r "echo explode('.', phpversion())[1];" )
    V_PHP_MINOR_VERSION=$(( $V_PHP_MINOR_VERSION * 1 ))
    F_LOG "PHP minor version: ${V_PHP_MINOR_VERSION}"

    # ────────────────────────────────────────────────────────────────────────────────
    F_LINE
    # ────────────────────────────────────────────────────────────────────────────────

    if [[ $( php -m | grep 'zip' | wc -l ) -eq 0 ]]; then
        F_LOG "Installing PHP extension zip"
        docker-php-ext-configure zip --with-libzip
        docker-php-ext-install -j$(nproc) zip
    else
        F_LOG "PHP extension zip already installed"
    fi

    # ────────────────────────────────────────────────────────────────────────────────
    F_LINE
    # ────────────────────────────────────────────────────────────────────────────────

    if [[ $( php -m | grep 'memcached' | wc -l ) -eq 0 ]]; then
        F_LOG "Installing PHP extension memcached"
        # ref: https://bobcares.com/blog/docker-php-ext-install-memcached/
        # ref: https://github.com/php-memcached-dev/php-memcached/issues/408
        if [[ $V_PHP_MAJOR_VERSION -eq 7 ]]; then
            set -ex \
                && DEBIAN_FRONTEND=noninteractive apt install --no-install-recommends -y libmemcached-dev \
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

    # ────────────────────────────────────────────────────────────────────────────────
    F_LINE
    # ────────────────────────────────────────────────────────────────────────────────

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

    # ────────────────────────────────────────────────────────────────────────────────
    F_LINE
    # ────────────────────────────────────────────────────────────────────────────────

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

    # ────────────────────────────────────────────────────────────────────────────────
    F_LINE
    # ────────────────────────────────────────────────────────────────────────────────

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
            apt install --no-install-recommends -y imagemagick libmagickwand-dev gcc make
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

    # ────────────────────────────────────────────────────────────────────────────────
    F_LINE
    # ────────────────────────────────────────────────────────────────────────────────

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

    # ────────────────────────────────────────────────────────────────────────────────
    F_LINE
    # ────────────────────────────────────────────────────────────────────────────────

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

    # ────────────────────────────────────────────────────────────────────────────────
    F_LINE
    # ────────────────────────────────────────────────────────────────────────────────

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

    # ────────────────────────────────────────────────────────────────────────────────
    F_LINE
    # ────────────────────────────────────────────────────────────────────────────────

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

    # ────────────────────────────────────────────────────────────────────────────────
    F_LINE
    # ────────────────────────────────────────────────────────────────────────────────

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

    # ────────────────────────────────────────────────────────────────────────────────
    F_LINE
    # ────────────────────────────────────────────────────────────────────────────────

    if [[ "$DOCKER_INSTALL_PHP_PCNTL" == "" ]]; then
        export DOCKER_INSTALL_PHP_PCNTL="yes"
    fi
    F_LOG "DOCKER_INSTALL_PHP_PCNTL=${DOCKER_INSTALL_PHP_PCNTL}"
    if [[ "${DOCKER_INSTALL_PHP_PCNTL,,}" =~ ^(y|yes|1|true)$ ]]; then
        if [[ $( php -m | grep 'pcntl' | wc -l ) -eq 0 ]]; then
            F_LOG "Installing PHP extension pcntl"
            docker-php-ext-install -j$(nproc) pcntl
        else
            F_LOG "PHP extension pcntl already installed"
        fi
    fi

    # ────────────────────────────────────────────────────────────────────────────────
    F_LINE
    # ────────────────────────────────────────────────────────────────────────────────

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

    # ────────────────────────────────────────────────────────────────────────────────
    F_LINE
    # ────────────────────────────────────────────────────────────────────────────────

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

    # ────────────────────────────────────────────────────────────────────────────────
    F_LINE
    # ────────────────────────────────────────────────────────────────────────────────

    # Apache mods
    F_LOG "Checking apache mods"
    if [[ ! -e /etc/apache2/mods-enabled/rewrite.load ]]; then
        a2enmod rewrite
    fi
    if [[ ! -e /etc/apache2/mods-enabled/headers.load ]]; then
        a2enmod headers
    fi
    F_LOG "Done"

    # ────────────────────────────────────────────────────────────────────────────────
    F_LINE
    # ────────────────────────────────────────────────────────────────────────────────

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
    V_USER_PATH=$( su - "$V_USER" -c ". ~/.bashrc; echo \$PATH" )
    F_LOG "${V_USER}'s \$PATH is /home/${V_USER_PATH}"

    # ────────────────────────────────────────────────────────────────────────────────
    F_LINE
    # ────────────────────────────────────────────────────────────────────────────────

    # Composer
    [[ "$DOCKER_INSTALL_COMPOSER" == "" ]] && export DOCKER_INSTALL_COMPOSER="yes"
    F_LOG "DOCKER_INSTALL_COMPOSER=${DOCKER_INSTALL_COMPOSER}"
    if [[ "${DOCKER_INSTALL_COMPOSER,,}" =~ ^(y|yes|1|true)$ ]]; then
        composer-use latest
    fi

    # ────────────────────────────────────────────────────────────────────────────────
    F_LINE
    # ────────────────────────────────────────────────────────────────────────────────

    # NodeJS
    [[ "$DOCKER_INSTALL_NODEJS" == "" ]] && export DOCKER_INSTALL_NODEJS="no"
    F_LOG "DOCKER_INSTALL_NODEJS=${DOCKER_INSTALL_NODEJS}"
    if [[ "${DOCKER_INSTALL_NODEJS,,}" =~ ^(y|yes|1|true)$ ]]; then
        F_LOG "Installing NodeJS"
        node-use latest
    else
        F_LOG "Skipping NodeJS install"
    fi

    # ────────────────────────────────────────────────────────────────────────────────
    F_LINE
    # ────────────────────────────────────────────────────────────────────────────────

    # Packages that require python
    [[ "$DOCKER_INSTALL_SUPERVISOR" == "" ]] && export DOCKER_INSTALL_SUPERVISOR="no"

    # Python
    [[ "$DOCKER_INSTALL_PYTHON3" == "" ]] && export DOCKER_INSTALL_PYTHON3="yes"

    # Enable python install when required by a package
    if [[ ! "${DOCKER_INSTALL_PYTHON3,,}" =~ ^(y|yes|1|true)$ ]]; then
        if [[ "${DOCKER_INSTALL_SUPERVISOR,,}" =~ ^(y|yes|1|true)$ ]]; then
            export DOCKER_INSTALL_PYTHON3="yes"
        fi
    fi

    F_LOG "DOCKER_INSTALL_PYTHON3=${DOCKER_INSTALL_PYTHON3}"
    if [[ "${DOCKER_INSTALL_PYTHON3,,}" =~ ^(y|yes|1|true)$ ]]; then
        F_LOG "Installing Python3"
        apt install --no-install-recommends -y python3
        python3 -V
    else
        F_LOG "Skipping Python3 install"
    fi

    # ────────────────────────────────────────────────────────────────────────────────
    F_LINE
    # ────────────────────────────────────────────────────────────────────────────────

    # Supervisor
    F_LOG "DOCKER_INSTALL_SUPERVISOR=${DOCKER_INSTALL_SUPERVISOR}"
    if [[ "${DOCKER_INSTALL_SUPERVISOR,,}" =~ ^(y|yes|1|true)$ ]]; then
        F_LOG "Installing Supervisor"
        apt install --no-install-recommends -y supervisor
        if [[ ! -d /etc/supervisor ]]; then
            F_LOG "Creating Supervisor configuration directory /etc/supervisor"
            mkdir -p /etc/supervisor
        fi
        if [[ ! -d /etc/supervisor/conf.d ]]; then
            F_LOG "Creating Supervisor configuration directory /etc/supervisor/conf.d"
            mkdir -p /etc/supervisor/conf.d
        fi
        if [[ ! -f /etc/supervisor/supervisord.conf ]]; then
            F_LOG "Creating Supervisor configuration file /etc/supervisor/supervisord.conf"
            echo_supervisord_conf > /etc/supervisor/supervisord.conf
            echo "" >> /etc/supervisor/supervisord.conf
            echo "[supervisord]" >> /etc/supervisor/supervisord.conf
            echo "user=docker" >> /etc/supervisor/supervisord.conf
            echo "" >> /etc/supervisor/supervisord.conf
            echo "[include]" >> /etc/supervisor/supervisord.conf
            echo "files = /etc/supervisor/conf.d/*.conf" >> /etc/supervisor/supervisord.conf
        fi
        echo -e "\n\033[031mIMPORTANT: remember to start the supervisor daemon with command: supervisord -c /etc/supervisor/supervisord.conf\033[0m\n"
    else
        F_LOG "Skipping Supervisor install"
    fi

    # ────────────────────────────────────────────────────────────────────────────────
    F_LINE
    # ────────────────────────────────────────────────────────────────────────────────

    # Slatedocs
    [[ "$DOCKER_INSTALL_SLATE" == "" ]] && export DOCKER_INSTALL_SLATE="no"
    F_LOG "DOCKER_INSTALL_SLATE=${DOCKER_INSTALL_SLATE}"
    if [[ "${DOCKER_INSTALL_SLATE,,}" =~ ^(y|yes|1|true)$ ]]; then
        F_LOG "Installing Slate"
        apt install --no-install-recommends -y ruby ruby-dev build-essential libffi-dev zlib1g-dev liblzma-dev nodejs patch bundler
        if [[ -d /slate ]]; then
            echo "Removing old /slate directory"
            rm -rf /slate
        fi
        mkdir /slate
        chmod 0775 /slate
        chown "$V_USER":"$V_USER" /slate
        su -c "git clone git@github.com:slatedocs/slate.git /slate/" "$V_USER"
        if [[ -d /slate/.git ]]; then
            rm -rf /slate/.git
        fi
        if [[ -d /slate/source ]]; then
            rm -rf /slate/source
        fi
        V_PWD=$( pwd )
        cd /slate
        su -c "bundle config set --local path 'vendor/bundle'" "$V_USER"
        su -c "bundle install" "$V_USER"
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

    # ────────────────────────────────────────────────────────────────────────────────
    F_LINE
    # ────────────────────────────────────────────────────────────────────────────────

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
                su - "$V_USER" -c ". /home/${V_USER}/.bashrc; composer global require laravel/installer"
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

    # ────────────────────────────────────────────────────────────────────────────────
    F_LINE
    # ────────────────────────────────────────────────────────────────────────────────

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

    # ────────────────────────────────────────────────────────────────────────────────
    F_LINE
    # ────────────────────────────────────────────────────────────────────────────────

    # Custom after installer script?
    if command -v lap-installer-after >/dev/null 2>&1; then
        bash lap-installer-after || { F_LOG "Error: after installer failed, aborting"; exit 1; }
    else
        F_LOG "No installer after script"
    fi

    # ────────────────────────────────────────────────────────────────────────────────
    F_LINE
    # ────────────────────────────────────────────────────────────────────────────────

    # APT cleanup
    F_LOG "Running APT cleanup"
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false
    rm -rf /var/lib/apt/lists/*
    F_LOG "Done"

    # ────────────────────────────────────────────────────────────────────────────────
    F_LINE
    # ────────────────────────────────────────────────────────────────────────────────

    # Store the installation script version
    F_LOG "Updating installation version"
    if [[ ! -d /usr/share/docker ]]; then mkdir -p /usr/share/docker; fi
    echo "$V_REQUIRED_SCRIPT_HASH" > /usr/share/docker/lap-installer.hash
    V_NEW_SCRIPT_HASH=$( cat /usr/share/docker/lap-installer.hash )
    F_LOG "Using new script hash \033[036m${V_NEW_SCRIPT_HASH}\033[0m"
    F_LOG "Using required script hash \033[036m${V_REQUIRED_SCRIPT_HASH}\033[0m"
    if [[ ! "$V_NEW_SCRIPT_HASH" == "$V_REQUIRED_SCRIPT_HASH" ]]; then
        F_LOG "Warning: stored script hash mismatch (please debug if you would be so kind)"
    fi

    # ────────────────────────────────────────────────────────────────────────────────
    F_LINE
    # ────────────────────────────────────────────────────────────────────────────────

    F_LOG "Stopping the busybox server"
    if [[ $TEMP_SERVER_PID -gt 0 ]]; then

        ps ax | grep "$TEMP_SERVER_PID"
        ps ax | grep busybox
        echo "Killing process \033[036m${TEMP_SERVER_PID}\033[0m"

        kill $TEMP_SERVER_PID 2>/dev/null || true   # SIGTERM
        sleep 2

        # wait but ignore exit code
        wait $TEMP_SERVER_PID 2>/dev/null || true

        # fallback if still alive
        if ps -p $TEMP_SERVER_PID > /dev/null 2>&1; then
            kill -9 $TEMP_SERVER_PID
            wait $TEMP_SERVER_PID 2>/dev/null || true
        fi

        apt-get -y remove busybox || true
        apt-get -y purge busybox || true
    fi
    if [[ -d /tmp/lap-installer ]]; then
        rm -rf /tmp/lap-installer
    fi

    # ────────────────────────────────────────────────────────────────────────────────
    F_LINE
    # ────────────────────────────────────────────────────────────────────────────────

fi

exit 0