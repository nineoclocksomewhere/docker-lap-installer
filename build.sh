#!/usr/bin/env bash

ROOT=$( dirname $( readlink -f $0 ) )

VERSION="$1"
if [[ -z "$VERSION" ]]; then
    VERSION="all"
fi

PHPDIRS=()
if [[ "$VERSION" == "all" ]]; then
    while IFS= read -r -d '' dir; do
        PHPDIRS+=("$dir")
    done < <(find "$ROOT/images" -maxdepth 1 -type d -name "php*" -print0)
else
    PHPDIRS+=("$ROOT/images/php${VERSION}")
fi

DOCKERFILES=()
for PHPDIR in "${PHPDIRS[@]}"; do
    VERSION=$(basename "$PHPDIR" | sed 's/^php//')
    if [[ ! -d "$PHPDIR" ]]; then
        echo -e "\033[97m\033[41mError: no directory found for version $VERSION, aborting (${PHPDIR})\033[0m"
        exit 1
    fi
    DOCKERFILE="$PHPDIR/Dockerfile"
    if [[ ! -f "$DOCKERFILE" ]]; then
        echo -e "\033[97m\033[41mError: Dockerfile not found for version $VERSION, aborting (${DOCKERFILE})\033[0m"
        exit 1
    fi
    DOCKERFILES+=("$VERSION:$DOCKERFILE")
done

for DOCKERFILE in "${DOCKERFILES[@]}"; do
    VERSION=$(echo "$DOCKERFILE" | cut -d':' -f1)
    DOCKERFILE=$(echo "$DOCKERFILE" | cut -d':' -f2-)
    echo -e "\033[97m\033[44mBuilding image for version $VERSION using Dockerfile ${DOCKERFILE}\033[0m"
    docker build \
      -t nocs/php${VERSION}:1 \
      -t nocs/php${VERSION}:latest \
      -f "$DOCKERFILE" "$ROOT"

    if [[ "$2" == "--save" ]]; then
            echo -e "Creating tarball from docker image..."
        docker save -o "${ROOT}/images/php${VERSION}/php${VERSION}.tar" "nocs/php${VERSION}:latest"
        if [[ -f "${ROOT}/images/php${VERSION}/php${VERSION}.tar" ]]; then
            echo -e "\033[97m\033[42mImage saved to ${ROOT}/images/php${VERSION}/php${VERSION}.tar\033[0m"
            echo -e "Compressing tarball..."
            gzip -9 "${ROOT}/images/php${VERSION}/php${VERSION}.tar"
            if [[ -f "${ROOT}/images/php${VERSION}/php${VERSION}.tar.gz" ]]; then
                echo -e "\033[97m\033[42mImage compressed to ${ROOT}/images/php${VERSION}/php${VERSION}.tar.gz\033[0m"
            else
                echo -e "\033[97m\033[41mError: failed to compress image to ${ROOT}/images/php${VERSION}/php${VERSION}.tar.gz\033[0m"
                exit 1
            fi
        else
            echo -e "\033[97m\033[41mError: failed to save image to ${ROOT}/images/php${VERSION}/php${VERSION}.tar\033[0m"
            exit 1
        fi
    fi

done

exit 0