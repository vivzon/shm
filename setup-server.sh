#!/bin/bash

# ==============================================================================
# SHM Panel - Ultimate VPS Setup Script (Updated)
# ==============================================================================
# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
log() { echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; }
warning() { echo -e "${YELLOW}[WARNING] $1${NC}"; }

if [ "$EUID" -ne 0 ]; then error "Please run as root"; exit 1; fi

# ------------------------------------------------------------------------------
# 1. Configuration & Credentials
# ------------------------------------------------------------------------------
# Prompt for the main domain
read -p "Enter the main domain for your panel (e.g., server.sellvell.com): " MAIN_DOMAIN

# If the domain is not provided, use a default
if [ -z "$MAIN_DOMAIN" ]; then
    MAIN_DOMAIN="server.sellvell.com"
    warning "No domain entered. Using default domain: $MAIN_DOMAIN"
fi

SERVER_IP=$(hostname -I | awk '{print $1}')
HOSTNAME=$MAIN_DOMAIN  # Using the provided domain as the hostname
TIMEZONE="Asia/Kolkata"
SSH_PORT="2222"

# Generates Secure Passwords
MYSQL_ROOT_PASS=$(openssl rand -base64 32)
ADMIN_USER="shmadmin"
ADMIN_PASS=$(openssl rand -base64 16)

# Database Credentials
DB_MAIN_NAME="shm_panel"
DB_RC_NAME="roundcubemail"
DB_USER="shm_db_user"
DB_PASS=$(openssl rand -base64 24)

# Blowfish Secret for phpMyAdmin
PMA_SECRET=$(openssl rand -hex 16)

log "Starting Installation on $SERVER_IP ($HOSTNAME)..."

# ------------------------------------------------------------------------------
# 2. System Updates & Dependencies
# ------------------------------------------------------------------------------

log "Updating system..."
export DEBIAN_FRONTEND=noninteractive
apt update && apt upgrade -y

# Pre-configure Postfix
echo "postfix postfix/main_mailer_type string 'Internet Site'" | debconf-set-selections
echo "postfix postfix/mailname string $HOSTNAME" | debconf-set-selections

log "Installing packages..."
apt install -y \
    curl wget git unzip htop acl zip \
    nginx mysql-server \
    ufw fail2ban \
    bind9 bind9utils bind9-doc \
    postfix dovecot-core dovecot-imapd dovecot-pop3d \
    software-properties-common

timedatectl set-timezone $TIMEZONE

# ------------------------------------------------------------------------------
# 3. PHP Setup
# ------------------------------------------------------------------------------

log "Installing PHP..."
apt install -y php-fpm php-mysql php-curl php-gd php-mbstring \
    php-xml php-zip php-bcmath php-json php-intl php-soap php-ldap php-imagick

# Detect Version
PHP_VERSION=$(php -v | head -n 1 | cut -d " " -f 2 | cut -d "." -f 1,2)
PHP_SOCK="/var/run/php/php$PHP_VERSION-fpm.sock"
log "PHP $PHP_VERSION detected."

# PHP Config
cat > /etc/php/$PHP_VERSION/fpm/conf.d/99-custom.ini << EOF
upload_max_filesize = 1024M
post_max_size = 1024M
memory_limit = 512M
max_execution_time = 300
date.timezone = "$TIMEZONE"
EOF

# ------------------------------------------------------------------------------
# 4. DNS Server (Bind9)
# ------------------------------------------------------------------------------

log "Configuring Bind9 (DNS)..."

cat > /etc/bind/named.conf.options << EOF
options {
    directory "/var/cache/bind";
    recursion yes;
    allow-query { any; };
    dnssec-validation auto;
    listen-on-v6 { any; };
};
EOF

systemctl restart bind9
systemctl enable bind9

# ------------------------------------------------------------------------------
# 5. Mail Server
# ------------------------------------------------------------------------------

log "Configuring Postfix & Dovecot..."

postconf -e "myhostname = $HOSTNAME"
postconf -e "inet_interfaces = all"
postconf -e "inet_protocols = all"
postconf -e "home_mailbox = Maildir/"
systemctl restart postfix

sed -i 's/#disable_plaintext_auth = yes/disable_plaintext_auth = no/' /etc/dovecot/conf.d/10-auth.conf
sed -i 's/mail_location = mbox:~/mail_location = maildir:~\/Maildir/' /etc/dovecot/conf.d/10-mail.conf
systemctl restart dovecot

# ------------------------------------------------------------------------------
# 6. Database Setup (Updated Schema)
# ------------------------------------------------------------------------------

log "Configuring MySQL..."
systemctl start mysql

# Secure MySQL & Create Users
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASS';"
mysql -e "DELETE FROM mysql.user WHERE User='';"
mysql -e "DROP DATABASE IF EXISTS test;"
mysql -e "FLUSH PRIVILEGES;"

# Create .my.cnf
cat > /root/.my.cnf << EOF
[client]
user=root
password=$MYSQL_ROOT_PASS
EOF
chmod 600 /root/.my.cnf

# Create Databases
mysql -e "CREATE DATABASE IF NOT EXISTS $DB_MAIN_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "CREATE DATABASE IF NOT EXISTS $DB_RC_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -e "GRANT ALL PRIVILEGES ON *.* TO '$DB_USER'@'localhost' WITH GRANT OPTION;"
mysql -e "FLUSH PRIVILEGES;"

# ------------------------------------------------------------------------------
# 7. Install phpMyAdmin & Roundcube
# ------------------------------------------------------------------------------
log "Installing Web Apps..."

# --- phpMyAdmin ---
mkdir -p /var/www/html/phpmyadmin
cd /tmp
wget https://files.phpmyadmin.net/phpMyAdmin/5.2.1/phpMyAdmin-5.2.1-all-languages.zip
unzip -q phpMyAdmin-5.2.1-all-languages.zip
cp -r phpMyAdmin-5.2.1-all-languages/* /var/www/html/phpmyadmin/
rm -rf phpMyAdmin-5.2.1*

# Configure PMA
cat > /var/www/html/phpmyadmin/config.inc.php << EOF
<?php
\$cfg['blowfish_secret'] = '$PMA_SECRET';
\$i = 0;
\$i++;
\$cfg['Servers'][\$i]['auth_type'] = 'cookie';
\$cfg['Servers'][\$i]['host'] = 'localhost';
\$cfg['Servers'][\$i]['compress'] = false;
\$cfg['Servers'][\$i]['AllowNoPassword'] = false;
?>
EOF

# --- Roundcube ---
mkdir -p /var/www/html/webmail
cd /tmp
wget https://github.com/roundcube/roundcubemail/releases/download/1.6.6/roundcubemail-1.6.6-complete.tar.gz
tar -xzf roundcubemail-1.6.6-complete.tar.gz
cp -r roundcubemail-1.6.6/* /var/www/html/webmail/
rm -rf roundcubemail*

cd /var/www/html/webmail
mysql $DB_RC_NAME < SQL/mysql.initial.sql
cat > config/config.inc.php << EOF
<?php
\$config['db_dsnw'] = 'mysql://$DB_USER:$DB_PASS@localhost/$DB_RC_NAME';
\$config['default_host'] = 'localhost';
\$config['smtp_server'] = 'localhost';
\$config['smtp_port'] = 25;
\$config['smtp_user'] = '%u';
\$config['smtp_pass'] = '%p';
\$config['product_name'] = 'SHM Webmail';
\$config['des_key'] = '$(openssl rand -hex 12)';
\$config['plugins'] = ['archive', 'zipdownload'];
?>
EOF

chown -R www-data:www-data /var/www/html

# ------------------------------------------------------------------------------
# 9. Nginx Configuration (Main Domain)
# ------------------------------------------------------------------------------
log "Configuring Nginx for $MAIN_DOMAIN..."

# Main Panel Config (Specific Hostname)
cat > /etc/nginx/sites-available/$MAIN_DOMAIN << EOF
server {
    listen 80;
    server_name $MAIN_DOMAIN;
    root /var/www/shm-panel;
    index index.php index.html;

    # --- Main Panel ---
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    # --- phpMyAdmin ---
    location /phpmyadmin {
        root /var/www/html;
        index index.php;
        try_files \$uri \$uri/ =404;
        location ~ ^/phpmyadmin/(.+\.php)$ {
            root /var/www/html;
            include snippets/fastcgi-php.conf;
            fastcgi_pass unix:$PHP_SOCK;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        }
    }

    # --- Webmail ---
    location /webmail {
        root /var/www/html;
        index index.php;
        try_files \$uri \$uri/ =404;
        location ~ ^/webmail/(.+\.php)$ {
            root /var/www/html;
            include snippets/fastcgi-php.conf;
            fastcgi_pass unix:$PHP_SOCK;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        }
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:$PHP_SOCK;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    location ~ /\. { deny all; }
}
EOF

# Enable Site & Disable Default
ln -sf /etc/nginx/sites-available/$MAIN_DOMAIN /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Setup Main Panel Directory
mkdir -p /var/www/shm-panel
# Place a placeholder index.php
echo "<?php header('Location: /login'); ?>" > /var/www/shm-panel/index.php
chown -R www-data:www-data /var/www/shm-panel

# ------------------------------------------------------------------------------
# 10. Security & Finalize
# ------------------------------------------------------------------------------
log "Finalizing..."

# Add Admin User (System Level)
if ! id "$ADMIN_USER" &>/dev/null; then
    useradd -m -s /bin/bash $ADMIN_USER
    echo "$ADMIN_USER:$ADMIN_PASS" | chpasswd
    usermod -aG sudo $ADMIN_USER
fi

# SSH Config
sed -i "s/#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
echo "AllowUsers $ADMIN_USER root" >> /etc/ssh/sshd_config

# Firewall
ufw default deny incoming
ufw default allow outgoing
ufw allow $SSH_PORT/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 53
ufw allow 25
ufw allow 143
ufw allow 587
ufw --force enable

# Save Info
cat > /root/server_credentials.txt << EOF
=== SHM Panel Credentials ===
Hostname:  $HOSTNAME
Server IP: $SERVER_IP
SSH Port:  $SSH_PORT

[Services]
Panel URL:  http://$MAIN_DOMAIN
phpMyAdmin: http://$MAIN_DOMAIN/phpmyadmin
Webmail:    http://$MAIN_DOMAIN/webmail

[Database]
Root Pass: $MYSQL_ROOT_PASS
DB User:   $DB_USER
DB Pass:   $DB_PASS

[Panel Login]
User: admin
Pass: password
EOF
chmod 600 /root/server_credentials.txt

# Restart Services
systemctl daemon-reload
systemctl restart mysql bind9 postfix dovecot nginx ssh

log "Setup Complete!"
echo "-----------------------------------------------------"
echo " Credentials: /root/server_credentials.txt"
echo " Panel URL:   http://$MAIN_DOMAIN"
echo " SSH Command: ssh -p $SSH_PORT $ADMIN_USER@$SERVER_IP"
echo "-----------------------------------------------------"
