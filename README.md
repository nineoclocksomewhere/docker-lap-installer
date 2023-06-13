# docker-lap-installer

Docker LAP installer. When mounting this script with Docker's volumes
you can use PHP's official Docker images (apache-debian) with the extra
installionts this script performs. This installer is mainly created to
avoid rebuilding Docker images that could be large in size.

# Usage

Mount the script as volume and run a combined command.

Example:
```yaml
  web:
    image: php:7.4.33-apache-bullseye
    environment:
      - TZ=Europe/Brussels
      - PUID=1000
      - PGID=1000
      - APACHE_RUN_USER=docker
      - APACHE_RUN_GROUP=docker
      - DOCKER_INSTALL_COMPOSER=yes
      - DOCKER_INSTALL_NODEJS=yes
      - DOCKER_INSTALL_LARAVEL=no
    volumes:
      - .:/var/www/html:rw
      - ./.docker/conf/000-default.conf:/etc/apache2/sites-available/000-default.conf
      - ./.docker/conf/php.ini:/usr/local/etc/php/php.ini
      - ./.docker/conf/.bash_aliases:/home/docker/.bash_aliases:rw
      - ./.docker/lap-installer.sh:/usr/local/bin/lap-installer
    command:
      - /bin/sh
      - -c
      - |
        lap-installer
        apache2-foreground
    restart: "unless-stopped"

```
