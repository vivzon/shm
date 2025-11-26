#!/bin/bash

# ==========================================
# SHM Panel Setup Script
# Features: Nginx, DNS, Mail, Manual PMA/Roundcube
# PHP: Auto-detect or Install PHP 8.4
# ==========================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
log() { echo -e "${GREEN}[$(date +'%T')] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; }
info() { echo -e "${BLUE}[INFO] $1${NC}"; }

# Root Check
if [ "$EUID" -ne 0 ]; then 
    error "Please run as root"
    exit 1
fi

# ==========================================
# INPUT
# ==========================================
clear
echo -e "${YELLOW}==============================================${NC}"
echo -e "${YELLOW}   SHM Panel: Nginx + Postfix + DNS + Tools   ${NC}"
echo -e "${YELLOW}   PHP: Auto-detects or Installs PHP 8.4      ${NC}"
echo -e "${YELLOW}==============================================${NC}"
echo ""
read -p "Enter your Domain Name (e.g., example.com): " DOMAIN_NAME

if [ -z "$DOMAIN_NAME" ]; then
    error "Domain name is required."
    exit 1
fi

# Configuration Variables
SERVER_IP=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')
TIMEZONE="Asia/Kolkata"
ADMIN_USER="shmadmin"
SSH_PORT="2222"
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)
APP_USER="shmuser"
APP_USER_PASSWORD=$(openssl rand -base64 16)
PMA_BLOWFISH=$(openssl rand -base64 32)
ROUNDCUBE_DB_PASS=$(openssl rand -base64 24)
MAIL_USER_PASS=$(openssl rand -base64 16)

# ==========================================
# SYSTEM PREP
# ==========================================
log "Updating system and installing base dependencies..."
export DEBIAN_FRONTEND=noninteractive
apt update && apt upgrade -y
apt install -y software-properties-common curl wget git unzip htop gnupg2 lsb-release ufw fail2ban

# ==========================================
# PHP AUTO-DETECT OR INSTALL 8.4
# ==========================================
log "Configuring PHP..."

PHP_VERSION=""

if command -v php &> /dev/null; then
    # Detect existing version
    PHP_VERSION=$(php -v | head -n 1 | cut -d " " -f 2 | cut -d "." -f 1,2)
    info "Existing PHP version detected: $PHP_VERSION"
else
    # Install PHP 8.4 via Ondrej PPA
    warning "PHP not found. Installing PHP 8.4..."
    add-apt-repository ppa:ondrej/php -y
    apt update
    apt install -y php8.4-fpm php8.4-cli
    PHP_VERSION="8.4"
fi

# Install Required Extensions for the specific version
log "Installing extensions for PHP $PHP_VERSION..."
PHP_EXT="php${PHP_VERSION}-fpm php${PHP_VERSION}-mysql php${PHP_VERSION}-curl php${PHP_VERSION}-gd php${PHP_VERSION}-mbstring php${PHP_VERSION}-xml php${PHP_VERSION}-zip php${PHP_VERSION}-bcmath php${PHP_VERSION}-intl php${PHP_VERSION}-soap php${PHP_VERSION}-ldap php${PHP_VERSION}-imagick"

apt install -y $PHP_EXT

# ==========================================
# CORE SERVICES
# ==========================================
log "Installing Nginx, MySQL, Bind9, Certbot..."
apt install -y nginx mysql-server bind9 bind9utils bind9-doc dnsutils certbot python3-certbot-nginx

timedatectl set-timezone $TIMEZONE

# ==========================================
# MYSQL SETUP
# ==========================================
log "Securing MySQL..."
systemctl start mysql
systemctl enable mysql

# Secure Root & Remove Test DB
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD';"
mysql -e "DELETE FROM mysql.user WHERE User='';"
mysql -e "DROP DATABASE IF EXISTS test;"
mysql -e "FLUSH PRIVILEGES;"

# Create .my.cnf
cat > /root/.my.cnf << EOF
[client]
user=root
password=$MYSQL_ROOT_PASSWORD
EOF
chmod 600 /root/.my.cnf

# ==========================================
# PHPMYADMIN (MANUAL INSTALL)
# ==========================================
log "Installing phpMyAdmin (Manual Source)..."
PMA_VER="5.2.1"
cd /tmp
wget -q https://files.phpmyadmin.net/phpMyAdmin/${PMA_VER}/phpMyAdmin-${PMA_VER}-all-languages.zip
unzip -q phpMyAdmin-${PMA_VER}-all-languages.zip
rm -rf /var/www/phpmyadmin
mv phpMyAdmin-${PMA_VER}-all-languages /var/www/phpmyadmin
rm phpMyAdmin-${PMA_VER}-all-languages.zip

# Configure PMA
cp /var/www/phpmyadmin/config.sample.inc.php /var/www/phpmyadmin/config.inc.php
sed -i "s/\$cfg\['blowfish_secret'\] = '';/\$cfg\['blowfish_secret'\] = '$PMA_BLOWFISH';/" /var/www/phpmyadmin/config.inc.php
mkdir -p /var/www/phpmyadmin/tmp
chown -R www-data:www-data /var/www/phpmyadmin

# ==========================================
# ROUNDCUBE WEBMAIL (MANUAL INSTALL)
# ==========================================
log "Installing Roundcube Webmail (Latest Stable)..."

# Download Latest Roundcube
cd /tmp
RC_VER="1.6.9" # Latest stable as of late 2024
wget -q https://github.com/roundcube/roundcubemail/releases/download/${RC_VER}/roundcubemail-${RC_VER}-complete.tar.gz
tar -xf roundcubemail-${RC_VER}-complete.tar.gz
rm -rf /var/www/webmail
mv roundcubemail-${RC_VER} /var/www/webmail
rm roundcubemail-${RC_VER}-complete.tar.gz

# Database Setup
mysql -e "CREATE DATABASE IF NOT EXISTS roundcubemail DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "CREATE USER IF NOT EXISTS 'roundcube'@'localhost' IDENTIFIED BY '$ROUNDCUBE_DB_PASS';"
mysql -e "GRANT ALL PRIVILEGES ON roundcubemail.* TO 'roundcube'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# Import SQL
mysql -u roundcube -p$ROUNDCUBE_DB_PASS roundcubemail < /var/www/webmail/SQL/mysql.initial.sql

# Config
cat > /var/www/webmail/config/config.inc.php << EOF
<?php
\$config['db_dsnw'] = 'mysql://roundcube:$ROUNDCUBE_DB_PASS@localhost/roundcubemail';
\$config['default_host'] = 'localhost';
\$config['smtp_server'] = 'localhost';
\$config['smtp_port'] = 25;
\$config['smtp_user'] = '%u';
\$config['smtp_pass'] = '%p';
\$config['product_name'] = 'SHM Webmail';
\$config['des_key'] = '$(openssl rand -base64 24)';
\$config['plugins'] = array('archive', 'zipdownload');
\$config['skin'] = 'elastic';
EOF

# Permissions
chown -R www-data:www-data /var/www/webmail

# ==========================================
# DNS (BIND9)
# ==========================================
log "Configuring DNS..."
mkdir -p /etc/bind/zones

# Options
cat > /etc/bind/named.conf.options << EOF
acl "trusted" { 127.0.0.1; $SERVER_IP; };
options {
    directory "/var/cache/bind";
    recursion yes;
    allow-recursion { trusted; };
    listen-on { any; };
    allow-transfer { none; };
    forwarders { 8.8.8.8; 1.1.1.1; };
    dnssec-validation auto;
};
EOF

# Local Zone Config
cat > /etc/bind/named.conf.local << EOF
zone "$DOMAIN_NAME" { type master; file "/etc/bind/zones/db.$DOMAIN_NAME"; };
EOF

# Zone File
SERIAL=$(date +%Y%m%d01)
cat > /etc/bind/zones/db.$DOMAIN_NAME << EOF
\$TTL    604800
@       IN      SOA     ns1.$DOMAIN_NAME. admin.$DOMAIN_NAME. (
                  $SERIAL     ; Serial
             604800     ; Refresh
              86400     ; Retry
            2419200     ; Expire
             604800 )   ; Negative Cache TTL
; NS Records
@       IN      NS      ns1.$DOMAIN_NAME.
@       IN      NS      ns2.$DOMAIN_NAME.

; A Records
@       IN      A       $SERVER_IP
ns1     IN      A       $SERVER_IP
ns2     IN      A       $SERVER_IP
www     IN      A       $SERVER_IP
mail    IN      A       $SERVER_IP
webmail IN      A       $SERVER_IP

; Mail
@       IN      MX      10 mail.$DOMAIN_NAME.
EOF

systemctl restart bind9

# ==========================================
# POSTFIX & DOVECOT
# ==========================================
log "Installing Mail Server..."
debconf-set-selections <<< "postfix postfix/mailname string $DOMAIN_NAME"
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
apt install -y postfix dovecot-core dovecot-imapd dovecot-pop3d

# Postfix Config
postconf -e "myhostname = mail.$DOMAIN_NAME"
postconf -e "mydestination = \$myhostname, localhost.\$mydomain, localhost, $DOMAIN_NAME"
postconf -e "home_mailbox = Maildir/"

# Dovecot Config
sed -i 's/#disable_plaintext_auth = yes/disable_plaintext_auth = no/' /etc/dovecot/conf.d/10-auth.conf
sed -i 's/auth_mechanisms = plain/auth_mechanisms = plain login/' /etc/dovecot/conf.d/10-auth.conf
sed -i 's|mail_location = .*|mail_location = maildir:~/Maildir|' /etc/dovecot/conf.d/10-mail.conf

systemctl restart postfix dovecot

# ==========================================
# NGINX CONFIGURATION
# ==========================================
log "Configuring Nginx..."

# Define Socket
PHP_SOCKET="unix:/run/php/php${PHP_VERSION}-fpm.sock"
info "Linking Nginx to PHP Socket: $PHP_SOCKET"

cat > /etc/nginx/sites-available/$DOMAIN_NAME << EOF
server {
    listen 80;
    server_name $DOMAIN_NAME www.$DOMAIN_NAME mail.$DOMAIN_NAME webmail.$DOMAIN_NAME ns1.$DOMAIN_NAME;
    root /var/www/shm-panel;
    index index.php index.html;

    # Logs
    access_log /var/log/nginx/${DOMAIN_NAME}_access.log;
    error_log /var/log/nginx/${DOMAIN_NAME}_error.log;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    # phpMyAdmin
    location /phpmyadmin {
        alias /var/www/phpmyadmin;
        index index.php;
        try_files \$uri \$uri/ /phpmyadmin/index.php;

        location ~ ^/phpmyadmin/(.+\.php)\$ {
            alias /var/www/phpmyadmin;
            fastcgi_pass $PHP_SOCKET;
            fastcgi_index index.php;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$request_filename;
        }
    }

    # Roundcube Webmail
    location /webmail {
        alias /var/www/webmail;
        index index.php;
        try_files \$uri \$uri/ /webmail/index.php;

        location ~ ^/webmail/(.+\.php)\$ {
            alias /var/www/webmail;
            fastcgi_pass $PHP_SOCKET;
            fastcgi_index index.php;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$request_filename;
        }
    }

    # Handle PHP
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass $PHP_SOCKET;
    }

    location ~ /\.ht { deny all; }
}
EOF

# Enable Site
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/$DOMAIN_NAME /etc/nginx/sites-enabled/

# Create Panel Dir
mkdir -p /var/www/shm-panel
echo "<h1>SHM Panel Installed</h1><p>PHP Version: $PHP_VERSION</p><?php phpinfo(); ?>" > /var/www/shm-panel/index.php

# Create User
if ! id "$ADMIN_USER" &>/dev/null; then
    useradd -m -s /bin/bash $ADMIN_USER
    ADMIN_PASS=$(openssl rand -base64 12)
    echo "$ADMIN_USER:$ADMIN_PASS" | chpasswd
    usermod -aG sudo $ADMIN_USER
fi

# Firewall & SSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow $SSH_PORT/tcp
ufw allow 53
ufw allow 25,465,587/tcp
ufw allow 143,993/tcp
ufw --force enable

# Restart Services
systemctl restart nginx bind9 mysql php${PHP_VERSION}-fpm postfix dovecot

# ==========================================
# FINAL OUTPUT
# ==========================================
CRED_FILE="/root/shm_credentials.txt"
cat > $CRED_FILE << EOF
=== SHM PANEL CREDENTIALS ===
Domain: $DOMAIN_NAME
PHP Version: $PHP_VERSION
DB Root Pass: $MYSQL_ROOT_PASSWORD
Admin User: $ADMIN_USER
Admin Pass: $ADMIN_PASS
Webmail DB Pass: $ROUNDCUBE_DB_PASS
EOF
chmod 600 $CRED_FILE

echo ""
echo -e "${GREEN}INSTALLATION COMPLETE!${NC}"
echo "------------------------------------------------"
echo "URL Panel:      http://$DOMAIN_NAME/"
echo "URL Webmail:    http://$DOMAIN_NAME/webmail"
echo "URL phpMyAdmin: http://$DOMAIN_NAME/phpmyadmin"
echo "------------------------------------------------"
echo "PHP Version:    $PHP_VERSION (Socket: $PHP_SOCKET)"
echo "Credentials saved in: $CRED_FILE"
echo "------------------------------------------------"
