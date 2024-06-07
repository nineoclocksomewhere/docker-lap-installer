# docker-lap-installer

Docker LAP installer. When mounting this script with Docker's volumes
you can use PHP's official Docker images (apache-debian) with the extra
installations this script performs. Make sure the script has the execute
permission set. This installer is mainly created to avoid rebuilding
Docker images that could be large in size.

Remember that the first time you're starting the container it could take
a while until fully booted. So be patient when you see your website still
showing 'Bad Gateway' when refreshing. For the first time it's better to
start your containers in attached state so you can see the progress.
To be sure you can end the containers when fully operational with ctrl+C,
wait and restart them in attached mode. An already up-to-date message
should be shown and the server should be up in no time.
```
foo_web        | Installation is up-to-date (v1.0.10)
```
From now on you can start the container in detached mode.

# Configuration

Search for the PHP version of your choice at https://hub.docker.com/_/php/tags .
Select a version with the tag-name ending in *-apache-&lt;debian-release-name&gt;*,
for example *8.3.8-apache-bullseye*.

# Usage

## Basic usage

Mount the script as volume and run a combined command.

Example:
```yaml
  web:
    image: php:7.4.33-apache-bullseye
    restart: unless-stopped
    environment:
      - TZ=Europe/Brussels
      - PUID=1000
      - PGID=1000
      - APACHE_RUN_USER=docker
      - APACHE_RUN_GROUP=docker
    volumes:
      - .:/var/www/html:rw
      - ./.docker/conf/000-default.conf:/etc/apache2/sites-available/000-default.conf
      - ./.docker/conf/php.ini:/usr/local/etc/php/php.ini
      - ./.docker/lap-installer.sh:/usr/local/bin/lap-installer
    command: /bin/sh -c "lap-installer && apache2-foreground"
```

## Using the lap-updater script

With the lap-updater script you keep your Docker container up-to-date.

Instead of adding the lap-installer.sh script to your volumes, add the lap-updater.sh script.
```yaml
    volumes:
      ...
      - ./.docker/lap-updater.sh:/usr/local/bin/lap-updater
    command: /bin/sh -c "lap-updater && apache2-foreground"
```

