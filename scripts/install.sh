#!/bin/bash

# SHM Master Installation Script
# Supports: Ubuntu 22.04 / 24.04 LTS

set -e

# Configuration
SHM_BASE="/usr/local/shm"
PANEL_USER="shm-panel"
DB_NAME="shm_panel"
DB_USER="shm_user"
DB_PASS=$(openssl rand -base64 12)

echo "------------------------------------------------"
echo "   SHM - Server Hosting Manager Installation"
echo "------------------------------------------------"

# 1. Update System
echo "[1/7] Updating system packages..."
apt update && apt upgrade -y

# 2. Install Dependencies
echo "[2/7] Installing core dependencies..."
apt install -y nginx mariadb-server php-fpm php-mysql php-xml php-mbstring \
    php-curl php-zip php-gd php-intl php-bcmath curl git unzip zip \
    certbot python3-certbot-nginx redis-server supervisor ufw fail2ban

# 3. Setup MariaDB
echo "[3/7] Configuring MariaDB..."
mysql -e "CREATE DATABASE IF NOT EXISTS $DB_NAME;"
mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# 4. Setup SHM Directory Structure & User
echo "[4/7] Setting up directory structure and user..."
if ! id "$PANEL_USER" &>/dev/null; then
    useradd -m -s /bin/bash "$PANEL_USER"
fi

mkdir -p "$SHM_BASE"/{scripts,templates,logs}
cp -r scripts/* "$SHM_BASE/scripts/"
cp -r templates/* "$SHM_BASE/templates/"
chmod +x "$SHM_BASE/scripts/"*.sh
chmod +x "$SHM_BASE/scripts/shm-manage"
ln -sf "$SHM_BASE/scripts/shm-manage" /usr/local/bin/shm-manage

# 5. Configure Panel Web Server & PHP-FPM
echo "[5/7] Configuring Nginx and PHP-FPM for the panel..."
PHP_VER=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')

# Configure PHP-FPM Pool
sed -i "s/{{PHP_VERSION}}/$PHP_VER/g" "$SHM_BASE/templates/php-fpm/panel-pool.conf"
cp "$SHM_BASE/templates/php-fpm/panel-pool.conf" "/etc/php/$PHP_VER/fpm/pool.d/shm-panel.conf"
systemctl restart "php$PHP_VER-fpm"

# Configure Nginx
sed -i "s/{{PHP_VERSION}}/$PHP_VER/g" "$SHM_BASE/templates/nginx/panel.vhost"
sed -i "s|{{PANEL_PATH}}|$SHM_BASE/panel|g" "$SHM_BASE/templates/nginx/panel.vhost"
cp "$SHM_BASE/templates/nginx/panel.vhost" /etc/nginx/sites-available/shm-panel
ln -sf /etc/nginx/sites-available/shm-panel /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
systemctl restart nginx

# 6. Sudoers & Firewall
echo "[6/7] Finalizing security and firewall..."
echo "$PANEL_USER ALL=(ALL) NOPASSWD: /usr/local/bin/shm-manage" > /etc/sudoers.d/shm
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw --force enable

# 7. Laravel Setup (Placeholder for real composer install)
echo "[7/7] Bootstrapping Laravel panel..."
# In a real environment: 
# cd $SHM_BASE/panel && composer install
# cp .env.example .env (and update DB_PASS)
# php artisan migrate --seed

echo "------------------------------------------------"
echo "   Installation Complete!"
echo "   Panel Database: $DB_NAME"
echo "   Database User: $DB_USER"
echo "   Database Pass: $DB_PASS"
echo "------------------------------------------------"

