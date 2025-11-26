#!/bin/bash

# ==========================================
# SHM MASTER SETUP SCRIPT (Final Revision)
# OS: Ubuntu 20.04 / 22.04 / 24.04
# Features: Nginx, PHP (Auto/8.4), MySQL, DNS, Mail
# ==========================================

# Colors for UI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ==========================================
# HELPER FUNCTIONS
# ==========================================
log() { echo -e "${GREEN}[$(date +'%T')] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; exit 1; }
info() { echo -e "${BLUE}[INFO] $1${NC}"; }
warning() { echo -e "${YELLOW}[WARNING] $1${NC}"; }

# Check Root
if [ "$EUID" -ne 0 ]; then 
    error "Please run this script as root."
fi

# ==========================================
# INPUT & VARIABLES
# ==========================================
clear
echo -e "${YELLOW}====================================================${NC}"
echo -e "${YELLOW}   SHM PANEL INSTALLER (Rev. Final)                 ${NC}"
echo -e "${YELLOW}   Nginx | PHP 8.4 | MySQL | Postfix | Roundcube    ${NC}"
echo -e "${YELLOW}====================================================${NC}"
echo ""

read -p "Enter your Domain Name (e.g., example.com): " DOMAIN_NAME
[ -z "$DOMAIN_NAME" ] && error "Domain name is required."

# Auto-detect Public IP
SERVER_IP=$(curl -s -4 ifconfig.me || hostname -I | awk '{print $1}')
[ -z "$SERVER_IP" ] && error "Could not detect Public IP."

# Variables
TIMEZONE="Asia/Kolkata"
SSH_PORT="2222"
ADMIN_USER="shmadmin"
# Generate Random Passwords
MYSQL_ROOT_PASS=$(openssl rand -base64 24)
ADMIN_PASS=$(openssl rand -base64 12)
ROUNDCUBE_DB_PASS=$(openssl rand -base64 18)
PMA_BLOWFISH=$(openssl rand -base64 32)

# ==========================================
# SYSTEM PREPARATION
# ==========================================
log "Updating system repositories and packages..."
export DEBIAN_FRONTEND=noninteractive
apt update -q && apt upgrade -y -q
apt install -y -q software-properties-common curl wget git unzip htop gnupg2 lsb-release ufw fail2ban acl

# ==========================================
# PHP INSTALLATION (AUTO-DETECT OR 8.4)
# ==========================================
log "Configuring PHP Environment..."

PHP_VERSION=""

if command -v php &> /dev/null; then
    # PHP exists, detect version (e.g., 8.1, 8.3)
    PHP_VERSION=$(php -v | head -n 1 | cut -d " " -f 2 | cut -d "." -f 1,2)
    info "Detected existing PHP version: $PHP_VERSION"
    # Ensure FPM is installed for this version
    apt install -y "php${PHP_VERSION}-fpm" "php${PHP_VERSION}-cli"
else
    # Install PHP 8.4
    warning "No PHP found. Adding Ondrej PPA and installing PHP 8.4..."
    add-apt-repository ppa:ondrej/php -y
    apt update -q
    apt install -y php8.4-fpm php8.4-cli
    PHP_VERSION="8.4"
fi

# Install Extensions Dynamic to Version
log "Installing Extensions for PHP $PHP_VERSION..."
PHP_EXT="php${PHP_VERSION}-mysql php${PHP_VERSION}-curl php${PHP_VERSION}-gd php${PHP_VERSION}-mbstring php${PHP_VERSION}-xml php${PHP_VERSION}-zip php${PHP_VERSION}-bcmath php${PHP_VERSION}-intl php${PHP_VERSION}-soap php${PHP_VERSION}-imagick php${PHP_VERSION}-gmp"
apt install -y $PHP_EXT

# Set PHP Socket Variable for Nginx
PHP_SOCKET="unix:/run/php/php${PHP_VERSION}-fpm.sock"

# ==========================================
# INSTALL CORE SERVICES
# ==========================================
log "Installing Nginx, MySQL, Bind9, Certbot..."
apt install -y nginx mysql-server bind9 bind9utils bind9-doc dnsutils certbot python3-certbot-nginx

# Set Timezone
timedatectl set-timezone $TIMEZONE

# ==========================================
# MYSQL CONFIGURATION
# ==========================================
log "Configuring MySQL Database..."
systemctl start mysql
systemctl enable mysql

# Create .my.cnf for root access without password prompt
cat > /root/.my.cnf << EOF
[client]
user=root
password=$MYSQL_ROOT_PASS
EOF
chmod 600 /root/.my.cnf

# Secure MySQL (Alter Root, Remove Anonymous, Remove Test)
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASS';" || mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASS';"
mysql -e "DELETE FROM mysql.user WHERE User='';"
mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
mysql -e "DROP DATABASE IF EXISTS test;"
mysql -e "FLUSH PRIVILEGES;"

# ==========================================
# PHPMYADMIN (MANUAL INSTALL)
# ==========================================
log "Installing phpMyAdmin (v5.2.1)..."
PMA_VER="5.2.1"
cd /tmp
wget -q "https://files.phpmyadmin.net/phpMyAdmin/${PMA_VER}/phpMyAdmin-${PMA_VER}-all-languages.zip"
unzip -q phpMyAdmin-${PMA_VER}-all-languages.zip
rm -rf /var/www/phpmyadmin
mv phpMyAdmin-${PMA_VER}-all-languages /var/www/phpmyadmin
rm phpMyAdmin-${PMA_VER}-all-languages.zip

# Config
cp /var/www/phpmyadmin/config.sample.inc.php /var/www/phpmyadmin/config.inc.php
sed -i "s/\$cfg\['blowfish_secret'\] = '';/\$cfg\['blowfish_secret'\] = '$PMA_BLOWFISH';/" /var/www/phpmyadmin/config.inc.php
# Fix permissions
mkdir -p /var/www/phpmyadmin/tmp
chown -R www-data:www-data /var/www/phpmyadmin
chmod 755 /var/www/phpmyadmin

# ==========================================
# ROUNDCUBE WEBMAIL (MANUAL INSTALL)
# ==========================================
log "Installing Roundcube Webmail (v1.6.9)..."
RC_VER="1.6.9"
cd /tmp
wget -q "https://github.com/roundcube/roundcubemail/releases/download/${RC_VER}/roundcubemail-${RC_VER}-complete.tar.gz"
tar -xf "roundcubemail-${RC_VER}-complete.tar.gz"
rm -rf /var/www/webmail
mv "roundcubemail-${RC_VER}" /var/www/webmail
rm "roundcubemail-${RC_VER}-complete.tar.gz"

# Create Webmail Database
mysql -e "CREATE DATABASE IF NOT EXISTS roundcubemail DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "CREATE USER IF NOT EXISTS 'roundcube'@'localhost' IDENTIFIED BY '$ROUNDCUBE_DB_PASS';"
mysql -e "GRANT ALL PRIVILEGES ON roundcubemail.* TO 'roundcube'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# Import Initial SQL
if [ -f "/var/www/webmail/SQL/mysql.initial.sql" ]; then
    mysql -u roundcube -p$ROUNDCUBE_DB_PASS roundcubemail < /var/www/webmail/SQL/mysql.initial.sql
else
    warning "Roundcube SQL file not found. Database might be incomplete."
fi

# Configure Roundcube
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
rm -rf /var/www/webmail/installer

# ==========================================
# DNS SERVER (BIND9)
# ==========================================
log "Configuring Bind9 DNS..."

mkdir -p /etc/bind/zones

# Named Options
cat > /etc/bind/named.conf.options << EOF
acl "trusted" {
    127.0.0.1;
    $SERVER_IP;
};
options {
    directory "/var/cache/bind";
    recursion yes;
    allow-recursion { trusted; };
    listen-on { any; };
    allow-transfer { none; };
    forwarders {
        8.8.8.8;
        1.1.1.1;
    };
    dnssec-validation auto;
};
EOF

# Local Zone Definition
cat > /etc/bind/named.conf.local << EOF
zone "$DOMAIN_NAME" {
    type master;
    file "/etc/bind/zones/db.$DOMAIN_NAME";
};
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

; Name Servers
@       IN      NS      ns1.$DOMAIN_NAME.
@       IN      NS      ns2.$DOMAIN_NAME.

; A Records
@       IN      A       $SERVER_IP
ns1     IN      A       $SERVER_IP
ns2     IN      A       $SERVER_IP
www     IN      A       $SERVER_IP
mail    IN      A       $SERVER_IP
webmail IN      A       $SERVER_IP
mysql   IN      A       $SERVER_IP

; MX Record
@       IN      MX      10 mail.$DOMAIN_NAME.
EOF

# Restart DNS
named-checkconf
systemctl restart bind9
systemctl enable bind9

# ==========================================
# MAIL SERVER (POSTFIX + DOVECOT)
# ==========================================
log "Configuring Mail Server..."

# Pre-seed Debconf
debconf-set-selections <<< "postfix postfix/mailname string $DOMAIN_NAME"
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"

# Install
apt install -y postfix dovecot-core dovecot-imapd dovecot-pop3d

# Configure Postfix
postconf -e "myhostname = mail.$DOMAIN_NAME"
postconf -e "mydestination = \$myhostname, localhost.\$mydomain, localhost, $DOMAIN_NAME"
postconf -e "home_mailbox = Maildir/"
postconf -e "inet_interfaces = all"

# Configure Dovecot (Allow plain auth for Roundcube local connection)
sed -i 's/#disable_plaintext_auth = yes/disable_plaintext_auth = no/' /etc/dovecot/conf.d/10-auth.conf
sed -i 's/auth_mechanisms = plain/auth_mechanisms = plain login/' /etc/dovecot/conf.d/10-auth.conf
sed -i 's|mail_location = .*|mail_location = maildir:~/Maildir|' /etc/dovecot/conf.d/10-mail.conf

# Restart Mail Services
systemctl restart postfix dovecot
systemctl enable postfix dovecot

# ==========================================
# NGINX CONFIGURATION
# ==========================================
log "Configuring Nginx Server Blocks..."

cat > /etc/nginx/sites-available/$DOMAIN_NAME << EOF
server {
    listen 80;
    server_name $DOMAIN_NAME www.$DOMAIN_NAME mail.$DOMAIN_NAME webmail.$DOMAIN_NAME ns1.$DOMAIN_NAME ns2.$DOMAIN_NAME;
    root /var/www/shm-panel;
    index index.php index.html;

    access_log /var/log/nginx/shm_access.log;
    error_log /var/log/nginx/shm_error.log;

    # Root Application
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

    # PHP Processing for Root
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass $PHP_SOCKET;
    }

    # Security
    location ~ /\.ht { deny all; }
    client_max_body_size 64M;
}
EOF

# Enable Site
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/$DOMAIN_NAME /etc/nginx/sites-enabled/

# Create Dashboard File
mkdir -p /var/www/shm-panel
cat > /var/www/shm-panel/index.php << EOF
<!DOCTYPE html>
<html>
<head><title>SHM Panel</title></head>
<body style="font-family: sans-serif; text-align: center; padding-top: 50px;">
    <h1>Welcome to $DOMAIN_NAME</h1>
    <p>PHP Version: $PHP_VERSION</p>
    <p>
        <a href="/webmail">Webmail</a> | 
        <a href="/phpmyadmin">phpMyAdmin</a>
    </p>
    <hr>
    <?php phpinfo(); ?>
</body>
</html>
EOF

chown -R www-data:www-data /var/www/shm-panel
chmod 755 /var/www/shm-panel

# ==========================================
# SECURITY & SSH
# ==========================================
log "Securing SSH and Firewall..."

# Create Admin User
if ! id "$ADMIN_USER" &>/dev/null; then
    useradd -m -s /bin/bash $ADMIN_USER
    echo "$ADMIN_USER:$ADMIN_PASS" | chpasswd
    usermod -aG sudo $ADMIN_USER
fi

# Configure SSH
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
sed -i "s/#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
sed -i "s/Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
sed -i "s/PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config

# Configure UFW
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow $SSH_PORT/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 53/tcp
ufw allow 53/udp
ufw allow 25,465,587/tcp
ufw allow 143,993/tcp
ufw --force enable

# ==========================================
# FINAL RESTART
# ==========================================
log "Restarting all services..."
systemctl restart nginx
systemctl restart bind9
systemctl restart php${PHP_VERSION}-fpm
systemctl restart mysql
systemctl restart postfix
systemctl restart dovecot
systemctl restart ssh

# ==========================================
# SUMMARY
# ==========================================
CRED_FILE="/root/shm-credentials.txt"
cat > $CRED_FILE << EOF
=================================================
             SHM PANEL CREDENTIALS
=================================================
Domain:        $DOMAIN_NAME
Server IP:     $SERVER_IP
PHP Version:   $PHP_VERSION (Socket: $PHP_SOCKET)

--- SYSTEM ADMIN ---
SSH Port:      $SSH_PORT
User:          $ADMIN_USER
Password:      $ADMIN_PASS
Command:       ssh -p $SSH_PORT $ADMIN_USER@$SERVER_IP

--- DATABASES ---
MySQL Root:    $MYSQL_ROOT_PASS
Webmail User:  roundcube / $ROUNDCUBE_DB_PASS

--- URLS ---
Panel:         http://$DOMAIN_NAME/
Webmail:       http://$DOMAIN_NAME/webmail
phpMyAdmin:    http://$DOMAIN_NAME/phpmyadmin

--- NEXT STEPS ---
1. Update NameServers at Registrar to: ns1.$DOMAIN_NAME, ns2.$DOMAIN_NAME
2. Wait for DNS propagation.
3. Install SSL: certbot --nginx -d $DOMAIN_NAME -d www.$DOMAIN_NAME -d mail.$DOMAIN_NAME -d webmail.$DOMAIN_NAME
=================================================
EOF

chmod 600 $CRED_FILE

clear
echo -e "${GREEN}=================================================${NC}"
echo -e "${GREEN}       INSTALLATION SUCCESSFUL                   ${NC}"
echo -e "${GREEN}=================================================${NC}"
echo "Credentials have been saved to: $CRED_FILE"
echo ""
cat $CRED_FILE
echo ""
echo -e "${YELLOW}NOTE: You may need to reconnect SSH using port $SSH_PORT${NC}"
