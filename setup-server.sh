#!/bin/bash

# ==========================================
# SHM Panel Setup Script (Auto PHP Detect / Install PHP 8.4)
# Improved phpMyAdmin & Roundcube handling + robust PHP detection
# ==========================================

set -euo pipefail
IFS=$'\n\t'

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}" >&2
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Check root
if [ "$EUID" -ne 0 ]; then
    error "Please run as root"
    exit 1
fi

# ==========================================
# INPUT
# ==========================================
clear
echo -e "${YELLOW}==============================================${NC}"
echo -e "${YELLOW}   SHM Panel + DNS + Webmail + phpMyAdmin     ${NC}"
echo -e "${YELLOW}   Auto-detects or Installs PHP (prefers 8.4) ${NC}"
echo -e "${YELLOW}==============================================${NC}"
echo ""
read -p "Enter your Domain Name (e.g., example.com): " DOMAIN_NAME

if [ -z "${DOMAIN_NAME:-}" ]; then
    error "Domain name is required."
    exit 1
fi

# ==========================================
# SYSTEM CONFIG
# ==========================================

# Get public IP
SERVER_IP=""
if command -v curl &>/dev/null; then
    SERVER_IP=$(curl -s ifconfig.me || true)
fi
if [ -z "$SERVER_IP" ]; then
    SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || true)
fi
if [ -z "$SERVER_IP" ]; then
    warning "Unable to determine server public IP. You may need to set DNS records manually."
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

log "Starting Setup for $DOMAIN_NAME on IP ${SERVER_IP:-UNSET}"

export DEBIAN_FRONTEND=noninteractive

# Update packages
log "Updating system packages..."
apt update && apt upgrade -y
apt install -y software-properties-common curl wget git unzip htop gnupg2 lsb-release ufw fail2ban ca-certificates openssl

# Add Ondrej PPA for PHP versions (gives access to 8.4 if available)
log "Adding PHP (ondrej) PPA to get latest PHP packages if needed..."
if ! grep -Rq "ondrej" /etc/apt/sources.list.d 2>/dev/null; then
    add-apt-repository ppa:ondrej/php -y || warning "Could not add ondrej/php PPA. Continuing with distro PHP packages."
    apt update || true
fi

# ==========================================
# PHP DETECTION / INSTALL (Prefer 8.4)
# ==========================================
log "Checking PHP configuration and availability..."

# Helper: parse major.minor from php -v
parse_php_ver() {
    php -v 2>/dev/null | head -n1 | awk '{print $2}' | cut -d'.' -f1,2 || true
}

TARGET_PHP="8.4"
PHP_VERSION=""

if command -v php &>/dev/null; then
    PHP_VERSION=$(parse_php_ver)
    if [ -z "$PHP_VERSION" ]; then
        warning "php binary exists but version could not be parsed. Will attempt to install PHP $TARGET_PHP."
        PHP_VERSION="$TARGET_PHP"
    else
        info "Detected PHP version: $PHP_VERSION"
    fi
fi

# If PHP not installed or older than 8.4, attempt to install 8.4 packages
install_php_84() {
    info "Attempting to install PHP $TARGET_PHP and common extensions..."
    apt update
    # Choose packages with explicit version suffix where available
    PHP_PACK_BASE=(php${TARGET_PHP} php${TARGET_PHP}-fpm php${TARGET_PHP}-cli php${TARGET_PHP}-mysql php${TARGET_PHP}-curl php${TARGET_PHP}-gd php${TARGET_PHP}-mbstring php${TARGET_PHP}-xml php${TARGET_PHP}-zip php${TARGET_PHP}-bcmath php${TARGET_PHP}-intl php${TARGET_PHP}-soap php${TARGET_PHP}-ldap php-imagick)

    # Some systems won't have php8.4 packages; fall back to meta "php" if needed.
    if apt-cache show "${PHP_PACK_BASE[0]}" >/dev/null 2>&1; then
        apt install -y "${PHP_PACK_BASE[@]}"
    else
        warning "PHP $TARGET_PHP packages not available via APT on this OS. Installing default php packages instead."
        apt install -y php-fpm php-cli php-mysql php-curl php-gd php-mbstring php-xml php-zip php-bcmath php-intl php-soap php-ldap php-imagick
    fi
}

# Decide
if [ -z "$PHP_VERSION" ]; then
    log "PHP not found. Installing PHP $TARGET_PHP (or distro default if not available)..."
    install_php_84
    PHP_VERSION=$(parse_php_ver || echo "$TARGET_PHP")
    info "Installed/Using PHP $PHP_VERSION"
else
    # compare versions (major.minor)
    ver_compare() {
        # returns 0 if $1 >= $2
        awk -v a="$1" -v b="$2" 'BEGIN{split(a,A,\".\");split(b,B,\".\");if((A[1]>B[1])||(A[1]==B[1] && A[2]>=B[2])) exit 0; exit 1}'
    }

    if ver_compare "$PHP_VERSION" "$TARGET_PHP"; then
        info "Detected PHP ($PHP_VERSION) is >= $TARGET_PHP. Will use it."
    else
        warning "Detected PHP ($PHP_VERSION) is older than $TARGET_PHP. Installing/adding PHP $TARGET_PHP alongside..."
        install_php_84
        PHP_VERSION=$(parse_php_ver || echo "$TARGET_PHP")
        info "Installed/Using PHP $PHP_VERSION"
    fi
fi

# Normalize to major.minor for package names
PHP_VERSION_SHORT=$(echo "$PHP_VERSION" | cut -d'.' -f1,2)
PHP_FPM_SOCK="unix:/run/php/php${PHP_VERSION_SHORT}-fpm.sock"
info "Final PHP version selected: $PHP_VERSION_SHORT"
info "PHP-FPM socket: $PHP_FPM_SOCK"

# Ensure php-fpm service exists and started
if systemctl list-units --full -all | grep -Fq "php${PHP_VERSION_SHORT}-fpm.service"; then
    systemctl enable --now "php${PHP_VERSION_SHORT}-fpm" || true
else
    warning "php${PHP_VERSION_SHORT}-fpm service not found. Trying to enable generic php-fpm..."
    systemctl enable --now php*-fpm || true
fi

# ==========================================
# INSTALL CORE SERVICES
# ==========================================
log "Installing Nginx, MySQL (mariadb-server if present), Bind9, Certbot..."
apt install -y nginx mysql-server bind9 bind9utils bind9-doc dnsutils certbot python3-certbot-nginx

# Set timezone
timedatectl set-timezone $TIMEZONE || true

# ==========================================
# USER MANAGEMENT
# ==========================================
log "Configuring Users..."

if ! id "$APP_USER" &>/dev/null; then
    useradd -m -s /bin/bash $APP_USER
    echo "$APP_USER:$APP_USER_PASSWORD" | chpasswd
    usermod -aG sudo $APP_USER || true
fi

if ! id "$ADMIN_USER" &>/dev/null; then
    useradd -m -s /bin/bash $ADMIN_USER
    ADMIN_PASSWORD=$(openssl rand -base64 16)
    echo "$ADMIN_USER:$ADMIN_PASSWORD" | chpasswd
    usermod -aG sudo $ADMIN_USER || true

    CRED_FILE="/root/server_credentials.txt"
    cat > "$CRED_FILE" <<EOF
=== Server Credentials ===
Domain: $DOMAIN_NAME
Admin User: $ADMIN_USER
Admin Password: $ADMIN_PASSWORD
App User: $APP_USER
App Password: $APP_USER_PASSWORD
MySQL Root Password: $MYSQL_ROOT_PASSWORD
Roundcube DB Password: $ROUNDCUBE_DB_PASS
Mail User ($ADMIN_USER@$DOMAIN_NAME): $MAIL_USER_PASS
EOF
    chmod 600 "$CRED_FILE"
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
# SSH CONFIG
# ==========================================
log "Configuring SSH on Port $SSH_PORT..."
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%F) || true
cat > /etc/ssh/sshd_config <<EOF
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
systemctl enable --now mysql || true

# Secure MySQL minimal hardening
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD';" || warning "Could not alter MySQL root password non-interactively. You may need to run mysql_secure_installation."
mysql -e "DELETE FROM mysql.user WHERE User='';" || true
mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" || true
mysql -e "DROP DATABASE IF EXISTS test;" || true
mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';" || true
mysql -e "FLUSH PRIVILEGES;" || true

cat > /root/.my.cnf <<EOF
[client]
user=root
password=$MYSQL_ROOT_PASSWORD
EOF
chmod 600 /root/.my.cnf

# ==========================================
# BIND9 (DNS)
# ==========================================
log "Configuring DNS (Bind9)..."
cat > /etc/bind/named.conf.options <<EOF
acl "trusted" {
    127.0.0.1;    # localhost
    $SERVER_IP;   # local server (may be empty)
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

cat > /etc/bind/named.conf.local <<EOF
zone "$DOMAIN_NAME" {
    type master;
    file "/etc/bind/zones/db.$DOMAIN_NAME";
};
EOF

mkdir -p /etc/bind/zones
SERIAL=$(date +%Y%m%d01)
cat > /etc/bind/zones/db.$DOMAIN_NAME <<EOF
$TTL    604800
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

named-checkconf || true
systemctl restart bind9 || true
systemctl enable bind9 || true

# ==========================================
# MAIL STACK (Postfix + Dovecot)
# ==========================================
log "Installing Mail Stack..."

debconf-set-selections <<< "postfix postfix/mailname string $DOMAIN_NAME"
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
apt install -y postfix dovecot-core dovecot-imapd dovecot-pop3d || true

postconf -e "myhostname = mail.$DOMAIN_NAME" || true
postconf -e "mydestination = \$myhostname, localhost.\$mydomain, localhost, $DOMAIN_NAME" || true
postconf -e "home_mailbox = Maildir/" || true
postconf -e "inet_interfaces = all" || true

sed -i "s/#disable_plaintext_auth = yes/disable_plaintext_auth = no/" /etc/dovecot/conf.d/10-auth.conf || true
sed -i "s/auth_mechanisms = plain/auth_mechanisms = plain login/" /etc/dovecot/conf.d/10-auth.conf || true
sed -i "s/mail_location = mbox:\~\/mail:INBOX=\/var\/mail\/%u/mail_location = maildir:\~\/Maildir/" /etc/dovecot/conf.d/10-mail.conf || true

systemctl restart postfix dovecot || true
systemctl enable postfix dovecot || true

# ==========================================
# phpMyAdmin (improved checks & install)
# ==========================================
log "Checking/installing phpMyAdmin..."

PMA_VERSION="5.2.1"

install_phpmyadmin() {
    cd /tmp
    rm -f phpMyAdmin-*-all-languages.zip || true
    if [ -d "/var/www/phpmyadmin" ]; then
        warning "/var/www/phpmyadmin already exists. Backing up to /var/www/phpmyadmin.bak.$(date +%F)"
        mv /var/www/phpmyadmin /var/www/phpmyadmin.bak.$(date +%F) || true
    fi

    wget -q https://files.phpmyadmin.net/phpMyAdmin/${PMA_VERSION}/phpMyAdmin-${PMA_VERSION}-all-languages.zip
    unzip -q phpMyAdmin-${PMA_VERSION}-all-languages.zip
    mv phpMyAdmin-${PMA_VERSION}-all-languages /var/www/phpmyadmin
    rm phpMyAdmin-${PMA_VERSION}-all-languages.zip || true

    cp /var/www/phpmyadmin/config.sample.inc.php /var/www/phpmyadmin/config.inc.php
    sed -i "s/\$cfg\\['blowfish_secret'\\] = '';/\$cfg\\['blowfish_secret'\\] = '$PMA_BLOWFISH';/" /var/www/phpmyadmin/config.inc.php

    mkdir -p /var/www/phpmyadmin/tmp
    chown -R www-data:www-data /var/www/phpmyadmin

    # Ensure necessary PHP extensions are installed
    apt install -y php${PHP_VERSION_SHORT}-mysql php${PHP_VERSION_SHORT}-mbstring php${PHP_VERSION_SHORT}-zip php${PHP_VERSION_SHORT}-xml php${PHP_VERSION_SHORT}-gd php${PHP_VERSION_SHORT}-curl || true

    # Ensure php.ini settings for session and upload
    PHP_INI=$(php --ini | grep "Loaded Configuration" | cut -d ':' -f2 | xargs)
    if [ -n "$PHP_INI" ]; then
        sed -i "s/upload_max_filesize = .*/upload_max_filesize = 100M/" "$PHP_INI" || true
        sed -i "s/post_max_size = .*/post_max_size = 100M/" "$PHP_INI" || true
        sed -i "s/;?session.save_path = .*/session.save_path = \"\/var\/lib\/php\/sessions\"/" "$PHP_INI" || true
        mkdir -p /var/lib/php/sessions
        chown -R www-data:www-data /var/lib/php/sessions
    fi

    log "phpMyAdmin installed to /var/www/phpmyadmin"
}

if [ -d "/var/www/phpmyadmin" ]; then
    info "phpMyAdmin appears to already be installed at /var/www/phpmyadmin. Ensuring config and extensions..."
    # Make sure blowfish exists
    if ! grep -q "blowfish_secret" /var/www/phpmyadmin/config.inc.php 2>/dev/null; then
        sed -i "s/\$cfg\\['blowfish_secret'\\] = '';/\$cfg\\['blowfish_secret'\\] = '$PMA_BLOWFISH';/" /var/www/phpmyadmin/config.inc.php || true
    fi
    chown -R www-data:www-data /var/www/phpmyadmin || true
    apt install -y php${PHP_VERSION_SHORT}-mbstring php${PHP_VERSION_SHORT}-zip php${PHP_VERSION_SHORT}-xml php${PHP_VERSION_SHORT}-gd php${PHP_VERSION_SHORT}-curl || true
else
    install_phpmyadmin
fi

# ==========================================
# Roundcube Webmail (check & configure)
# ==========================================
log "Checking/installing Roundcube Webmail..."

install_roundcube() {
    apt install -y roundcube roundcube-mysql php-net-smtp php-mail-mime || true
    # Create DB and user
    mysql -e "CREATE DATABASE IF NOT EXISTS roundcubemail DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;" || true
    mysql -e "CREATE USER IF NOT EXISTS 'roundcube'@'localhost' IDENTIFIED BY '$ROUNDCUBE_DB_PASS';" || true
    mysql -e "GRANT ALL PRIVILEGES ON roundcubemail.* TO 'roundcube'@'localhost';" || true
    mysql -e "FLUSH PRIVILEGES;" || true

    # Import SQL if present
    if [ -f "/usr/share/roundcube/SQL/mysql.initial.sql.gz" ]; then
        zcat /usr/share/roundcube/SQL/mysql.initial.sql.gz | mysql -u roundcube -p$ROUNDCUBE_DB_PASS roundcubemail || true
    elif [ -f "/usr/share/roundcube/SQL/mysql.initial.sql" ]; then
        mysql -u roundcube -p$ROUNDCUBE_DB_PASS roundcubemail < /usr/share/roundcube/SQL/mysql.initial.sql || true
    fi

    mkdir -p /etc/roundcube
    cat > /etc/roundcube/config.inc.php <<EOF
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

    ln -sf /usr/share/roundcube /var/www/webmail || true
    chown -R www-data:www-data /var/www/webmail || true
}

if [ -d "/var/www/webmail" ] || [ -d "/usr/share/roundcube" ]; then
    info "Roundcube appears to be installed. Ensuring configuration and DB..."
    install_roundcube
else
    install_roundcube
fi

# ==========================================
# NGINX SITE (robust alias handling for phpMyAdmin & Roundcube)
# ==========================================
log "Configuring Nginx site for $DOMAIN_NAME..."

NGINX_CONF="/etc/nginx/sites-available/$DOMAIN_NAME"
cat > "$NGINX_CONF" <<EOF
server {
    listen 80;
    server_name $DOMAIN_NAME www.$DOMAIN_NAME mail.$DOMAIN_NAME webmail.$DOMAIN_NAME ns1.$DOMAIN_NAME ns2.$DOMAIN_NAME;
    root /var/www/shm-panel;
    index index.php index.html index.htm;

    # Main Panel
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    # phpMyAdmin
    location /phpmyadmin {
        alias /var/www/phpmyadmin/;
        index index.php;
        try_files \$uri \$uri/ /phpmyadmin/index.php;
    }

    location ~ ^/phpmyadmin/(.+\.php)$ {
        alias /var/www/phpmyadmin/$1;
        fastcgi_pass $PHP_FPM_SOCK;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME /var/www/phpmyadmin/$1;
    }

    # Roundcube Webmail
    location /webmail {
        alias /var/www/webmail/;
        index index.php;
        try_files \$uri \$uri/ /webmail/index.php;
    }

    location ~ ^/webmail/(.+\.php)$ {
        alias /var/www/webmail/$1;
        fastcgi_pass $PHP_FPM_SOCK;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME /var/www/webmail/$1;
    }

    # PHP processing for panel
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass $PHP_FPM_SOCK;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    # security & caching
    location ~ /\. { deny all; }
    location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ { expires 30d; }
    client_max_body_size 100M;
}
EOF

# enable site
rm -f /etc/nginx/sites-enabled/default || true
ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/$DOMAIN_NAME || true

# Create directories
mkdir -p /var/www/shm-panel
echo "<?php phpinfo(); ?>" > /var/www/shm-panel/phpinfo.php
chown -R $APP_USER:www-data /var/www/shm-panel || true
chown -R www-data:www-data /var/www/webmail || true
chmod 755 /var/www/shm-panel || true

# ==========================================
# FINALIZE: restart services & checks
# ==========================================
log "Restarting and checking services..."

systemctl daemon-reload || true
systemctl restart bind9 || true
systemctl restart mysql || true
# Restart php-fpm service gracefully
if systemctl list-units --full -all | grep -Fq "php${PHP_VERSION_SHORT}-fpm.service"; then
    systemctl restart "php${PHP_VERSION_SHORT}-fpm" || true
else
    systemctl restart php*-fpm || true
fi
systemctl restart nginx || true
systemctl restart postfix || true
systemctl restart dovecot || true
systemctl restart fail2ban || true
systemctl restart ssh || true

# Quick checks
log "Running quick health checks..."
NGINX_STATUS=$(systemctl is-active nginx || true)
PHP_STATUS=$(systemctl is-active "php${PHP_VERSION_SHORT}-fpm" 2>/dev/null || systemctl is-active php-fpm 2>/dev/null || echo "unknown")
MYSQL_STATUS=$(systemctl is-active mysql || true)

log "Nginx: $NGINX_STATUS"
log "PHP-FPM (php${PHP_VERSION_SHORT}-fpm): $PHP_STATUS"
log "MySQL: $MYSQL_STATUS"

# Create System Info Script
cat > /root/system-info.sh <<EOF
#!/bin/bash
echo "=== System Status ==="
echo "Uptime: \$(uptime -p)"
echo "Mem: \$(free -h | grep Mem | awk '{print \$3 \"/\" \$2}')"
echo "PHP Version: \$(php -v | head -n 1)"
echo ""
echo "=== Services ==="
echo "Nginx: \$(systemctl is-active nginx)"
echo "MySQL: \$(systemctl is-active mysql)"
echo "PHP-FPM: \$(systemctl is-active php${PHP_VERSION_SHORT}-fpm || true)"
echo "Bind9: \$(systemctl is-active bind9)"
EOF
chmod +x /root/system-info.sh || true

log "Setup Completed (with best-effort checks)."

echo ""
echo -e "${YELLOW}==============================================${NC}"
echo -e "${GREEN}       INSTALLATION COMPLETE FOR $DOMAIN_NAME ${NC}"
echo -e "${YELLOW}==============================================${NC}"
echo ""
echo "1. CREDENTIALS (Saved in /root/server_credentials.txt):"
echo "   - Admin User: $ADMIN_USER"
echo "   - SSH Port: $SSH_PORT (Reconnect using: ssh -p $SSH_PORT $ADMIN_USER@${SERVER_IP:-<server-ip>})"
echo ""
echo "2. PHP CONFIGURATION:" 
echo "   - Detected/Installed Version: $PHP_VERSION_SHORT"
echo "   - FPM Socket: $PHP_FPM_SOCK"
echo ""
echo "3. ACCESS URLS:"
echo "   - Panel:     http://$DOMAIN_NAME/"
echo "   - phpMyAdmin: http://$DOMAIN_NAME/phpmyadmin"
echo "   - Webmail:   http://$DOMAIN_NAME/webmail"
echo ""
echo "4. DNS SETUP (Go to your domain registrar):"
echo "   - Create Child NameServers (Glue Records):"
echo "     ns1.$DOMAIN_NAME -> ${SERVER_IP:-<server-ip>}"
echo "     ns2.$DOMAIN_NAME -> ${SERVER_IP:-<server-ip>}"\necho "   - Change Nameservers to ns1.$DOMAIN_NAME and ns2.$DOMAIN_NAME"
echo ""
echo "5. SSL CERTIFICATE:" 
echo "   Run this command after DNS propagates:"
echo "   certbot --nginx -d $DOMAIN_NAME -d www.$DOMAIN_NAME -d mail.$DOMAIN_NAME -d webmail.$DOMAIN_NAME"
echo ""

# End of script
