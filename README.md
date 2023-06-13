# docker-lap-installer

Docker LAP installer. When mounting this script with Docker's volumes
you can use PHP's official Docker images (apache-debian) with the extra
installionts this script performs. This installer is mainly created to
avoid rebuilding Docker images that could be large in size.

Remember that the first time you're starting the container it could take
a while until fully booted. So be patient when you see your website still
showing 'Bad Gateway' when refreshing. For the first time it's better to
start your containers in a non-detached state so you can see the progress.
To be sure you can end the containers with ctrl+C, wait and restart them in
attached mode. An already up-to-date message should be shown and the server
should be up in no time.
```
foo_web        | Installation is up-to-date (v1.0.10)
```

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
