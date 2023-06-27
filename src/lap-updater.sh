#!/usr/bin/env bash

if [[ -f /tmp/lap-installer.sh ]]; then
    rm /tmp/lap-installer.sh
    if [[ -f /tmp/lap-installer.sh ]]; then
        echo -e "\033[031mError: removing previous lap-installer script failed, aborting\033[0m"
        exit 1
    fi
fi
if [[ $( which wget | wc -l ) -ge 1 ]]; then
    wget -v -O /tmp/lap-installer.sh https://raw.githubusercontent.com/nullester/docker-lap-installer/master/src/lap-installer.sh
elif [[ $( which curl | wc -l ) -ge 1 ]]; then
    curl -v -o /tmp/lap-installer.sh https://raw.githubusercontent.com/nullester/docker-lap-installer/master/src/lap-installer.sh
fi
if [[ ! -f /tmp/lap-installer.sh ]]; then
    echo -e "\033[031mError: downloading the lap-installer script failed, aborting\033[0m"
    exit 1
fi

chmod +x /tmp/lap-installer.sh
bash /tmp/lap-installer.sh
rm /tmp/lap-installer.sh > /dev/null 2>&1

exit 0
