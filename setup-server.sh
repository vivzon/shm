#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    error "Please run as root"
    exit 1
fi

# Configuration
SERVER_IP=$(hostname -I | awk '{print $1}')
TIMEZONE="Asia/Kolkata"
ADMIN_USER="shmadmin"
SSH_PORT="2222"
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)
APP_USER="shmuser"
APP_USER_PASSWORD=$(openssl rand -base64 16)

log "Starting VPS Server Setup for SHM Panel"
log "Server IP: $SERVER_IP"

# Update system
log "Updating system packages..."
apt update && apt upgrade -y

# Install essential packages
log "Installing essential packages..."
apt install -y \
    curl wget git unzip htop \
    nginx mysql-server php-fpm \
    php-mysql php-curl php-gd php-mbstring \
    php-xml php-zip php-bcmath php-json \
    php-intl php-soap php-ldap \
    ufw fail2ban logrotate \
    software-properties-common

# Set timezone
log "Setting timezone to $TIMEZONE..."
timedatectl set-timezone $TIMEZONE

# Create application user
log "Creating application user: $APP_USER..."
if id "$APP_USER" &>/dev/null; then
    warning "User $APP_USER already exists"
else
    useradd -m -s /bin/bash $APP_USER
    echo "$APP_USER:$APP_USER_PASSWORD" | chpasswd
    usermod -aG sudo $APP_USER
fi

# Create admin user
log "Creating admin user: $ADMIN_USER..."
if id "$ADMIN_USER" &>/dev/null; then
    warning "User $ADMIN_USER already exists"
else
    useradd -m -s /bin/bash $ADMIN_USER
    ADMIN_PASSWORD=$(openssl rand -base64 16)
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

# Configure SSH
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

# Configure firewall
log "Configuring firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow $SSH_PORT
ufw allow 80
ufw allow 443
ufw --force enable

# Configure fail2ban
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

[sshd-ddos]
enabled = true
port = $SSH_PORT
logpath = /var/log/auth.log
maxretry = 5

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log
EOF

# Configure MySQL
log "Configuring MySQL..."
systemctl enable mysql
systemctl start mysql

# Secure MySQL installation
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD';"
mysql -e "DELETE FROM mysql.user WHERE User='';"
mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
mysql -e "DROP DATABASE IF EXISTS test;"
mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
mysql -e "FLUSH PRIVILEGES;"

# Create MySQL configuration
cat > /root/.my.cnf << EOF
[client]
user=root
password=$MYSQL_ROOT_PASSWORD
EOF

chmod 600 /root/.my.cnf

# Configure PHP
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
unserialize_callback_func =
serialize_precision = -1
disable_functions = pcntl_alarm,pcntl_fork,pcntl_waitpid,pcntl_wait,pcntl_wifexited,pcntl_wifstopped,pcntl_wifsignaled,pcntl_wifcontinued,pcntl_wexitstatus,pcntl_wtermsig,pcntl_wstopsig,pcntl_signal,pcntl_signal_dispatch,pcntl_get_last_error,pcntl_strerror,pcntl_sigprocmask,pcntl_sigwaitinfo,pcntl_sigtimedwait,pcntl_exec,pcntl_getpriority,pcntl_setpriority,
disable_classes =
memory_limit = 256M
error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT
display_errors = Off
display_startup_errors = Off
log_errors = On
log_errors_max_len = 1024
ignore_repeated_errors = Off
ignore_repeated_source = Off
report_memleaks = On
track_errors = Off
html_errors = Off
variables_order = "GPCS"
request_order = "GP"
register_argc_argv = Off
auto_globals_jit = On
post_max_size = 100M
auto_prepend_file =
auto_append_file =
default_mimetype = "text/html"
default_charset = "UTF-8"
doc_root =
user_dir =
enable_dl = Off
file_uploads = On
upload_max_filesize = 100M
max_file_uploads = 20
allow_url_fopen = On
allow_url_include = Off
default_socket_timeout = 60

[Date]
date.timezone = "$TIMEZONE"

[filter]

[iconv]

[intl]

[sqlite]

[sqlite3]

[Pcre]

[Pdo]

[Pdo_mysql]
pdo_mysql.default_socket=

[Phar]

[mail function]
SMTP = localhost
smtp_port = 25
mail.add_x_header = On

[SQL]
sql.safe_mode = Off

[ODBC]

[MySQLi]
mysqli.default_port = 3306
mysqli.default_socket =
mysqli.default_host =
mysqli.default_user =
mysqli.default_pw =
mysqli.reconnect = Off

[mysqlnd]
mysqlnd.collect_statistics = On
mysqlnd.collect_memory_statistics = Off

[PostgreSQL]

[bcmath]

[browscap]

[Session]
session.save_handler = files
session.use_strict_mode = 0
session.use_cookies = 1
session.use_only_cookies = 1
session.name = PHPSESSID
session.auto_start = 0
session.cookie_lifetime = 0
session.cookie_path = /
session.cookie_domain =
session.cookie_httponly =
session.cookie_samesite =
session.serialize_handler = php
session.gc_probability = 1
session.gc_divisor = 1000
session.gc_maxlifetime = 1440
session.referer_check =
session.cache_limiter = nocache
session.cache_expire = 180
session.use_trans_sid = 0
session.sid_length = 26
session.trans_sid_tags = "a=href,area=href,frame=src,form="
session.sid_bits_per_character = 5

[Assertion]

[COM]

[mbstring]

[gd]

[exif]

[Tidy]
tidy.clean_output = Off

[soap]
soap.wsdl_cache_enabled=1
soap.wsdl_cache_dir="/tmp"
soap.wsdl_cache_ttl=86400
soap.wsdl_cache_limit = 5

[ldap]
ldap.max_links = -1

[dba]

[opcache]
opcache.enable=1
opcache.memory_consumption=128
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=10000
opcache.revalidate_freq=2
opcache.fast_shutdown=1
EOF

# Configure Nginx
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
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF

# Create SHM Panel nginx configuration
cat > /etc/nginx/sites-available/shm-panel << EOF
server {
    listen 80;
    server_name _;
    root /var/www/shm-panel;
    index index.php index.html index.htm;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    # Main location
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    # PHP handling
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php$PHP_VERSION-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    # Deny access to sensitive files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    location ~ /(config|logs|temp|uploads|install) {
        deny all;
        access_log off;
        log_not_found off;
    }

    location ~ /\.env {
        deny all;
        access_log off;
        log_not_found off;
    }

    # Cache static files
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|pdf|txt)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # File upload size
    client_max_body_size 100M;
    client_body_timeout 300;
}
EOF

# Enable site
ln -sf /etc/nginx/sites-available/shm-panel /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Create application directory
log "Creating application directory..."
mkdir -p /var/www/shm-panel
chown -R $APP_USER:www-data /var/www/shm-panel
chmod 755 /var/www/shm-panel

# Create log directory
mkdir -p /var/log/shm-panel
chown -R $APP_USER:www-data /var/log/shm-panel

# Configure logrotate for application
cat > /etc/logrotate.d/shm-panel << EOF
/var/log/shm-panel/*.log {
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

# Create startup script
cat > /root/startup-scripts.sh << 'EOF'
#!/bin/bash
# Startup scripts for SHM Panel

echo "Starting SHM Panel services..."

# Start essential services
systemctl start mysql
systemctl start nginx
systemctl start php8.1-fpm
systemctl start fail2ban

# Check service status
echo "Service Status:"
echo "MySQL: $(systemctl is-active mysql)"
echo "Nginx: $(systemctl is-active nginx)"
echo "PHP-FPM: $(systemctl is-active php8.1-fpm)"
echo "Fail2Ban: $(systemctl is-active fail2ban)"

# Display credentials (first run only)
if [ -f /root/first-run ]; then
    echo "=== SHM Panel First Run Information ==="
    echo "Admin SSH User: $(grep 'Admin User' /root/server_credentials.txt | cut -d: -f2)"
    echo "Admin SSH Password: $(grep 'Admin Password' /root/server_credentials.txt | cut -d: -f2)"
    echo "App User: $(grep 'App User' /root/server_credentials.txt | cut -d: -f2)"
    echo "App Password: $(grep 'App Password' /root/server_credentials.txt | cut -d: -f2)"
    echo "MySQL Root Password: $(grep 'MySQL Root' /root/server_credentials.txt | cut -d: -f2)"
    echo "======================================="
    rm -f /root/first-run
fi
EOF

chmod +x /root/startup-scripts.sh

# Create system info script
cat > /root/system-info.sh << 'EOF'
#!/bin/bash
echo "=== System Information ==="
echo "Hostname: $(hostname)"
echo "IP Address: $(hostname -I)"
echo "Uptime: $(uptime -p)"
echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
echo "Memory: $(free -h | grep Mem | awk '{print $3 "/" $2}')"
echo "Disk: $(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}')"
echo ""
echo "=== Service Status ==="
echo "MySQL: $(systemctl is-active mysql)"
echo "Nginx: $(systemctl is-active nginx)"
echo "PHP-FPM: $(systemctl is-active php8.1-fpm)"
echo "Fail2Ban: $(systemctl is-active fail2ban)"
echo ""
echo "=== Network ==="
ufw status
echo ""
echo "=== Recent Logins ==="
last -10
EOF

chmod +x /root/system-info.sh

# Create backup script
cat > /root/backup-shm.sh << 'EOF'
#!/bin/bash
# Backup script for SHM Panel

BACKUP_DIR="/root/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="shm-backup-$DATE"

mkdir -p $BACKUP_DIR

echo "Starting SHM Panel backup..."

# Backup MySQL databases
mysqldump --all-databases > $BACKUP_DIR/$BACKUP_NAME-mysql.sql
gzip $BACKUP_DIR/$BACKUP_NAME-mysql.sql

# Backup application files
tar -czf $BACKUP_DIR/$BACKUP_NAME-files.tar.gz /var/www/shm-panel

# Backup configurations
tar -czf $BACKUP_DIR/$BACKUP_NAME-config.tar.gz /etc/nginx /etc/mysql /etc/php

echo "Backup completed: $BACKUP_DIR/$BACKUP_NAME-*"
echo "File sizes:"
ls -lh $BACKUP_DIR/$BACKUP_NAME-*

# Cleanup old backups (keep last 7 days)
find $BACKUP_DIR -name "shm-backup-*" -mtime +7 -delete
EOF

chmod +x /root/backup-shm.sh

# Create restore script
cat > /root/restore-shm.sh << 'EOF'
#!/bin/bash
# Restore script for SHM Panel

BACKUP_DIR="/root/backups"

if [ -z "$1" ]; then
    echo "Usage: $0 <backup-timestamp>"
    echo "Available backups:"
    ls $BACKUP_DIR/shp-backup-* 2>/dev/null | cut -d'-' -f3- | cut -d'.' -f1 | sort
    exit 1
fi

BACKUP_NAME="shm-backup-$1"

if [ ! -f "$BACKUP_DIR/$BACKUP_NAME-mysql.sql.gz" ]; then
    echo "Backup not found: $BACKUP_NAME"
    exit 1
fi

echo "Restoring SHM Panel from backup: $1"

# Stop services
systemctl stop nginx
systemctl stop mysql

# Restore MySQL
gunzip -c $BACKUP_DIR/$BACKUP_NAME-mysql.sql.gz | mysql

# Restore files
tar -xzf $BACKUP_DIR/$BACKUP_NAME-files.tar.gz -C /

# Restore configurations
tar -xzf $BACKUP_DIR/$BACKUP_NAME-config.tar.gz -C /

# Start services
systemctl start mysql
systemctl start nginx

echo "Restore completed"
EOF

chmod +x /root/restore-shm.sh

# Create monitoring script
cat > /root/monitor-shm.sh << 'EOF'
#!/bin/bash
# Monitoring script for SHM Panel

LOG_FILE="/var/log/shm-panel/monitor.log"
ALERT_EMAIL="admin@localhost"

# Create log directory if not exists
mkdir -p /var/log/shm-panel

{
    echo "=== SHM Panel Health Check - $(date) ==="
    
    # Check services
    for service in mysql nginx php8.1-fpm; do
        if systemctl is-active --quiet $service; then
            echo "✅ $service is running"
        else
            echo "❌ $service is NOT running"
            systemctl restart $service
            echo "Attempted to restart $service"
        fi
    done
    
    # Check disk space
    DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | cut -d'%' -f1)
    if [ $DISK_USAGE -gt 90 ]; then
        echo "⚠️  High disk usage: $DISK_USAGE%"
    else
        echo "✅ Disk usage: $DISK_USAGE%"
    fi
    
    # Check memory
    MEM_USAGE=$(free | awk 'NR==2{printf "%.2f", $3*100/$2}')
    echo "Memory usage: $MEM_USAGE%"
    
    # Check load
    LOAD=$(uptime | awk -F'load average:' '{print $2}')
    echo "Load average: $LOAD"
    
    # Check MySQL connections
    MYSQL_CONNECTIONS=$(mysql -e "SHOW STATUS LIKE 'Threads_connected'" | awk 'NR==2 {print $2}')
    echo "MySQL connections: $MYSQL_CONNECTIONS"
    
} >> $LOG_FILE

# Keep only last 1000 lines in log file
tail -1000 $LOG_FILE > $LOG_FILE.tmp
mv $LOG_FILE.tmp $LOG_FILE
EOF

chmod +x /root/monitor-shm.sh

# Add to crontab for monitoring
(crontab -l 2>/dev/null; echo "*/5 * * * * /root/monitor-shm.sh >/dev/null 2>&1") | crontab -
(crontab -l 2>/dev/null; echo "0 2 * * * /root/backup-shm.sh >/dev/null 2>&1") | crontab -

# Restart services
log "Restarting services..."
systemctl daemon-reload
systemctl restart mysql
systemctl restart nginx
systemctl restart php$PHP_VERSION-fpm
systemctl restart fail2ban
systemctl restart ssh

# Enable services to start on boot
systemctl enable mysql nginx php$PHP_VERSION-fpm fail2ban ssh

# Create first run flag
touch /root/first-run

# Display completion message
log "VPS Server Setup Completed!"
echo ""
echo "=== IMPORTANT INFORMATION ==="
echo "SSH Port: $SSH_PORT"
echo "Admin User: $ADMIN_USER"
echo "Admin Password: $(grep 'Admin Password' /root/server_credentials.txt | cut -d: -f2)"
echo "App User: $APP_USER"
echo "App Password: $(grep 'App Password' /root/server_credentials.txt | cut -d: -f2)"
echo "MySQL Root Password: $(grep 'MySQL Root' /root/server_credentials.txt | cut -d: -f2)"
echo ""
echo "=== NEXT STEPS ==="
echo "1. SSH to server: ssh -p $SSH_PORT $ADMIN_USER@$SERVER_IP"
echo "2. Upload SHM Panel files to /var/www/shm-panel"
echo "3. Set proper permissions: chown -R $APP_USER:www-data /var/www/shm-panel"
echo "4. Access SHM Panel at: http://$SERVER_IP"
echo ""
echo "Credentials saved to: /root/server_credentials.txt"
echo "Use '/root/system-info.sh' to check system status"
echo "Use '/root/backup-shm.sh' to create backups"

# Save setup information
cat > /root/setup-info.txt << EOF
SHM Panel Server Setup
======================
Completed: $(date)
Server IP: $SERVER_IP
SSH Port: $SSH_PORT
Admin User: $ADMIN_USER
App User: $APP_USER
Web Root: /var/www/shm-panel
Database: MySQL (root password in server_credentials.txt)

Useful Commands:
- Check status: /root/system-info.sh
- Backup: /root/backup-shm.sh
- Restore: /root/restore-shm.sh <backup-timestamp>
- Monitor: /root/monitor-shm.sh

Services:
- MySQL: systemctl status mysql
- Nginx: systemctl status nginx
- PHP-FPM: systemctl status php$PHP_VERSION-fpm
- Fail2Ban: systemctl status fail2ban
EOF

log "Setup information saved to /root/setup-info.txt"