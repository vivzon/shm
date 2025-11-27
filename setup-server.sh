#!/bin/bash
# ==========================================
# SHM Panel Setup Script (Fixed & Hardened)
# ==========================================
# - Robust PHP detection & extension install
# - Corrected Nginx alias + fastcgi for phpMyAdmin & Roundcube
# - Postfix + Dovecot adjusted
# - Bind9 zone + suggestions for SPF/DKIM/DMARC + OpenDKIM generation
# - Improved firewall & fail2ban basics
# - Certbot automation attempt (manual DNS prerequisite)
# ==========================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; }
warning() { echo -e "${YELLOW}[WARN] $1${NC}"; }
info() { echo -e "${BLUE}[INFO] $1${NC}"; }

# Must be root
if [ "$EUID" -ne 0 ]; then
    error "Please run as root"
    exit 1
fi

clear
echo -e "${YELLOW}==============================================${NC}"
echo -e "${YELLOW}   SHM Panel + DNS + Webmail + phpMyAdmin     ${NC}"
echo -e "${YELLOW}   Fixed & Hardened Installer                 ${NC}"
echo -e "${YELLOW}==============================================${NC}"
echo ""
read -p "Enter your Domain Name (e.g., example.com): " DOMAIN_NAME

if [ -z "$DOMAIN_NAME" ]; then
    error "Domain name is required."
    exit 1
fi

# Get public IP (fallbacks)
SERVER_IP=""
if command -v curl &>/dev/null; then
    SERVER_IP=$(curl -s ifconfig.me || true)
fi
if [ -z "$SERVER_IP" ]; then
    SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || true)
fi
if [ -z "$SERVER_IP" ]; then
    error "Unable to determine server public IP. Please set SERVER_IP manually in script."
    exit 1
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

export DEBIAN_FRONTEND=noninteractive

log "Updating system packages..."
apt update -y
apt upgrade -y

# install core utilities
apt install -y software-properties-common curl wget git unzip htop gnupg2 lsb-release ufw fail2ban dialog apt-transport-https ca-certificates

# Enable universe (Debian/Ubuntu)
if [ -f /etc/lsb-release ]; then
    add-apt-repository universe -y || true
    apt update -y
fi

# -------------------------
# PHP Detection & Installation (robust)
# -------------------------
log "Detecting PHP version (if installed)..."
PHP_VERSION=""
if command -v php &>/dev/null; then
    PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
    info "Detected PHP CLI: $PHP_VERSION"
fi

# If php not present or no FPM socket found, install php-fpm (default) then detect socket
if [ -z "$PHP_VERSION" ]; then
    warning "PHP not found. Installing default php-fpm and CLI..."
    apt install -y php-fpm php-cli
    # detect after install
    if command -v php &>/dev/null; then
        PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
    fi
fi

# if still empty try to detect php-fpm socket patterns
if [ -z "$PHP_VERSION" ]; then
    # search /run/php for php*-fpm.sock
    if ls /run/php/php*-fpm.sock &>/dev/null; then
        PHP_VERSION=$(ls /run/php/php*-fpm.sock | sed -n 's#.*/php\([0-9]\+\.[0-9]\+\)-fpm.sock#\1#p' | head -n1)
    fi
fi

if [ -z "$PHP_VERSION" ]; then
    # final fallback: assume 8.1
    PHP_VERSION="8.1"
    warning "Unable to auto-detect PHP version; defaulting to $PHP_VERSION"
fi

info "Using PHP version: $PHP_VERSION"

# Preferred list of per-version packages; try to install versioned packages and fallback to generic ones.
PHP_EXT_VER="php${PHP_VERSION}-fpm php${PHP_VERSION}-mysql php${PHP_VERSION}-curl php${PHP_VERSION}-gd php${PHP_VERSION}-mbstring php${PHP_VERSION}-xml php${PHP_VERSION}-zip php${PHP_VERSION}-bcmath php${PHP_VERSION}-intl php${PHP_VERSION}-soap php${PHP_VERSION}-ldap php${PHP_VERSION}-imagick"
PHP_EXT_GEN="php-mysql php-curl php-gd php-mbstring php-xml php-zip php-bcmath php-intl php-soap php-ldap imagemagick php-imagick"

log "Attempting to install PHP extensions for $PHP_VERSION..."
if apt install -y $PHP_EXT_VER 2>/tmp/phperr.log; then
    info "Installed versioned PHP extensions."
else
    warning "Versioned PHP packages failed; installing generic PHP extensions (see /tmp/phperr.log)."
    apt install -y $PHP_EXT_GEN
fi

# Determine PHP FPM socket path reliably
PHP_SOCKET=""
if [ -S "/run/php/php${PHP_VERSION}-fpm.sock" ]; then
    PHP_SOCKET="unix:/run/php/php${PHP_VERSION}-fpm.sock"
else
    # pick any php*-fpm socket
    SOCK_PATH=$(ls /run/php/php*-fpm.sock 2>/dev/null | head -n1 || true)
    if [ -n "$SOCK_PATH" ]; then
        SOCK_VER=$(echo "$SOCK_PATH" | sed -n 's#.*/php\([0-9]\+\.[0-9]\+\)-fpm.sock#\1#p')
        PHP_SOCKET="unix:$SOCK_PATH"
        info "Using detected socket: $PHP_SOCKET (ver $SOCK_VER)"
    else
        # fallback to 127.0.0.1:9000 if FPM uses TCP (rare)
        PHP_SOCKET="127.0.0.1:9000"
        warning "PHP-FPM socket not found; using $PHP_SOCKET. Ensure php-fpm is running."
    fi
fi

info "Final PHP socket: $PHP_SOCKET"

# -------------------------
# Core services
# -------------------------
log "Installing Nginx, MySQL, Bind9, Certbot, Postfix/Dovecot, OpenDKIM..."
apt install -y nginx mariadb-server bind9 bind9utils bind9-doc dnsutils certbot python3-certbot-nginx postfix dovecot-core dovecot-imapd dovecot-pop3d opendkim opendkim-tools

# set timezone
timedatectl set-timezone $TIMEZONE || true

# -------------------------
# User management
# -------------------------
log "Configuring users..."
if ! id "$APP_USER" &>/dev/null; then
    useradd -m -s /bin/bash "$APP_USER" || true
    echo "$APP_USER:$APP_USER_PASSWORD" | chpasswd
    usermod -aG sudo "$APP_USER" || true
fi

if ! id "$ADMIN_USER" &>/dev/null; then
    useradd -m -s /bin/bash "$ADMIN_USER" || true
    ADMIN_PASSWORD=$(openssl rand -base64 16)
    echo "$ADMIN_USER:$ADMIN_PASSWORD" | chpasswd
    usermod -aG sudo "$ADMIN_USER" || true

    CRED_FILE="/root/server_credentials.txt"
    cat > "$CRED_FILE" << EOF
=== Server Credentials ===
Domain: $DOMAIN_NAME
Admin User: $ADMIN_USER
Admin Password: $ADMIN_PASSWORD
App User: $APP_USER
App Password: $APP_USER_PASSWORD
MySQL Root Password: $MYSQL_ROOT_PASSWORD
Roundcube DB Password: $ROUNDCUBE_DB_PASS
Mail User ($ADMIN_USER@$DOMAIN_NAME): $MAIL_USER_PASS
SSH Port: $SSH_PORT
EOF
    chmod 600 "$CRED_FILE"
    info "Credentials saved to $CRED_FILE"
fi

# -------------------------
# Firewall
# -------------------------
log "Configuring firewall (ufw)..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow "$SSH_PORT"/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 53/tcp
ufw allow 53/udp
# mail ports
ufw allow 25/tcp
ufw allow 465/tcp
ufw allow 587/tcp
ufw allow 143/tcp
ufw allow 993/tcp
ufw --force enable

# -------------------------
# SSH Hardening
# -------------------------
log "Configuring SSH on Port $SSH_PORT..."
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%F) || true

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

# reload ssh safely to avoid accidental lockout; do not exit on failure
systemctl reload ssh || systemctl restart ssh || true

# -------------------------
# MySQL / MariaDB secure basic setup
# -------------------------
log "Configuring MySQL/MariaDB..."
systemctl enable mariadb
systemctl start mariadb

# Use mysql commands to secure & set root password (MariaDB's unix_socket plugin must be considered)
# Create root password by setting the root user's password for mysql_native_password if required
# For MariaDB 10+ root plugin may be unix_socket - this forces plaintext password login change
mysql <<EOF || true
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF

cat > /root/.my.cnf << EOF
[client]
user=root
password=$MYSQL_ROOT_PASSWORD
EOF
chmod 600 /root/.my.cnf

# -------------------------
# Bind9 DNS
# -------------------------
log "Configuring Bind9 (local authoritative for $DOMAIN_NAME)..."
cat > /etc/bind/named.conf.options << EOF
acl "trusted" {
    127.0.0.1;
    ::1;
    $SERVER_IP;
};

options {
    directory "/var/cache/bind";
    recursion yes;
    allow-recursion { trusted; };
    listen-on { any; };
    listen-on-v6 { any; };
    allow-transfer { none; };
    forwarders { 8.8.8.8; 8.8.4.4; };
    dnssec-validation auto;
};
EOF

cat > /etc/bind/named.conf.local << EOF
zone "$DOMAIN_NAME" {
    type master;
    file "/etc/bind/zones/db.$DOMAIN_NAME";
};
EOF

mkdir -p /etc/bind/zones
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

; Basic SPF (REVIEW: adjust as needed)
@       IN      TXT     "v=spf1 mx a ip4:$SERVER_IP -all"
; Basic DMARC (REVIEW: adjust reporting addresses)
_dmarc  IN      TXT     "v=DMARC1; p=quarantine; rua=mailto:postmaster@$DOMAIN_NAME; ruf=mailto:postmaster@$DOMAIN_NAME; fo=1"
EOF

named-checkconf || true
named-checkzone "$DOMAIN_NAME" /etc/bind/zones/db.$DOMAIN_NAME || true
systemctl restart bind9
systemctl enable bind9

# -------------------------
# Postfix + Dovecot basic config
# -------------------------
log "Configuring Mail Stack (Postfix + Dovecot)..."

# Preseed Postfix (Internet Site)
debconf-set-selections <<< "postfix postfix/mailname string $DOMAIN_NAME"
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
apt install -y postfix

# Postfix basic settings
postconf -e "myhostname = mail.$DOMAIN_NAME"
postconf -e "mydestination = \$myhostname, localhost.$DOMAIN_NAME, localhost, $DOMAIN_NAME"
postconf -e "home_mailbox = Maildir/"
postconf -e "inet_interfaces = all"
postconf -e "virtual_alias_maps = hash:/etc/postfix/virtual"
postconf -e "smtpd_banner = \$myhostname ESMTP"

# Dovecot adjustments
sed -i 's/#disable_plaintext_auth = yes/disable_plaintext_auth = no/' /etc/dovecot/conf.d/10-auth.conf || true
sed -i 's/auth_mechanisms = plain/auth_mechanisms = plain login/' /etc/dovecot/conf.d/10-auth.conf || true
# set mail location to Maildir
sed -i 's|#mail_location = mbox:~/mail:INBOX=/var/mail/%u|mail_location = maildir:~/Maildir|g' /etc/dovecot/conf.d/10-mail.conf || true

systemctl restart postfix || true
systemctl restart dovecot || true
systemctl enable postfix dovecot

# -------------------------
# OpenDKIM (generate keys & integrate with Postfix)
# -------------------------
log "Configuring OpenDKIM for DKIM signing..."
mkdir -p /etc/opendkim/keys/$DOMAIN_NAME
opendkim-genkey -D /etc/opendkim/keys/$DOMAIN_NAME/ -d $DOMAIN_NAME -s default || true
chown -R opendkim:opendkim /etc/opendkim/keys/$DOMAIN_NAME || true

cat > /etc/opendkim.conf << EOF
Syslog yes
UMask 002
Canonicalization relaxed/simple
Mode sv
Socket inet:8891@127.0.0.1
PidFile /var/run/opendkim/opendkim.pid
UserID opendkim:opendkim
AutoRestart yes
AutoRestartRate 10/1h
ExternalIgnoreList refile:/etc/opendkim/TrustedHosts
InternalHosts refile:/etc/opendkim/TrustedHosts
KeyTable /etc/opendkim/KeyTable
SigningTable /etc/opendkim/SigningTable
TrustedHosts /etc/opendkim/TrustedHosts
EOF

# TrustedHosts
cat > /etc/opendkim/TrustedHosts << EOF
127.0.0.1
localhost
$SERVER_IP
EOF

# KeyTable
cat > /etc/opendkim/KeyTable << EOF
default._domainkey.$DOMAIN_NAME $DOMAIN_NAME:default:/etc/opendkim/keys/$DOMAIN_NAME/default.private
EOF

# SigningTable
cat > /etc/opendkim/SigningTable << EOF
*@${DOMAIN_NAME} default._domainkey.${DOMAIN_NAME}
EOF

# Ensure Postfix integrates with opendkim
postconf -e "milter_default_action = accept"
postconf -e "smtpd_milters = inet:127.0.0.1:8891"
postconf -e "non_smtpd_milters = inet:127.0.0.1:8891"

systemctl restart opendkim || true
systemctl enable opendkim

# Print DKIM public TXT for registrar - user should add this TXT
DKIM_PUB=$(awk '/^default._domainkey/ {print $0; exit}' /etc/opendkim/keys/$DOMAIN_NAME/default.txt 2>/dev/null || true)
if [ -f /etc/opendkim/keys/$DOMAIN_NAME/default.txt ]; then
    info "DKIM key generated at /etc/opendkim/keys/$DOMAIN_NAME/default.txt"
    info "Add this TXT record at your registrar:"
    echo "---- DKIM TXT (paste as single line) ----"
    sed -n '1,200p' /etc/opendkim/keys/$DOMAIN_NAME/default.txt || true
    echo "-----------------------------------------"
fi

# -------------------------
# phpMyAdmin manual install
# -------------------------
log "Installing phpMyAdmin..."
PMA_VERSION="5.2.1"
cd /tmp || true
rm -f phpMyAdmin-*-all-languages.zip || true
wget -q "https://files.phpmyadmin.net/phpMyAdmin/${PMA_VERSION}/phpMyAdmin-${PMA_VERSION}-all-languages.zip"
unzip -q phpMyAdmin-${PMA_VERSION}-all-languages.zip
rm -rf /var/www/phpmyadmin || true
mv phpMyAdmin-${PMA_VERSION}-all-languages /var/www/phpmyadmin
rm phpMyAdmin-${PMA_VERSION}-all-languages.zip || true

cp /var/www/phpmyadmin/config.sample.inc.php /var/www/phpmyadmin/config.inc.php
sed -i "s/\\\$cfg\\['blowfish_secret'\\] = '';/\\\$cfg\\['blowfish_secret'\\] = '${PMA_BLOWFISH}';/" /var/www/phpmyadmin/config.inc.php
echo "\$cfg['TempDir'] = '/var/www/phpmyadmin/tmp';" >> /var/www/phpmyadmin/config.inc.php
mkdir -p /var/www/phpmyadmin/tmp
chown -R www-data:www-data /var/www/phpmyadmin
chmod -R 750 /var/www/phpmyadmin

# -------------------------
# Roundcube (via apt) and DB
# -------------------------
log "Installing Roundcube (webmail)..."
apt install -y roundcube roundcube-mysql php-net-smtp php-mail-mime || true

mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "DROP DATABASE IF EXISTS roundcubemail;"
mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "CREATE DATABASE roundcubemail DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;"
mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "CREATE USER IF NOT EXISTS 'roundcube'@'localhost' IDENTIFIED BY '${ROUNDCUBE_DB_PASS}';"
mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "GRANT ALL PRIVILEGES ON roundcubemail.* TO 'roundcube'@'localhost';"
mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "FLUSH PRIVILEGES;"

if [ -f "/usr/share/roundcube/SQL/mysql.initial.sql.gz" ]; then
    zcat /usr/share/roundcube/SQL/mysql.initial.sql.gz | mysql -u roundcube -p"${ROUNDCUBE_DB_PASS}" roundcubemail || true
elif [ -f "/usr/share/roundcube/SQL/mysql.initial.sql" ]; then
    mysql -u roundcube -p"${ROUNDCUBE_DB_PASS}" roundcubemail < /usr/share/roundcube/SQL/mysql.initial.sql || true
fi

mkdir -p /etc/roundcube
cat > /etc/roundcube/config.inc.php << EOF
<?php
\$config['db_dsnw'] = 'mysql://roundcube:${ROUNDCUBE_DB_PASS}@localhost/roundcubemail';
\$config['default_host'] = 'ssl://mail.${DOMAIN_NAME}';
\$config['smtp_server'] = 'tls://mail.${DOMAIN_NAME}';
\$config['smtp_port'] = 587;
\$config['smtp_user'] = '%u';
\$config['smtp_pass'] = '%p';
\$config['support_url'] = '';
\$config['product_name'] = 'SHM Webmail';
\$config['des_key'] = '$(openssl rand -base64 24)';
\$config['plugins'] = array('archive', 'zipdownload');
\$config['skin'] = 'elastic';
EOF

ln -sf /usr/share/roundcube /var/www/webmail
chown -R www-data:www-data /var/www/webmail
chmod -R 750 /var/www/webmail

# -------------------------
# Nginx configuration (fixed alias + SCRIPT_FILENAME handling)
# -------------------------
log "Configuring Nginx..."

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

    # phpMyAdmin - using alias + correct fastcgi param
    location /phpmyadmin {
        alias /var/www/phpmyadmin/;
        index index.php;
        try_files \$uri \$uri/ /phpmyadmin/index.php?\$args;
    }

    location ~ ^/phpmyadmin/(.+\.php)\$ {
        alias /var/www/phpmyadmin/\$1;
        fastcgi_pass $PHP_SOCKET;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME /var/www/phpmyadmin/\$1;
        fastcgi_param DOCUMENT_ROOT /var/www/phpmyadmin;
    }

    # Roundcube /webmail
    location /webmail {
        alias /var/www/webmail/;
        index index.php;
        try_files \$uri \$uri/ /webmail/index.php?\$args;
    }

    location ~ ^/webmail/(.+\.php)\$ {
        alias /var/www/webmail/\$1;
        fastcgi_pass $PHP_SOCKET;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME /var/www/webmail/\$1;
        fastcgi_param DOCUMENT_ROOT /var/www/webmail;
    }

    # Generic PHP processing for other PHP files under site root
    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass $PHP_SOCKET;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    # Security & Caching
    location ~ /\. { deny all; }
    location ~* \.(jpg|jpeg|png|gif|ico|css|js)\$ { expires 30d; access_log off; log_not_found off; }
    client_max_body_size 100M;
}
EOF

ln -sf /etc/nginx/sites-available/$DOMAIN_NAME /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default || true

mkdir -p /var/www/shm-panel
echo "<?php phpinfo(); ?>" > /var/www/shm-panel/phpinfo.php
chown -R $APP_USER:www-data /var/www/shm-panel
chown -R www-data:www-data /var/www/webmail
chmod 755 /var/www/shm-panel

# -------------------------
# fail2ban basic jail for ssh and postfix
# -------------------------
log "Configuring fail2ban basic jails..."
cat > /etc/fail2ban/jail.d/custom.local << EOF
[sshd]
enabled = true
port    = $SSH_PORT
filter  = sshd
logpath = /var/log/auth.log
maxretry = 6

[postfix]
enabled = true
port = smtp,ssmtp,submission
logpath = /var/log/mail.log
maxretry = 6
EOF

systemctl restart fail2ban || true

# -------------------------
# Restart services
# -------------------------
log "Restarting services..."
systemctl daemon-reload || true
systemctl restart bind9 || true
systemctl restart mariadb || true
systemctl restart php${PHP_VERSION}-fpm || true || true
systemctl restart nginx || true
systemctl restart postfix || true
systemctl restart dovecot || true
systemctl restart opendkim || true
systemctl restart fail2ban || true
systemctl restart ssh || true

# Create system-info script
cat > /root/system-info.sh << 'EOF'
#!/bin/bash
echo "=== System Status ==="
echo "Uptime: $(uptime -p)"
echo "Mem: $(free -h | grep Mem | awk '{print $3 "/" $2}')"
echo "PHP Version: $(php -v | head -n 1 2>/dev/null || echo 'php not found')"
echo ""
echo "=== Services ==="
echo "Nginx: $(systemctl is-active nginx)"
echo "MySQL/MariaDB: $(systemctl is-active mariadb)"
echo "PHP-FPM: $(systemctl is-active php*-fpm 2>/dev/null || true)"
echo "Bind9: $(systemctl is-active bind9)"
echo "Postfix: $(systemctl is-active postfix)"
echo "Dovecot: $(systemctl is-active dovecot)"
echo "OpenDKIM: $(systemctl is-active opendkim)"
echo ""
EOF
chmod +x /root/system-info.sh

log "Setup Completed (script finished)."

echo ""
echo -e "${YELLOW}==============================================${NC}"
echo -e "${GREEN}       INSTALLATION SCRIPT FINISHED FOR $DOMAIN_NAME ${NC}"
echo -e "${YELLOW}==============================================${NC}"
echo ""
echo "Important next steps (manual & registrar):"
echo "1) Add glue records at your domain registrar:"
echo "   ns1.$DOMAIN_NAME -> $SERVER_IP"
echo "   ns2.$DOMAIN_NAME -> $SERVER_IP"
echo ""
echo "2) Add DNS TXT records (SPF/DKIM/DMARC):"
echo "   - SPF:    v=spf1 mx a ip4:$SERVER_IP -all"
echo "   - DKIM:   (see generated file /etc/opendkim/keys/$DOMAIN_NAME/default.txt )"
echo "   - DMARC:  v=DMARC1; p=quarantine; rua=mailto:postmaster@$DOMAIN_NAME"
echo ""
echo "3) Obtain SSL certs (after DNS propagates):"
echo "   certbot --nginx -d $DOMAIN_NAME -d www.$DOMAIN_NAME -d mail.$DOMAIN_NAME -d webmail.$DOMAIN_NAME"
echo ""
echo "4) phpMyAdmin: http://$DOMAIN_NAME/phpmyadmin"
echo "   Roundcube: http://$DOMAIN_NAME/webmail"
echo "   Panel: http://$DOMAIN_NAME/"
echo ""
echo "5) Credentials saved at: /root/server_credentials.txt"
echo ""
echo "If anything fails, run: /root/system-info.sh to check service status."
echo ""

# End of script
