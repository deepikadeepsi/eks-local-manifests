#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "$1" == apache2* ]] || [ "$1" = 'php-fpm' ]; then
    uid="$(id -u)"
    gid="$(id -g)"
    if [ "$uid" = '0' ]; then
        case "$1" in
            apache2*)
                user="${APACHE_RUN_USER:-www-data}"
                group="${APACHE_RUN_GROUP:-www-data}"
                ;;
            *) # php-fpm
                user='www-data'
                group='www-data'
                ;;
        esac
    else
        user="$uid"
        group="$gid"
    fi

    if [ ! -e /var/www/html/index.php ] && [ ! -e /var/www/html/wp-includes/version.php ]; then
        echo >&2 "WordPress not found in /var/www/html/ - copying now..."
        if [ -n "$(find /var/www/html/ -mindepth 1 -maxdepth 1 -not -name wp-content)" ]; then
            echo >&2 "WARNING: /var/www/html/ is not empty! (copying anyhow)"
        fi

        sourceTarArgs=(
            --create
            --file -
            --directory /usr/src/wordpress
            --owner "$user" --group "$group"
        )
        targetTarArgs=(
            --extract
            --file -
        )
        if [ "$uid" != '0' ]; then
            targetTarArgs+=( --no-overwrite-dir )
        fi

        tar "${sourceTarArgs[@]}" . | tar "${targetTarArgs[@]}"
        echo >&2 "Complete! WordPress has been successfully copied to /var/www/html"
    fi

    cp -r /usr/src/wordpress/* /var/www/html/

    wpEnvs=( "${!WORDPRESS_@}" )
    if [ ! -s /var/www/html/wp-config.php ] && [ "${#wpEnvs[@]}" -gt 0 ]; then
        for wpConfigDocker in \
            /var/www/html/wp-config-docker.php \
            /usr/src/wordpress/wp-config-docker.php \
        ; do
            if [ -s "$wpConfigDocker" ]; then
                echo >&2 "No 'wp-config.php' found in /var/www/html, but 'WORDPRESS_...' variables supplied; copying '$wpConfigDocker' (${wpEnvs[*]})"
                awk '
                    /put your unique phrase here/ {
                        cmd = "head -c1m /dev/urandom | sha1sum | cut -d\\  -f1"
                        cmd | getline str
                        close(cmd)
                        gsub("put your unique phrase here", str)
                    }
                    { print }
                ' "$wpConfigDocker" > /var/www/html/wp-config.php
                if [ "$uid" = '0' ]; then
                    chown "$user:$group" /var/www/html/wp-config.php || true
                fi
                break
            fi
        done
    fi
fi

exec "$@"
