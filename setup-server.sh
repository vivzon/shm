#!/bin/bash

# ==============================================================================
# SHM Panel - Ultimate VPS Setup Script
# Features: LEMP + DNS + Mail (Postfix/Dovecot) + phpMyAdmin + Roundcube
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

SERVER_IP=$(hostname -I | awk '{print $1}')
HOSTNAME=$(hostname)
TIMEZONE="Asia/Kolkata"
SSH_PORT="2222"

# Generates Secure Passwords
MYSQL_ROOT_PASS=$(openssl rand -base64 32)
ADMIN_USER="shmadmin"
ADMIN_PASS=$(openssl rand -base64 16)
APP_USER="shmuser"
APP_PASS=$(openssl rand -base64 16)

# Database Credentials
DB_MAIN_NAME="shm_panel"
DB_RC_NAME="roundcubemail" # For Webmail
DB_USER="shm_db_user"
DB_PASS=$(openssl rand -base64 24)

# Blowfish Secret for phpMyAdmin
PMA_SECRET=$(openssl rand -hex 16)

log "Starting Installation on $SERVER_IP..."

# ------------------------------------------------------------------------------
# 2. System Updates & Dependencies
# ------------------------------------------------------------------------------

log "Updating system..."
export DEBIAN_FRONTEND=noninteractive
apt update && apt upgrade -y

# Pre-configure Postfix to avoid prompts
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
# 3. PHP Setup (Dynamic Version)
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
# 4. DNS Server (Bind9) Setup
# ------------------------------------------------------------------------------

log "Configuring Bind9 (DNS)..."

# Allow query from any (it's a public nameserver)
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
# 5. Mail Server (Postfix + Dovecot)
# ------------------------------------------------------------------------------

log "Configuring Postfix & Dovecot..."

# Postfix (SMTP)
postconf -e "myhostname = $HOSTNAME"
postconf -e "inet_interfaces = all"
postconf -e "inet_protocols = all"
postconf -e "home_mailbox = Maildir/"
systemctl restart postfix

# Dovecot (IMAP)
# Enable plaintext auth (needed for local simple login initially)
sed -i 's/#disable_plaintext_auth = yes/disable_plaintext_auth = no/' /etc/dovecot/conf.d/10-auth.conf
sed -i 's/mail_location = mbox:~/mail_location = maildir:~\/Maildir/' /etc/dovecot/conf.d/10-mail.conf
systemctl restart dovecot

# ------------------------------------------------------------------------------
# 6. Database Setup
# ------------------------------------------------------------------------------

log "Configuring MySQL..."
systemctl start mysql

# Secure MySQL
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

# Create Databases (Panel + Roundcube)
mysql -e "CREATE DATABASE IF NOT EXISTS $DB_MAIN_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "CREATE DATABASE IF NOT EXISTS $DB_RC_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -e "GRANT ALL PRIVILEGES ON *.* TO '$DB_USER'@'localhost' WITH GRANT OPTION;"
mysql -e "FLUSH PRIVILEGES;"

# Import Panel Schema
cat > /root/schema.sql << 'EOSQL'
SET FOREIGN_KEY_CHECKS=0;
CREATE TABLE IF NOT EXISTS `users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `username` varchar(50) NOT NULL,
  `email` varchar(100) NOT NULL,
  `password` varchar(255) NOT NULL,
  `role` enum('superadmin','admin','user') NOT NULL DEFAULT 'user',
  `plan_id` int(11) DEFAULT NULL,
  `ssh_access_enabled` tinyint(1) NOT NULL DEFAULT '0',
  `status` enum('active','inactive','suspended') NOT NULL DEFAULT 'active',
  `last_login` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), UNIQUE KEY `username` (`username`), UNIQUE KEY `email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `domains` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `domain_name` varchar(255) NOT NULL,
  `document_root` varchar(500) NOT NULL,
  `php_version` varchar(10) DEFAULT '8.4',
  `ssl_enabled` tinyint(1) DEFAULT '0',
  `expiry_date` date DEFAULT NULL,
  `status` enum('active','suspended') NOT NULL DEFAULT 'active',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), UNIQUE KEY `domain_name` (`domain_name`), KEY `user_id` (`user_id`),
  CONSTRAINT `domains_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `hosting_plans` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `disk_space_mb` int(10) UNSIGNED NOT NULL DEFAULT '1000',
  `bandwidth_gb` int(10) UNSIGNED NOT NULL DEFAULT '10',
  `max_domains` int(10) UNSIGNED NOT NULL DEFAULT '1',
  `price_monthly` decimal(10,2) NOT NULL DEFAULT '0.00',
  `is_visible` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Admin: admin / admin123
INSERT IGNORE INTO `users` (`username`, `email`, `password`, `role`, `status`) VALUES 
('admin', 'admin@localhost', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'superadmin', 'active');
INSERT IGNORE INTO `hosting_plans` (`name`, `disk_space_mb`) VALUES ('Basic', 1000);
SET FOREIGN_KEY_CHECKS=1;
EOSQL

mysql $DB_MAIN_NAME < /root/schema.sql
rm /root/schema.sql

# ------------------------------------------------------------------------------
# 7. Install phpMyAdmin
# ------------------------------------------------------------------------------

log "Installing phpMyAdmin..."
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
\$cfg['UploadDir'] = '';
\$cfg['SaveDir'] = '';
?>
EOF

chown -R www-data:www-data /var/www/html/phpmyadmin

# ------------------------------------------------------------------------------
# 8. Install Roundcube (Webmail)
# ------------------------------------------------------------------------------

log "Installing Roundcube..."
mkdir -p /var/www/html/webmail
cd /tmp
wget https://github.com/roundcube/roundcubemail/releases/download/1.6.6/roundcubemail-1.6.6-complete.tar.gz
tar -xzf roundcubemail-1.6.6-complete.tar.gz
cp -r roundcubemail-1.6.6/* /var/www/html/webmail/
rm -rf roundcubemail*

# Configure Roundcube
cd /var/www/html/webmail
# Import initial DB schema
mysql $DB_RC_NAME < SQL/mysql.initial.sql

# Write config
cat > config/config.inc.php << EOF
<?php
\$config['db_dsnw'] = 'mysql://$DB_USER:$DB_PASS@localhost/$DB_RC_NAME';
\$config['default_host'] = 'localhost';
\$config['smtp_server'] = 'localhost';
\$config['smtp_port'] = 25;
\$config['smtp_user'] = '%u';
\$config['smtp_pass'] = '%p';
\$config['support_url'] = '';
\$config['product_name'] = 'SHM Webmail';
\$config['des_key'] = '$(openssl rand -hex 12)';
\$config['plugins'] = ['archive', 'zipdownload'];
?>
EOF

chown -R www-data:www-data /var/www/html/webmail

# ------------------------------------------------------------------------------
# 9. Nginx Configuration
# ------------------------------------------------------------------------------

log "Configuring Nginx..."

cat > /etc/nginx/sites-available/shm-panel << EOF
server {
    listen 80;
    server_name _;
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

    # --- Webmail (Roundcube) ---
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

    # --- PHP Handling for Panel ---
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:$PHP_SOCK;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\. { deny all; }
}
EOF

ln -sf /etc/nginx/sites-available/shm-panel /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Setup Main Panel Directory
mkdir -p /var/www/shm-panel
echo "<?php echo '<h1>SHM Panel Installed</h1>'; ?>" > /var/www/shm-panel/index.php
chown -R www-data:www-data /var/www/shm-panel

# ------------------------------------------------------------------------------
# 10. Security & Users
# ------------------------------------------------------------------------------

log "Finalizing Security..."

# Add System Users
if ! id "$ADMIN_USER" &>/dev/null; then
    useradd -m -s /bin/bash $ADMIN_USER
    echo "$ADMIN_USER:$ADMIN_PASS" | chpasswd
    usermod -aG sudo $ADMIN_USER
fi

# Configure SSH
sed -i "s/#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
sed -i "s/PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config
echo "AllowUsers $ADMIN_USER" >> /etc/ssh/sshd_config

# Configure Firewall (Open DNS and Mail ports)
ufw default deny incoming
ufw default allow outgoing
ufw allow $SSH_PORT/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 53  # DNS
ufw allow 25  # SMTP
ufw allow 143 # IMAP
ufw allow 587 # Submission
ufw --force enable

# Save Credentials
cat > /root/server_credentials.txt << EOF
=== SHM Panel Credentials ===
Server IP: $SERVER_IP
SSH Port:  $SSH_PORT

[Login]
SSH User:  $ADMIN_USER
SSH Pass:  $ADMIN_PASS

[Services]
phpMyAdmin: http://$SERVER_IP/phpmyadmin
Webmail:    http://$SERVER_IP/webmail
Main Panel: http://$SERVER_IP

[Database]
Root Pass: $MYSQL_ROOT_PASS
DB User:   $DB_USER
DB Pass:   $DB_PASS

[Defaults]
Panel Admin: admin / admin123
EOF
chmod 600 /root/server_credentials.txt

# Restart all services
systemctl daemon-reload
systemctl restart mysql bind9 postfix dovecot nginx $PHP_SERVICE fail2ban ssh

log "Setup Complete!"
echo "-----------------------------------------------------"
echo " Credentials saved to: /root/server_credentials.txt"
echo " Access Webmail:       http://$SERVER_IP/webmail"
echo " Access phpMyAdmin:    http://$SERVER_IP/phpmyadmin"
echo " SSH Command:          ssh -p $SSH_PORT $ADMIN_USER@$SERVER_IP"
echo "-----------------------------------------------------"
