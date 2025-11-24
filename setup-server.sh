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

# ==========================================
# INPUT REQUIRED
# ==========================================
echo -e "${YELLOW}==============================================${NC}"
echo -e "${YELLOW}   SHM Panel + DNS + Webmail + phpMyAdmin     ${NC}"
echo -e "${YELLOW}==============================================${NC}"
echo ""
read -p "Enter your Domain Name (e.g., example.com): " DOMAIN_NAME

if [ -z "$DOMAIN_NAME" ]; then
    error "Domain name is required for DNS and Mail configuration."
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
PMA_BLOWFISH=$(openssl rand -base64 32)
ROUNDCUBE_DB_PASS=$(openssl rand -base64 24)
MAIL_USER_PASS=$(openssl rand -base64 16)

log "Starting Full Server Setup for $DOMAIN_NAME"
log "Server IP: $SERVER_IP"

# Update system
log "Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt update && apt upgrade -y

# Install essential packages
log "Installing base packages..."
apt install -y \
    curl wget git unzip htop gnupg2 lsb-release \
    nginx mysql-server php-fpm \
    php-mysql php-curl php-gd php-mbstring \
    php-xml php-zip php-bcmath php-json \
    php-intl php-soap php-ldap php-imagick \
    ufw fail2ban logrotate software-properties-common \
    bind9 bind9utils bind9-doc dnsutils \
    certbot python3-certbot-nginx

# Set timezone
log "Setting timezone to $TIMEZONE..."
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
    echo "=== Server Credentials ===" > /root/server_credentials.txt
    echo "Domain: $DOMAIN_NAME" >> /root/server_credentials.txt
    echo "Admin User: $ADMIN_USER" >> /root/server_credentials.txt
    echo "Admin Password: $ADMIN_PASSWORD" >> /root/server_credentials.txt
    echo "App User: $APP_USER" >> /root/server_credentials.txt
    echo "App Password: $APP_USER_PASSWORD" >> /root/server_credentials.txt
    echo "MySQL Root Password: $MYSQL_ROOT_PASSWORD" >> /root/server_credentials.txt
    echo "Roundcube DB Password: $ROUNDCUBE_DB_PASS" >> /root/server_credentials.txt
    echo "Mail User ($ADMIN_USER@$DOMAIN_NAME): $MAIL_USER_PASS" >> /root/server_credentials.txt
    chmod 600 /root/server_credentials.txt
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
ufw allow 53/tcp     # DNS
ufw allow 53/udp     # DNS
ufw allow 25/tcp     # SMTP
ufw allow 465/tcp    # SMTPS
ufw allow 587/tcp    # SMTP Submission
ufw allow 143/tcp    # IMAP
ufw allow 993/tcp    # IMAPS
ufw --force enable

# ==========================================
# SSH SECURITY
# ==========================================
log "Configuring SSH..."
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

# ==========================================
# MYSQL SETUP
# ==========================================
log "Configuring MySQL..."
systemctl enable mysql
systemctl start mysql

mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD';"
mysql -e "DELETE FROM mysql.user WHERE User='';"
mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
mysql -e "DROP DATABASE IF EXISTS test;"
mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
mysql -e "FLUSH PRIVILEGES;"

# .my.cnf for passwordless root access via CLI
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

# Check config and restart
named-checkconf
systemctl restart bind9
systemctl enable bind9

# ==========================================
# EMAIL STACK (Postfix + Dovecot)
# ==========================================
log "Installing Mail Stack..."

# Pre-configure Postfix
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
# PHPMYADMIN (Manual Install for Nginx)
# ==========================================
log "Installing phpMyAdmin..."

PMA_VERSION="5.2.1"
cd /tmp
wget https://files.phpmyadmin.net/phpMyAdmin/${PMA_VERSION}/phpMyAdmin-${PMA_VERSION}-all-languages.zip
unzip phpMyAdmin-${PMA_VERSION}-all-languages.zip
mv phpMyAdmin-${PMA_VERSION}-all-languages /var/www/phpmyadmin
rm phpMyAdmin-${PMA_VERSION}-all-languages.zip

# Create Config
cp /var/www/phpmyadmin/config.sample.inc.php /var/www/phpmyadmin/config.inc.php
sed -i "s/\$cfg\['blowfish_secret'\] = '';/\$cfg\['blowfish_secret'\] = '$PMA_BLOWFISH';/" /var/www/phpmyadmin/config.inc.php

# Create tmp dir for PMA
mkdir -p /var/www/phpmyadmin/tmp
chown -R www-data:www-data /var/www/phpmyadmin

# ==========================================
# WEBMAIL (Roundcube)
# ==========================================
log "Installing Roundcube Webmail..."

apt install -y roundcube roundcube-mysql php-net-smtp php-mail-mime

# Configure Database for Roundcube
mysql -e "CREATE DATABASE roundcubemail DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;"
mysql -e "CREATE USER 'roundcube'@'localhost' IDENTIFIED BY '$ROUNDCUBE_DB_PASS';"
mysql -e "GRANT ALL PRIVILEGES ON roundcubemail.* TO 'roundcube'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# Import initial SQL
zcat /usr/share/roundcube/SQL/mysql.initial.sql.gz | mysql -u roundcube -p$ROUNDCUBE_DB_PASS roundcubemail

# Configure Roundcube
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

PHP_VERSION=$(php -v | head -n 1 | cut -d " " -f 2 | cut -d "." -f 1,2)

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
            fastcgi_pass unix:/var/run/php/php$PHP_VERSION-fpm.sock;
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
            fastcgi_pass unix:/var/run/php/php$PHP_VERSION-fpm.sock;
            fastcgi_index index.php;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$request_filename;
        }
    }

    # PHP Processing
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php$PHP_VERSION-fpm.sock;
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
rm -f /etc/nginx/sites-enabled/shm-panel
ln -sf /etc/nginx/sites-available/$DOMAIN_NAME /etc/nginx/sites-enabled/

# Create Directories & Permissions
mkdir -p /var/www/shm-panel
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
systemctl restart php$PHP_VERSION-fpm
systemctl restart nginx
systemctl restart postfix
systemctl restart dovecot
systemctl restart fail2ban
systemctl restart ssh

# Create a System Info Script (Updated)
cat > /root/system-info.sh << 'EOF'
#!/bin/bash
echo "=== System Status ==="
echo "Uptime: $(uptime -p)"
echo "Load: $(uptime | awk -F'load average:' '{print $2}')"
echo "Mem: $(free -h | grep Mem | awk '{print $3 "/" $2}')"
echo ""
echo "=== Service Status ==="
echo "Nginx: $(systemctl is-active nginx)"
echo "MySQL: $(systemctl is-active mysql)"
echo "PHP: $(systemctl is-active php*-fpm | head -n1)"
echo "DNS (Bind): $(systemctl is-active bind9)"
echo "Postfix: $(systemctl is-active postfix)"
echo "Dovecot: $(systemctl is-active dovecot)"
echo ""
echo "=== Network ==="
ufw status numbered | grep -v "v6"
EOF
chmod +x /root/system-info.sh

log "Setup Completed Successfully!"
echo ""
echo -e "${YELLOW}==============================================${NC}"
echo -e "${GREEN}       INSTALLATION COMPLETE FOR $DOMAIN_NAME ${NC}"
echo -e "${YELLOW}==============================================${NC}"
echo ""
echo "1. ACCESS DETAILS:"
echo "   - Panel:     http://$DOMAIN_NAME/"
echo "   - phpMyAdmin: http://$DOMAIN_NAME/phpmyadmin"
echo "   - Webmail:   http://$DOMAIN_NAME/webmail"
echo ""
echo "2. CREDENTIALS (Saved in /root/server_credentials.txt):"
echo "   - Admin User: $ADMIN_USER"
echo "   - SSH Port: $SSH_PORT"
echo ""
echo "3. DNS CONFIGURATION:"
echo "   - Nameserver 1: ns1.$DOMAIN_NAME ($SERVER_IP)"
echo "   - Nameserver 2: ns2.$DOMAIN_NAME ($SERVER_IP)"
echo "   * IMPORTANT: Go to your Domain Registrar and set your Glue Records/Nameservers"
echo "     to point to $SERVER_IP."
echo ""
echo "4. EMAIL CONFIGURATION:"
echo "   - Default user created manually via shell if needed."
echo "   - Add user: useradd -m -s /bin/bash newuser && passwd newuser"
echo ""
echo "5. SSL CERTIFICATES:"
echo "   To enable HTTPS, run:"
echo "   certbot --nginx -d $DOMAIN_NAME -d www.$DOMAIN_NAME -d mail.$DOMAIN_NAME"
echo ""
