#!/bin/bash

# SHM Panel Deployment Script
# Run this after uploading SHM Panel files

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    error "Please run as root"
    exit 1
fi

APP_USER="shmuser"
WEB_ROOT="/var/www/shm-panel"
DB_NAME="shm_panel"
DB_USER="shm_user"
DB_PASSWORD=$(openssl rand -base64 16)

log "Starting SHM Panel Deployment"

# Check if SHM Panel files exist
if [ ! -f "$WEB_ROOT/index.php" ]; then
    error "SHM Panel files not found in $WEB_ROOT"
    echo "Please upload SHM Panel files first"
    exit 1
fi

# Set proper permissions
log "Setting file permissions..."
chown -R $APP_USER:www-data $WEB_ROOT
find $WEB_ROOT -type d -exec chmod 755 {} \;
find $WEB_ROOT -type f -exec chmod 644 {} \;
chmod 600 $WEB_ROOT/includes/config.php 2>/dev/null || true

# Create upload and temp directories
mkdir -p $WEB_ROOT/uploads $WEB_ROOT/temp
chown -R www-data:www-data $WEB_ROOT/uploads $WEB_ROOT/temp
chmod 755 $WEB_ROOT/uploads $WEB_ROOT/temp

# Create database and user
log "Creating database and user..."
mysql -e "CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';"
mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# Create database configuration
if [ ! -f "$WEB_ROOT/includes/config.php" ]; then
    log "Creating database configuration..."
    cat > $WEB_ROOT/includes/config.php << EOF
<?php
define('DB_HOST', 'localhost');
define('DB_NAME', '$DB_NAME');
define('DB_USER', '$DB_USER');
define('DB_PASS', '$DB_PASSWORD');
define('SITE_URL', 'http://$(hostname -I | awk '{print $1}')');
?>
EOF
    chown $APP_USER:www-data $WEB_ROOT/includes/config.php
    chmod 600 $WEB_ROOT/includes/config.php
fi

# Run installation
log "Running installation..."
# Note: The web-based installer will handle the rest

# Set up log files
touch /var/log/shm-panel/application.log
chown $APP_USER:www-data /var/log/shm-panel/application.log
chmod 644 /var/log/shm-panel/application.log

# Create application cron jobs
log "Setting up cron jobs..."
(crontab -u $APP_USER -l 2>/dev/null; echo "*/5 * * * * /usr/bin/php $WEB_ROOT/cron.php >/dev/null 2>&1") | crontab -u $APP_USER -

# Test PHP configuration
log "Testing PHP configuration..."
echo "<?php phpinfo(); ?>" > $WEB_ROOT/test.php
chown $APP_USER:www-data $WEB_ROOT/test.php

# Restart web services
log "Restarting web services..."
systemctl restart nginx
systemctl restart php8.4-fpm

# Display deployment information
log "SHM Panel Deployment Completed!"
echo ""
echo "=== DEPLOYMENT INFORMATION ==="
echo "Web URL: http://$(hostname -I | awk '{print $1}')"
echo "Database Name: $DB_NAME"
echo "Database User: $DB_USER"
echo "Database Password: $DB_PASSWORD"
echo ""
echo "=== NEXT STEPS ==="
echo "1. Access http://$(hostname -I | awk '{print $1}')/install/"
echo "2. Complete the web-based installation"
echo "3. Remove test file: rm $WEB_ROOT/test.php"
echo "4. Configure your domains in the SHM Panel"
echo ""
echo "Database credentials saved to: $WEB_ROOT/includes/config.php"

# Save deployment info
cat > /root/shm-deployment-info.txt << EOF
SHM Panel Deployment
====================
Deployed: $(date)
Database: $DB_NAME
Database User: $DB_USER
Database Password: $DB_PASSWORD
Web Root: $WEB_ROOT
App User: $APP_USER

Installation URL: http://$(hostname -I | awk '{print $1}')/install/
EOF

log "Deployment information saved to /root/shm-deployment-info.txt"
