#!/bin/bash

# SHM Site Creation Script
# Usage: shm-site-create.sh <username> <domain> [php_version]

USERNAME=$1
DOMAIN=$2
PHP_VERSION=${3:-"8.1"} # Default to 8.1 if not specified

if [ -z "$USERNAME" ] || [ -z "$DOMAIN" ]; then
    echo "Error: Username and domain are required."
    exit 1
fi

TEMPLATES_DIR="/usr/local/shm/templates"
NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"
PHP_POOL_CONF="/etc/php/$PHP_VERSION/fpm/pool.d/$USERNAME.conf"

# Create Nginx Config
cp "$TEMPLATES_DIR/nginx/default.vhost" "$NGINX_CONF"
sed -i "s/{{DOMAIN}}/$DOMAIN/g" "$NGINX_CONF"
sed -i "s/{{USERNAME}}/$USERNAME/g" "$NGINX_CONF"
sed -i "s/{{PHP_VERSION}}/$PHP_VERSION/g" "$NGINX_CONF"

ln -s "$NGINX_CONF" "/etc/nginx/sites-enabled/$DOMAIN"

# Create PHP Pool Config
cp "$TEMPLATES_DIR/php-fpm/pool.conf" "$PHP_POOL_CONF"
sed -i "s/{{USERNAME}}/$USERNAME/g" "$PHP_POOL_CONF"
sed -i "s/{{PHP_VERSION}}/$PHP_VERSION/g" "$PHP_POOL_CONF"

# Reload Services
systemctl reload nginx
systemctl restart "php$PHP_VERSION-fpm"

echo "Site $DOMAIN created for user $USERNAME successfully."
