#!/bin/bash

# ==============================================================================
# SHM Panel Server Setup Script
# Structure: cPanel-style (public_html, etc, ssl)
# ==============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ------------------------------------------------------------------------------
# Logging Functions
# ------------------------------------------------------------------------------
log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; }
warning() { echo -e "${YELLOW}[WARNING] $1${NC}"; }
info() { echo -e "${BLUE}[INFO] $1${NC}"; }

# ------------------------------------------------------------------------------
# Pre-flight Checks
# ------------------------------------------------------------------------------
if [ "$EUID" -ne 0 ]; then 
    error "Please run as root"
    exit 1
fi

# ------------------------------------------------------------------------------
# Configuration Variables
# ------------------------------------------------------------------------------
SERVER_IP=$(hostname -I | awk '{print $1}')
TIMEZONE="Asia/Kolkata"
SSH_PORT="2222"

# Users
ADMIN_USER="shmadmin"
APP_USER="shmuser"

# Passwords (Auto-generated)
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)
APP_USER_PASSWORD=$(openssl rand -base64 16)
ADMIN_PASSWORD=$(openssl rand -base64 16)

# Directories
BASE_DIR="/var/www/shm_panel"
PUBLIC_HTML="$BASE_DIR/public_html"
CONFIG_DIR="$BASE_DIR/etc"
SSL_DIR="$BASE_DIR/ssl"
LOGS_DIR="$BASE_DIR/logs"
TMP_DIR="$BASE_DIR/tmp"
BACKUP_DIR="$BASE_DIR/backups"

log "Starting VPS Server Setup for SHM Panel"
log "Server IP: $SERVER_IP"

# ------------------------------------------------------------------------------
# System Updates & Essentials
# ------------------------------------------------------------------------------
log "Updating system packages..."
apt update && apt upgrade -y

log "Installing essential packages..."
apt install -y \
    curl wget git unzip htop \
    nginx mysql-server php-fpm \
    php-mysql php-curl php-gd php-mbstring \
    php-xml php-zip php-bcmath php-json \
    php-intl php-soap php-ldap \
    ufw fail2ban logrotate \
    software-properties-common

log "Setting timezone to $TIMEZONE..."
timedatectl set-timezone $TIMEZONE

# ------------------------------------------------------------------------------
# User Management
# ------------------------------------------------------------------------------
log "Creating application user: $APP_USER..."
if id "$APP_USER" &>/dev/null; then
    warning "User $APP_USER already exists"
else
    useradd -m -s /bin/bash $APP_USER
    echo "$APP_USER:$APP_USER_PASSWORD" | chpasswd
    usermod -aG sudo $APP_USER
fi

log "Creating admin user: $ADMIN_USER..."
if id "$ADMIN_USER" &>/dev/null; then
    warning "User $ADMIN_USER already exists"
else
    useradd -m -s /bin/bash $ADMIN_USER
    echo "$ADMIN_USER:$ADMIN_PASSWORD" | chpasswd
    usermod -aG sudo $ADMIN_USER
    
    # Save credentials
    echo "Admin User: $ADMIN_USER" > /root/server_credentials.txt
    echo "Admin Password: $ADMIN_PASSWORD" >> /root/server_credentials.txt
    echo "App User: $APP_USER" >> /root/server_credentials.txt
    echo "App Password: $APP_USER_PASSWORD" >> /root/server_credentials.txt
    echo "MySQL Root Password: $MYSQL_ROOT_PASSWORD" >> /root/server_credentials.txt
    chmod 600 /root/server_credentials.txt
fi

# ------------------------------------------------------------------------------
# Security (SSH, Firewall, Fail2Ban)
# ------------------------------------------------------------------------------
log "Configuring SSH security..."
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

cat > /etc/ssh/sshd_config << EOF
Port $SSH_PORT
Protocol 2
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication yes
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
AllowUsers $ADMIN_USER $APP_USER
EOF

log "Configuring firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow $SSH_PORT
ufw allow 80
ufw allow 443
ufw --force enable

log "Configuring fail2ban..."
systemctl enable fail2ban
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = $SSH_PORT
logpath = /var/log/auth.log
maxretry = 3

[nginx-http-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log
EOF

# ------------------------------------------------------------------------------
# MySQL Configuration
# ------------------------------------------------------------------------------
log "Configuring MySQL..."
systemctl enable mysql
systemctl start mysql

# Secure MySQL installation
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD';"
mysql -e "DELETE FROM mysql.user WHERE User='';"
mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
mysql -e "DROP DATABASE IF EXISTS test;"
mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
mysql -e "CREATE DATABASE IF NOT EXISTS shm_panel CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "FLUSH PRIVILEGES;"

# Create MySQL configuration for root
cat > /root/.my.cnf << EOF
[client]
user=root
password=$MYSQL_ROOT_PASSWORD
EOF
chmod 600 /root/.my.cnf

# ------------------------------------------------------------------------------
# PHP Configuration
# ------------------------------------------------------------------------------
log "Configuring PHP..."
PHP_VERSION=$(php -v | head -n 1 | cut -d " " -f 2 | cut -d "." -f 1,2)
cat > /etc/php/$PHP_VERSION/fpm/php.ini << EOF
[PHP]
engine = On
short_open_tag = Off
precision = 14
output_buffering = 4096
zlib.output_compression = Off
implicit_flush = Off
serialize_precision = -1
disable_functions = pcntl_alarm,pcntl_fork,pcntl_waitpid,pcntl_wait,pcntl_wifexited,pcntl_wifstopped,pcntl_wifsignaled,pcntl_wifcontinued,pcntl_wexitstatus,pcntl_wtermsig,pcntl_wstopsig,pcntl_signal,pcntl_signal_dispatch,pcntl_get_last_error,pcntl_strerror,pcntl_sigprocmask,pcntl_sigwaitinfo,pcntl_sigtimedwait,pcntl_exec,pcntl_getpriority,pcntl_setpriority,
memory_limit = 256M
error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT
display_errors = Off
display_startup_errors = Off
log_errors = On
max_execution_time = 300
post_max_size = 100M
upload_max_filesize = 100M
max_file_uploads = 20
date.timezone = "$TIMEZONE"
session.gc_probability = 1
session.gc_divisor = 1000
session.gc_maxlifetime = 1440
opcache.enable=1
opcache.memory_consumption=128
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=10000
opcache.revalidate_freq=2
opcache.fast_shutdown=1
EOF

# ------------------------------------------------------------------------------
# Directory Structure (cPanel Style) & Config Generation
# ------------------------------------------------------------------------------
log "Creating directory structure..."

# Create base directories
mkdir -p $PUBLIC_HTML
mkdir -p $CONFIG_DIR
mkdir -p $SSL_DIR
mkdir -p $LOGS_DIR
mkdir -p $TMP_DIR
mkdir -p $BACKUP_DIR

# 1. Database Config
if [ ! -f "$CONFIG_DIR/database.php" ]; then
    log "Generating Database Configuration..."
    cat > $CONFIG_DIR/database.php << EOF
<?php
return [
    'host' => 'localhost',
    'database' => 'shm_panel',
    'username' => 'root',
    'password' => '$MYSQL_ROOT_PASSWORD',
    'charset' => 'utf8mb4',
    'collation' => 'utf8mb4_unicode_ci',
    'port' => 3306,
];
EOF
fi

# 2. Email Config
if [ ! -f "$CONFIG_DIR/mail.php" ]; then
    log "Generating Email Configuration..."
    cat > $CONFIG_DIR/mail.php << EOF
<?php
return [
    'driver' => 'smtp',
    'host' => 'localhost',
    'port' => 587,
    'encryption' => 'tls',
    'username' => 'no-reply@localhost',
    'password' => '',
    'from' => [
        'address' => 'admin@localhost',
        'name' => 'SHM Panel Admin',
    ],
];
EOF
fi

# 3. General App Config
if [ ! -f "$CONFIG_DIR/app.php" ]; then
    log "Generating General App Configuration..."
    cat > $CONFIG_DIR/app.php << EOF
<?php
return [
    'name' => 'SHM Panel',
    'env' => 'production',
    'debug' => false,
    'url' => 'http://$SERVER_IP',
    'timezone' => '$TIMEZONE',
    'ssl' => [
        'enabled' => false,
        'cert_path' => '$SSL_DIR/server.crt',
        'key_path' => '$SSL_DIR/server.key',
    ],
    'paths' => [
        'base' => '$BASE_DIR',
        'public' => '$PUBLIC_HTML',
        'logs' => '$LOGS_DIR',
        'temp' => '$TMP_DIR',
    ]
];
EOF
fi

# 4. Placeholder index.php
if [ ! -f "$PUBLIC_HTML/index.php" ]; then
    cat > $PUBLIC_HTML/index.php << EOF
<?php
// SHM Panel Placeholder
\$dbConfig = include '../etc/database.php';
?>
<!DOCTYPE html>
<html>
<head><title>SHM Panel Installed</title></head>
<body>
    <div style="text-align: center; padding: 50px; font-family: sans-serif;">
        <h1 style="color: #2ecc71;">SHM Panel Installed Successfully</h1>
        <p>Server IP: $SERVER_IP</p>
        <p>System ready for code deployment.</p>
    </div>
</body>
</html>
EOF
fi

# Permissions
log "Setting directory permissions..."
chown -R $APP_USER:www-data $BASE_DIR
find $BASE_DIR -type d -exec chmod 755 {} \;
# Secure the config directory (User: RW, Group: R, World: No)
chmod 640 $CONFIG_DIR/*.php
# Logs writable by group (www-data needs to write logs)
chmod -R 775 $LOGS_DIR
chmod -R 775 $TMP_DIR

# ------------------------------------------------------------------------------
# Nginx Configuration
# ------------------------------------------------------------------------------
log "Configuring Nginx..."
cat > /etc/nginx/nginx.conf << EOF
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 768;
    multi_accept on;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml;

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF

# SHM Panel VHost
cat > /etc/nginx/sites-available/shm-panel << EOF
server {
    listen 80;
    server_name _;
    
    # Point to public_html (Code Directory)
    root $PUBLIC_HTML;
    index index.php index.html index.htm;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php$PHP_VERSION-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    # Deny access to sensitive directories (Double safety, even though they are outside root)
    location ~ /(etc|ssl|logs|tmp|backups) {
        deny all;
        return 404;
    }

    location ~ /\.env { deny all; }
    location ~ /\.git { deny all; }

    # Cache static files
    location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
}
EOF

# Enable Site
ln -sf /etc/nginx/sites-available/shm-panel /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Logrotate for App
cat > /etc/logrotate.d/shm-panel << EOF
$LOGS_DIR/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 $APP_USER www-data
    postrotate
        systemctl reload nginx
    endscript
}
EOF

# ------------------------------------------------------------------------------
# Helper Scripts
# ------------------------------------------------------------------------------

# 1. System Info Script
cat > /root/system-info.sh << EOF
#!/bin/bash
echo "=== SHM Panel System Info ==="
echo "URL: http://\$(hostname -I | awk '{print \$1}')"
echo "Root Dir: $PUBLIC_HTML"
echo "Config Dir: $CONFIG_DIR"
echo "--- Services ---"
echo "MySQL: \$(systemctl is-active mysql)"
echo "Nginx: \$(systemctl is-active nginx)"
echo "PHP: \$(systemctl is-active php$PHP_VERSION-fpm)"
echo "--- Resource Usage ---"
uptime -p
free -h | grep Mem | awk '{print "Mem: " \$3 "/" \$2}'
df -h / | awk 'NR==2 {print "Disk: " \$3 "/" \$2 " (" \$5 ")"}'
EOF
chmod +x /root/system-info.sh

# 2. Backup Script (Updated for structure)
cat > /root/backup-shm.sh << EOF
#!/bin/bash
# Backup script for SHM Panel

SOURCE_DIR="$BASE_DIR"
BACKUP_ROOT="$BACKUP_DIR"
DATE=\$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="shm-backup-\$DATE"

mkdir -p \$BACKUP_ROOT

echo "Starting SHM Panel backup..."

# Backup MySQL
mysqldump --all-databases > \$BACKUP_ROOT/\$BACKUP_NAME-mysql.sql
gzip \$BACKUP_ROOT/\$BACKUP_NAME-mysql.sql

# Backup Code (public_html)
tar -czf \$BACKUP_ROOT/\$BACKUP_NAME-code.tar.gz -C \$SOURCE_DIR public_html

# Backup Configs (etc & ssl)
tar -czf \$BACKUP_ROOT/\$BACKUP_NAME-config.tar.gz -C \$SOURCE_DIR etc ssl

echo "Backup saved to: \$BACKUP_ROOT"
# Keep last 7 days
find \$BACKUP_ROOT -name "shm-backup-*" -mtime +7 -delete
EOF
chmod +x /root/backup-shm.sh

# 3. Restore Script
cat > /root/restore-shm.sh << EOF
#!/bin/bash
# Restore script for SHM Panel

BACKUP_ROOT="$BACKUP_DIR"
TARGET_DIR="$BASE_DIR"

if [ -z "\$1" ]; then
    echo "Usage: \$0 <timestamp>"
    echo "Available backups:"
    ls \$BACKUP_ROOT/shm-backup-* 2>/dev/null | cut -d'-' -f3- | cut -d'.' -f1 | sort | uniq
    exit 1
fi

ID="\$1"
echo "Restoring backup ID: \$ID..."

systemctl stop nginx

# Restore DB
if [ -f "\$BACKUP_ROOT/shm-backup-\$ID-mysql.sql.gz" ]; then
    gunzip -c \$BACKUP_ROOT/shm-backup-\$ID-mysql.sql.gz | mysql
    echo "Database restored."
fi

# Restore Code
if [ -f "\$BACKUP_ROOT/shm-backup-\$ID-code.tar.gz" ]; then
    tar -xzf \$BACKUP_ROOT/shm-backup-\$ID-code.tar.gz -C \$TARGET_DIR
    echo "Code restored."
fi

# Restore Configs
if [ -f "\$BACKUP_ROOT/shm-backup-\$ID-config.tar.gz" ]; then
    tar -xzf \$BACKUP_ROOT/shm-backup-\$ID-config.tar.gz -C \$TARGET_DIR
    echo "Configs restored."
fi

# Fix Permissions
chown -R $APP_USER:www-data \$TARGET_DIR
systemctl start nginx
echo "Restore Complete."
EOF
chmod +x /root/restore-shm.sh

# 4. Monitor Script
cat > /root/monitor-shm.sh << EOF
#!/bin/bash
LOG_FILE="$LOGS_DIR/monitor.log"
{
    echo "--- \$(date) ---"
    if ! systemctl is-active --quiet mysql; then
        echo "MySQL DOWN - Restarting"
        systemctl restart mysql
    fi
    if ! systemctl is-active --quiet nginx; then
        echo "Nginx DOWN - Restarting"
        systemctl restart nginx
    fi
    if ! systemctl is-active --quiet php$PHP_VERSION-fpm; then
        echo "PHP DOWN - Restarting"
        systemctl restart php$PHP_VERSION-fpm
    fi
} >> \$LOG_FILE
tail -500 \$LOG_FILE > \$LOG_FILE.tmp && mv \$LOG_FILE.tmp \$LOG_FILE
EOF
chmod +x /root/monitor-shm.sh

# Add Cron Jobs
(crontab -l 2>/dev/null; echo "*/5 * * * * /root/monitor-shm.sh") | crontab -
(crontab -l 2>/dev/null; echo "0 2 * * * /root/backup-shm.sh") | crontab -

# ------------------------------------------------------------------------------
# Finalize
# ------------------------------------------------------------------------------
log "Restarting services..."
systemctl daemon-reload
systemctl restart mysql
systemctl restart nginx
systemctl restart php$PHP_VERSION-fpm
systemctl restart fail2ban
systemctl restart ssh

log "VPS Server Setup Completed!"
echo ""
echo "=== IMPORTANT INFORMATION ==="
echo "Server IP: $SERVER_IP"
echo "SSH Port: $SSH_PORT"
echo "Web Root: $PUBLIC_HTML"
echo "Config Dir: $CONFIG_DIR"
echo ""
echo "=== CREDENTIALS ==="
echo "Admin User: $ADMIN_USER"
echo "Admin Pass: $ADMIN_PASSWORD"
echo "App User: $APP_USER"
echo "MySQL Root Pass: $MYSQL_ROOT_PASSWORD"
echo "(Saved in /root/server_credentials.txt)"
echo ""
echo "=== COMMANDS ==="
echo "Status: /root/system-info.sh"
echo "Backup: /root/backup-shm.sh"
echo "Restore: /root/restore-shm.sh <id>"
echo ""
echo "Please reconnect using: ssh -p $SSH_PORT $ADMIN_USER@$SERVER_IP"
