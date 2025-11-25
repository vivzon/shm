#!/bin/bash

# ==========================================
# SHM Panel Setup Script (Auto PHP Detect)
# ==========================================

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

# ==========================================
# INPUT REQUIRED
# ==========================================
clear
echo -e "${YELLOW}==============================================${NC}"
echo -e "${YELLOW}   SHM Panel + DNS + Webmail + phpMyAdmin     ${NC}"
echo -e "${YELLOW}   Auto-detects or Installs PHP               ${NC}"
echo -e "${YELLOW}==============================================${NC}"
echo ""
read -p "Enter your Domain Name (e.g., example.com): " DOMAIN_NAME

if [ -z "$DOMAIN_NAME" ]; then
    error "Domain name is required."
    exit 1
fi

# ==========================================
# SYSTEM CONFIGURATION
# ==========================================

# Get Public IP (Better than hostname -I for DNS)
SERVER_IP=$(curl -s ifconfig.me)
if [ -z "$SERVER_IP" ]; then
    SERVER_IP=$(hostname -I | awk '{print $1}')
fi

TIMEZONE="Asia/Kolkata"
ADMIN_USER="shmadmin"
SSH_PORT="2222"
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)
APP_USER="shmuser"
APP_USER_PASSWORD=$(openssl rand -base64 16)
PMA_BLOWFISH=$(openssl rand -base64 32)
ROUNDCUBE_DB_PASS=$(openssl rand -base64 24)
MAIL_USER_PASS=$(openssl rand -base64 16)

log "Starting Setup for $DOMAIN_NAME on IP $SERVER_IP"

# Update system
log "Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt update && apt upgrade -y
apt install -y software-properties-common curl wget git unzip htop gnupg2 lsb-release ufw fail2ban

# Enable Universe repo (needed for some packages)
add-apt-repository universe -y
apt update

# ==========================================
# PHP LOGIC (CHECK OR INSTALL)
# ==========================================
log "Checking PHP Configuration..."

PHP_VERSION=""

if command -v php &> /dev/null; then
    # PHP is installed, detect version
    PHP_VERSION=$(php -v | head -n 1 | cut -d " " -f 2 | cut -d "." -f 1,2)
    info "PHP $PHP_VERSION is already installed. Proceeding with this version."
else
    # PHP is not installed, install default
    warning "PHP not found. Installing latest default version..."
    apt install -y php-fpm php-cli
    PHP_VERSION=$(php -v | head -n 1 | cut -d " " -f 2 | cut -d "." -f 1,2)
    info "Installed PHP $PHP_VERSION."
fi

# Define PHP Package names based on version
PHP_PACKAGES="php${PHP_VERSION}-fpm php${PHP_VERSION}-mysql php${PHP_VERSION}-curl php${PHP_VERSION}-gd php${PHP_VERSION}-mbstring php${PHP_VERSION}-xml php${PHP_VERSION}-zip php${PHP_VERSION}-bcmath php${PHP_VERSION}-intl php${PHP_VERSION}-soap php${PHP_VERSION}-ldap php${PHP_VERSION}-imagick"

log "Installing PHP extensions for PHP $PHP_VERSION..."
apt install -y $PHP_PACKAGES

# ==========================================
# INSTALL CORE SERVICES
# ==========================================
log "Installing Nginx, MySQL, Bind9, Certbot..."
apt install -y \
    nginx mysql-server \
    bind9 bind9utils bind9-doc dnsutils \
    certbot python3-certbot-nginx

# Set timezone
timedatectl set-timezone $TIMEZONE

# ==========================================
# USER MANAGEMENT
# ==========================================
log "Configuring Users..."

# Create application user
if ! id "$APP_USER" &>/dev/null; then
    useradd -m -s /bin/bash $APP_USER
    echo "$APP_USER:$APP_USER_PASSWORD" | chpasswd
    usermod -aG sudo $APP_USER
fi

# Create admin user
if ! id "$ADMIN_USER" &>/dev/null; then
    useradd -m -s /bin/bash $ADMIN_USER
    ADMIN_PASSWORD=$(openssl rand -base64 16)
    echo "$ADMIN_USER:$ADMIN_PASSWORD" | chpasswd
    usermod -aG sudo $ADMIN_USER
    
    # Save credentials
    CRED_FILE="/root/server_credentials.txt"
    echo "=== Server Credentials ===" > $CRED_FILE
    echo "Domain: $DOMAIN_NAME" >> $CRED_FILE
    echo "Admin User: $ADMIN_USER" >> $CRED_FILE
    echo "Admin Password: $ADMIN_PASSWORD" >> $CRED_FILE
    echo "App User: $APP_USER" >> $CRED_FILE
    echo "App Password: $APP_USER_PASSWORD" >> $CRED_FILE
    echo "MySQL Root Password: $MYSQL_ROOT_PASSWORD" >> $CRED_FILE
    echo "Roundcube DB Password: $ROUNDCUBE_DB_PASS" >> $CRED_FILE
    echo "Mail User ($ADMIN_USER@$DOMAIN_NAME): $MAIL_USER_PASS" >> $CRED_FILE
    chmod 600 $CRED_FILE
fi

# ==========================================
# FIREWALL
# ==========================================
log "Configuring firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow $SSH_PORT/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 53/tcp
ufw allow 53/udp
ufw allow 25/tcp
ufw allow 465/tcp
ufw allow 587/tcp
ufw allow 143/tcp
ufw allow 993/tcp
ufw --force enable

# ==========================================
# SSH SECURITY
# ==========================================
log "Configuring SSH on Port $SSH_PORT..."
# Backup original config
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%F)

# Write new config
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

# ==========================================
# MYSQL SETUP
# ==========================================
log "Configuring MySQL..."
systemctl enable mysql
systemctl start mysql

# Secure MySQL
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD';"
mysql -e "DELETE FROM mysql.user WHERE User='';"
mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
mysql -e "DROP DATABASE IF EXISTS test;"
mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
mysql -e "FLUSH PRIVILEGES;"

# Create .my.cnf for root
cat > /root/.my.cnf << EOF
[client]
user=root
password=$MYSQL_ROOT_PASSWORD
EOF
chmod 600 /root/.my.cnf

# ==========================================
# DNS SERVER (BIND9)
# ==========================================
log "Configuring DNS (Bind9)..."

# Configure Options
cat > /etc/bind/named.conf.options << EOF
acl "trusted" {
    127.0.0.1;    # localhost
    $SERVER_IP;   # local server
};

options {
    directory "/var/cache/bind";
    recursion yes;
    allow-recursion { trusted; };
    listen-on { any; };
    allow-transfer { none; };
    forwarders {
        8.8.8.8;
        8.8.4.4;
    };
    dnssec-validation auto;
};
EOF

# Configure Zones
cat > /etc/bind/named.conf.local << EOF
zone "$DOMAIN_NAME" {
    type master;
    file "/etc/bind/zones/db.$DOMAIN_NAME";
};
EOF

mkdir -p /etc/bind/zones

# Create Zone File
SERIAL=$(date +%Y%m%d01)
cat > /etc/bind/zones/db.$DOMAIN_NAME << EOF
\$TTL    604800
@       IN      SOA     ns1.$DOMAIN_NAME. admin.$DOMAIN_NAME. (
                  $SERIAL     ; Serial
             604800     ; Refresh
              86400     ; Retry
            2419200     ; Expire
             604800 )   ; Negative Cache TTL
;
; Name servers
@       IN      NS      ns1.$DOMAIN_NAME.
@       IN      NS      ns2.$DOMAIN_NAME.

; A records
@       IN      A       $SERVER_IP
ns1     IN      A       $SERVER_IP
ns2     IN      A       $SERVER_IP
www     IN      A       $SERVER_IP
mail    IN      A       $SERVER_IP
webmail IN      A       $SERVER_IP
mysql   IN      A       $SERVER_IP

; MX record
@       IN      MX      10 mail.$DOMAIN_NAME.
EOF

named-checkconf
systemctl restart bind9
systemctl enable bind9

# ==========================================
# EMAIL STACK (Postfix + Dovecot)
# ==========================================
log "Installing Mail Stack..."

debconf-set-selections <<< "postfix postfix/mailname string $DOMAIN_NAME"
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"

apt install -y postfix dovecot-core dovecot-imapd dovecot-pop3d

# Configure Postfix
postconf -e "myhostname = mail.$DOMAIN_NAME"
postconf -e "mydestination = \$myhostname, localhost.\$mydomain, localhost, $DOMAIN_NAME"
postconf -e "home_mailbox = Maildir/"
postconf -e "inet_interfaces = all"

# Configure Dovecot
sed -i 's/#disable_plaintext_auth = yes/disable_plaintext_auth = no/' /etc/dovecot/conf.d/10-auth.conf
sed -i 's/auth_mechanisms = plain/auth_mechanisms = plain login/' /etc/dovecot/conf.d/10-auth.conf
sed -i 's/mail_location = mbox:~\/mail:INBOX=\/var\/mail\/%u/mail_location = maildir:~\/Maildir/' /etc/dovecot/conf.d/10-mail.conf

systemctl restart postfix dovecot
systemctl enable postfix dovecot

# ==========================================
# PHPMYADMIN (Manual Install)
# ==========================================
log "Installing phpMyAdmin..."

PMA_VERSION="5.2.1"
cd /tmp
rm -f phpMyAdmin-*-all-languages.zip
wget -q https://files.phpmyadmin.net/phpMyAdmin/${PMA_VERSION}/phpMyAdmin-${PMA_VERSION}-all-languages.zip
unzip -q phpMyAdmin-${PMA_VERSION}-all-languages.zip
rm -rf /var/www/phpmyadmin
mv phpMyAdmin-${PMA_VERSION}-all-languages /var/www/phpmyadmin
rm phpMyAdmin-${PMA_VERSION}-all-languages.zip

# Create Config
cp /var/www/phpmyadmin/config.sample.inc.php /var/www/phpmyadmin/config.inc.php
sed -i "s/\$cfg\['blowfish_secret'\] = '';/\$cfg\['blowfish_secret'\] = '$PMA_BLOWFISH';/" /var/www/phpmyadmin/config.inc.php

mkdir -p /var/www/phpmyadmin/tmp
chown -R www-data:www-data /var/www/phpmyadmin

# ==========================================
# WEBMAIL (Roundcube)
# ==========================================
log "Installing Roundcube Webmail..."

# Install Roundcube via apt (easier dependency management)
apt install -y roundcube roundcube-mysql php-net-smtp php-mail-mime

# Configure Database for Roundcube
mysql -e "DROP DATABASE IF EXISTS roundcubemail;"
mysql -e "CREATE DATABASE roundcubemail DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;"
mysql -e "CREATE USER IF NOT EXISTS 'roundcube'@'localhost' IDENTIFIED BY '$ROUNDCUBE_DB_PASS';"
mysql -e "GRANT ALL PRIVILEGES ON roundcubemail.* TO 'roundcube'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# Import initial SQL
if [ -f "/usr/share/roundcube/SQL/mysql.initial.sql.gz" ]; then
    zcat /usr/share/roundcube/SQL/mysql.initial.sql.gz | mysql -u roundcube -p$ROUNDCUBE_DB_PASS roundcubemail
elif [ -f "/usr/share/roundcube/SQL/mysql.initial.sql" ]; then
    mysql -u roundcube -p$ROUNDCUBE_DB_PASS roundcubemail < /usr/share/roundcube/SQL/mysql.initial.sql
fi

# Configure Roundcube
mkdir -p /etc/roundcube
cat > /etc/roundcube/config.inc.php << EOF
<?php
\$config['db_dsnw'] = 'mysql://roundcube:$ROUNDCUBE_DB_PASS@localhost/roundcubemail';
\$config['default_host'] = 'localhost';
\$config['smtp_server'] = 'localhost';
\$config['smtp_port'] = 25;
\$config['smtp_user'] = '%u';
\$config['smtp_pass'] = '%p';
\$config['support_url'] = '';
\$config['product_name'] = 'SHM Webmail';
\$config['des_key'] = '$(openssl rand -base64 24)';
\$config['plugins'] = array('archive', 'zipdownload');
\$config['skin'] = 'elastic';
EOF

ln -sf /usr/share/roundcube /var/www/webmail

# ==========================================
# NGINX CONFIGURATION
# ==========================================
log "Configuring Nginx..."

# Determine PHP Socket based on detected version
PHP_SOCKET="unix:/run/php/php${PHP_VERSION}-fpm.sock"
info "Configuring Nginx to use: $PHP_SOCKET"

cat > /etc/nginx/sites-available/$DOMAIN_NAME << EOF
server {
    listen 80;
    server_name $DOMAIN_NAME www.$DOMAIN_NAME mail.$DOMAIN_NAME webmail.$DOMAIN_NAME ns1.$DOMAIN_NAME ns2.$DOMAIN_NAME;
    root /var/www/shm-panel;
    index index.php index.html;

    # Main Panel
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

    # Webmail (Roundcube)
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

    # PHP Processing
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass $PHP_SOCKET;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    # Security & Caching
    location ~ /\. { deny all; }
    location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ { expires 30d; }
    client_max_body_size 100M;
}
EOF

# Enable site
rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-enabled/$DOMAIN_NAME
ln -sf /etc/nginx/sites-available/$DOMAIN_NAME /etc/nginx/sites-enabled/

# Create Directories & Permissions
mkdir -p /var/www/shm-panel
echo "<?php phpinfo(); ?>" > /var/www/shm-panel/phpinfo.php
chown -R $APP_USER:www-data /var/www/shm-panel
chown -R www-data:www-data /var/www/webmail
chmod 755 /var/www/shm-panel

# ==========================================
# FINALIZE & RESTART
# ==========================================
log "Restarting Services..."
systemctl daemon-reload
systemctl restart bind9
systemctl restart mysql
systemctl restart php${PHP_VERSION}-fpm
systemctl restart nginx
systemctl restart postfix
systemctl restart dovecot
systemctl restart fail2ban
systemctl restart ssh

# Create System Info Script
cat > /root/system-info.sh << EOF
#!/bin/bash
echo "=== System Status ==="
echo "Uptime: \$(uptime -p)"
echo "Mem: \$(free -h | grep Mem | awk '{print \$3 \"/\" \$2}')"
echo "PHP Version: \$(php -v | head -n 1)"
echo ""
echo "=== Services ==="
echo "Nginx: \$(systemctl is-active nginx)"
echo "MySQL: \$(systemctl is-active mysql)"
echo "PHP-FPM: \$(systemctl is-active php${PHP_VERSION}-fpm)"
echo "Bind9: \$(systemctl is-active bind9)"
EOF
chmod +x /root/system-info.sh

log "Setup Completed Successfully!"
echo ""
echo -e "${YELLOW}==============================================${NC}"
echo -e "${GREEN}       INSTALLATION COMPLETE FOR $DOMAIN_NAME ${NC}"
echo -e "${YELLOW}==============================================${NC}"
echo ""
echo "1. CREDENTIALS (Saved in /root/server_credentials.txt):"
echo "   - Admin User: $ADMIN_USER"
echo "   - SSH Port: $SSH_PORT (Reconnect using: ssh -p $SSH_PORT $ADMIN_USER@$SERVER_IP)"
echo ""
echo "2. PHP CONFIGURATION:"
echo "   - Detected/Installed Version: $PHP_VERSION"
echo "   - FPM Socket: $PHP_SOCKET"
echo ""
echo "3. ACCESS URLS:"
echo "   - Panel:     http://$DOMAIN_NAME/"
echo "   - phpMyAdmin: http://$DOMAIN_NAME/phpmyadmin"
echo "   - Webmail:   http://$DOMAIN_NAME/webmail"
echo ""
echo "4. DNS SETUP (Go to your domain registrar):"
echo "   - Create Child NameServers (Glue Records):"
echo "     ns1.$DOMAIN_NAME -> $SERVER_IP"
echo "     ns2.$DOMAIN_NAME -> $SERVER_IP"
echo "   - Change Nameservers to ns1.$DOMAIN_NAME and ns2.$DOMAIN_NAME"
echo ""
echo "5. SSL CERTIFICATE:"
echo "   Run this command after DNS propagates:"
echo "   certbot --nginx -d $DOMAIN_NAME -d www.$DOMAIN_NAME -d mail.$DOMAIN_NAME -d webmail.$DOMAIN_NAME"
echo ""
