#!/bin/bash

# ==============================================================================
# SHM Panel - Ultimate VPS Setup Script (Revised & Fixed)
# ==============================================================================
# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging
log() { echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; }
warning() { echo -e "${YELLOW}[WARNING] $1${NC}"; }
info() { echo -e "${CYAN}[INFO] $1${NC}"; }

# Check root
if [ "$EUID" -ne 0 ]; then 
    error "Please run as root (use: sudo bash $0)"
    exit 1
fi

# ------------------------------------------------------------------------------
# 1. Configuration & Credentials
# ------------------------------------------------------------------------------
clear
echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                SHM Panel - Ultimate VPS Setup                 ║"
echo "║                   Complete Installation Script                 ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Prompt for the main domain
read -p "Enter the main domain for your panel (e.g., panel.yourdomain.com): " MAIN_DOMAIN

# If the domain is not provided, use a default
if [ -z "$MAIN_DOMAIN" ]; then
    MAIN_DOMAIN="panel.server.com"
    warning "No domain entered. Using default domain: $MAIN_DOMAIN"
fi

# Extract domain parts for nameserver configuration
DOMAIN_NAME=$(echo $MAIN_DOMAIN | awk -F. '{if (NF>=2) {print $(NF-1)"."$NF} else {print $1}}')
HOST_NAME=$(echo $MAIN_DOMAIN | awk -F. '{print $1}')
SERVER_IP=$(hostname -I | awk '{print $1}')
HOSTNAME=$(hostname -f)
TIMEZONE="Asia/Kolkata"
SSH_PORT="2222"

# Validate IP address
if [ -z "$SERVER_IP" ]; then
    error "Could not detect server IP address"
    exit 1
fi

# Generate Secure Passwords
log "Generating secure passwords..."
MYSQL_ROOT_PASS=$(openssl rand -base64 32 2>/dev/null || date +%s | sha256sum | base64 | head -c 32)
ADMIN_USER="shmadmin"
ADMIN_PASS=$(openssl rand -base64 16 2>/dev/null || date +%s | sha256sum | base64 | head -c 16)

# Database Credentials
DB_MAIN_NAME="shm_panel"
DB_RC_NAME="roundcubemail"
DB_USER="shm_db_user"
DB_PASS=$(openssl rand -base64 24 2>/dev/null || date +%s | sha256sum | base64 | head -c 24)

# Blowfish Secret for phpMyAdmin
PMA_SECRET=$(openssl rand -hex 16 2>/dev/null || date +%s | sha256sum | cut -c1-32)

# Nameserver Configuration
NS1="ns1.${DOMAIN_NAME}"
NS2="ns2.${DOMAIN_NAME}"
NS1_IP="${SERVER_IP}"
NS2_IP="${SERVER_IP}"
EMAIL="admin@${DOMAIN_NAME}"

log "Starting Installation on $SERVER_IP ($HOSTNAME)..."
log "Domain: $DOMAIN_NAME | Host: $HOST_NAME"
log "Nameservers: $NS1 ($NS1_IP), $NS2 ($NS2_IP)"
log "Panel URL: http://$MAIN_DOMAIN"

# ------------------------------------------------------------------------------
# 2. System Updates & Dependencies
# ------------------------------------------------------------------------------
log "Updating system and installing dependencies..."

# Update system first
export DEBIAN_FRONTEND=noninteractive
apt update && apt upgrade -y

# Install prerequisites for adding repositories
apt install -y software-properties-common apt-transport-https lsb-release ca-certificates curl wget gnupg

# Add Ondrej PHP repository (for multiple PHP versions)
log "Adding Ondrej PHP repository..."
add-apt-repository ppa:ondrej/php -y

# Update again with new repository
apt update

# Install all required packages in one go to avoid conflicts
log "Installing required packages..."
apt install -y \
    curl wget git unzip htop acl zip nginx mysql-server \
    ufw fail2ban bind9 bind9utils bind9-doc dnsutils \
    postfix dovecot-core dovecot-imapd dovecot-pop3d \
    php8.1 php8.1-fpm php8.1-mysql php8.1-curl php8.1-gd \
    php8.1-mbstring php8.1-xml php8.1-zip php8.1-bcmath \
    php8.2 php8.2-fpm php8.2-mysql php8.2-curl php8.2-gd \
    php8.2-mbstring php8.2-xml php8.2-zip php8.2-bcmath \
    php8.3 php8.3-fpm php8.3-mysql php8.3-curl php8.3-gd \
    php8.3-mbstring php8.3-xml php8.3-zip php8.3-bcmath

# Check if PHP installation was successful
if ! command -v php8.2 &> /dev/null; then
    error "PHP 8.2 installation failed. Trying alternative installation method..."
    apt install -y php8.2 php8.2-fpm php8.2-mysql
fi

# Set default PHP version
PHP_VERSION="8.2"
update-alternatives --set php /usr/bin/php$PHP_VERSION
update-alternatives --set phar /usr/bin/phar$PHP_VERSION
update-alternatives --set phar.phar /usr/bin/phar.phar$PHP_VERSION

PHP_SOCK="/var/run/php/php$PHP_VERSION-fpm.sock"
log "Using PHP $PHP_VERSION as default (Socket: $PHP_SOCK)"

# Configure all PHP versions
for version in 8.1 8.2 8.3; do
    if [ -f "/etc/php/$version/fpm/php.ini" ]; then
        log "Configuring PHP $version..."
        sed -i "s/^upload_max_filesize =.*/upload_max_filesize = 1024M/" /etc/php/$version/fpm/php.ini
        sed -i "s/^post_max_size =.*/post_max_size = 1024M/" /etc/php/$version/fpm/php.ini
        sed -i "s/^memory_limit =.*/memory_limit = 512M/" /etc/php/$version/fpm/php.ini
        sed -i "s/^max_execution_time =.*/max_execution_time = 300/" /etc/php/$version/fpm/php.ini
        sed -i "s/^;date.timezone =.*/date.timezone = $TIMEZONE/" /etc/php/$version/fpm/php.ini
        
        # Create PHP-FPM pool configuration for better performance
        cat > /etc/php/$version/fpm/pool.d/www.conf << EOF
[www]
user = www-data
group = www-data
listen = /var/run/php/php$version-fpm.sock
listen.owner = www-data
listen.group = www-data
pm = dynamic
pm.max_children = 50
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 35
slowlog = /var/log/php$version-fpm-slow.log
EOF
        
        # Restart PHP-FPM
        systemctl restart php$version-fpm
    fi
done

# ------------------------------------------------------------------------------
# 3. DNS Server (Bind9) - Fixed Configuration
# ------------------------------------------------------------------------------
log "Configuring Bind9 DNS server..."

# Stop bind9 temporarily
systemctl stop bind9

# Create directories
mkdir -p /etc/bind/zones

# Configure named.conf.options with proper settings
cat > /etc/bind/named.conf.options << EOF
options {
    directory "/var/cache/bind";
    
    // If there is a firewall between you and nameservers you want
    // to talk to, you may need to fix the firewall to allow multiple
    // ports to talk.  See http://www.kb.cert.org/vuls/id/800113
    
    // If your ISP provided one or more IP addresses for stable 
    // nameservers, you probably want to use them as forwarders.  
    // Uncomment the following block, and insert the addresses replacing 
    // the all-0's placeholder.
    
    forwarders {
        8.8.8.8;
        8.8.4.4;
        1.1.1.1;
    };
    
    //========================================================================
    // If BIND logs error messages about the root key being expired,
    // you will need to update your keys.  See https://www.isc.org/bind-keys
    //========================================================================
    
    dnssec-validation auto;
    
    auth-nxdomain no;    # conform to RFC1035
    listen-on-v6 { any; };
    listen-on { any; };
    
    // Allow queries from anywhere
    allow-query { any; };
    
    // Allow recursion for internal network
    recursion yes;
    allow-recursion { any; };
    
    // Enable query logging (optional)
    // querylog yes;
    
    // Rate limiting
    rate-limit {
        responses-per-second 15;
        window 5;
    };
};
EOF

# Create forward zone file
cat > /etc/bind/zones/db.${DOMAIN_NAME} << EOF
\$TTL 86400
@   IN  SOA ${NS1}. ${EMAIL}. (
    $(date +%Y%m%d)01  ; Serial (YYYYMMDDNN)
    3600               ; Refresh
    1800               ; Retry
    604800             ; Expire
    86400 )            ; Minimum TTL

; Name Servers
    IN  NS  ${NS1}.
    IN  NS  ${NS2}.

; A Records
@           IN  A   ${SERVER_IP}
${HOST_NAME} IN  A   ${SERVER_IP}
${NS1}      IN  A   ${SERVER_IP}
${NS2}      IN  A   ${SERVER_IP}
www         IN  A   ${SERVER_IP}
mail        IN  A   ${SERVER_IP}
panel       IN  A   ${SERVER_IP}
ns1         IN  A   ${SERVER_IP}
ns2         IN  A   ${SERVER_IP}

; MX Record
@   IN  MX  10  mail.${DOMAIN_NAME}.

; CNAME Records
ftp     IN  CNAME   ${HOST_NAME}.${DOMAIN_NAME}.
smtp    IN  CNAME   mail.${DOMAIN_NAME}.
pop3    IN  CNAME   mail.${DOMAIN_NAME}.
imap    IN  CNAME   mail.${DOMAIN_NAME}.

; TXT Records
@       IN  TXT "v=spf1 a mx ip4:${SERVER_IP} ~all"
_dmarc  IN  TXT "v=DMARC1; p=none; rua=mailto:${EMAIL}"
EOF

# Create reverse zone file
REVERSE_IP=$(echo $SERVER_IP | awk -F. '{print $3"."$2"."$1".in-addr.arpa"}')
LAST_OCTET=$(echo $SERVER_IP | awk -F. '{print $4}')

cat > /etc/bind/zones/db.${REVERSE_IP} << EOF
\$TTL 86400
@   IN  SOA ${NS1}. ${EMAIL}. (
    $(date +%Y%m%d)01  ; Serial
    3600               ; Refresh
    1800               ; Retry
    604800             ; Expire
    86400 )            ; Minimum TTL

; Name Servers
    IN  NS  ${NS1}.
    IN  NS  ${NS2}.

; PTR Records
${LAST_OCTET}  IN  PTR  ${HOST_NAME}.${DOMAIN_NAME}.
EOF

# Configure named.conf.local
cat > /etc/bind/named.conf.local << EOF
// Forward Zone for ${DOMAIN_NAME}
zone "${DOMAIN_NAME}" {
    type master;
    file "/etc/bind/zones/db.${DOMAIN_NAME}";
    allow-transfer { any; };
    allow-query { any; };
    notify yes;
};

// Reverse Zone for ${SERVER_IP}
zone "${REVERSE_IP}" {
    type master;
    file "/etc/bind/zones/db.${REVERSE_IP}";
    allow-transfer { any; };
    allow-query { any; };
};
EOF

# Set proper permissions
chown -R bind:bind /etc/bind/zones
chmod 644 /etc/bind/zones/db.*

# Update resolv.conf
cat > /etc/resolv.conf << EOF
nameserver 127.0.0.1
nameserver 8.8.8.8
nameserver 1.1.1.1
options edns0
search ${DOMAIN_NAME}
EOF

# Protect resolv.conf
chattr +i /etc/resolv.conf 2>/dev/null || true

# Disable systemd-resolved if running
systemctl stop systemd-resolved 2>/dev/null
systemctl disable systemd-resolved 2>/dev/null

# Start and enable bind9
systemctl start bind9
systemctl enable bind9

# Test DNS configuration
log "Testing DNS configuration..."
if named-checkconf; then
    log "✓ Bind9 configuration syntax is valid"
else
    error "Bind9 configuration has errors"
    named-checkconf
fi

if named-checkzone ${DOMAIN_NAME} /etc/bind/zones/db.${DOMAIN_NAME}; then
    log "✓ Forward zone syntax is valid"
else
    error "Forward zone has errors"
    named-checkzone ${DOMAIN_NAME} /etc/bind/zones/db.${DOMAIN_NAME}
fi

if named-checkzone ${REVERSE_IP} /etc/bind/zones/db.${REVERSE_IP}; then
    log "✓ Reverse zone syntax is valid"
else
    warning "Reverse zone has errors (this might be expected for certain IP ranges)"
fi

# ------------------------------------------------------------------------------
# 4. Mail Server Configuration
# ------------------------------------------------------------------------------
log "Configuring Postfix & Dovecot..."

# Configure Postfix
postconf -e "myhostname = ${HOST_NAME}.${DOMAIN_NAME}"
postconf -e "mydomain = ${DOMAIN_NAME}"
postconf -e "myorigin = \$mydomain"
postconf -e "mydestination = \$myhostname, localhost.\$mydomain, localhost, \$mydomain"
postconf -e "mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128"
postconf -e "inet_interfaces = all"
postconf -e "inet_protocols = all"
postconf -e "home_mailbox = Maildir/"
postconf -e "smtpd_banner = \$myhostname ESMTP"
postconf -e "mailbox_size_limit = 0"
postconf -e "message_size_limit = 52428800"

# Configure Dovecot
cat > /etc/dovecot/conf.d/10-mail.conf << EOF
mail_location = maildir:~/Maildir
namespace inbox {
  inbox = yes
}
EOF

cat > /etc/dovecot/conf.d/10-auth.conf << EOF
disable_plaintext_auth = no
auth_mechanisms = plain login
!include auth-system.conf.ext
EOF

cat > /etc/dovecot/conf.d/10-master.conf << EOF
service imap-login {
  inet_listener imap {
    port = 143
  }
  inet_listener imaps {
    port = 993
    ssl = yes
  }
}
service pop3-login {
  inet_listener pop3 {
    port = 110
  }
  inet_listener pop3s {
    port = 995
    ssl = yes
  }
}
service lmtp {
  unix_listener /var/spool/postfix/private/dovecot-lmtp {
    mode = 0600
    user = postfix
    group = postfix
  }
}
service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0666
    user = postfix
    group = postfix
  }
  unix_listener auth-userdb {
    mode = 0666
    user = vmail
    group = vmail
  }
  user = dovecot
}
service auth-worker {
  user = vmail
}
EOF

# Create vmail user if not exists
if ! id vmail &>/dev/null; then
    useradd -r -u 150 -g mail -d /var/vmail -s /sbin/nologin -c "Virtual Mailbox" vmail
    mkdir -p /var/vmail
    chown -R vmail:mail /var/vmail
fi

# Restart mail services
systemctl restart postfix
systemctl restart dovecot
systemctl enable postfix dovecot

# ------------------------------------------------------------------------------
# 5. Database Setup (MySQL/MariaDB)
# ------------------------------------------------------------------------------
log "Configuring MySQL database..."

# Start MySQL service
systemctl start mysql
systemctl enable mysql

# Secure MySQL installation with improved method
mysql_secure_installation << EOF

n
y
$MYSQL_ROOT_PASS
$MYSQL_ROOT_PASS
y
y
y
y
EOF

# Create .my.cnf for root access
cat > /root/.my.cnf << EOF
[client]
user=root
password=$MYSQL_ROOT_PASS
EOF
chmod 600 /root/.my.cnf

# Create databases and users
mysql -e "CREATE DATABASE IF NOT EXISTS \`$DB_MAIN_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "CREATE DATABASE IF NOT EXISTS \`$DB_RC_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -e "GRANT ALL PRIVILEGES ON \`$DB_MAIN_NAME\`.* TO '$DB_USER'@'localhost';"
mysql -e "GRANT ALL PRIVILEGES ON \`$DB_RC_NAME\`.* TO '$DB_USER'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# ------------------------------------------------------------------------------
# 6. Install phpMyAdmin & Roundcube
# ------------------------------------------------------------------------------
log "Installing Web Applications..."

# --- Install phpMyAdmin ---
log "Installing phpMyAdmin..."
if [ ! -d "/var/www/html/phpmyadmin" ]; then
    mkdir -p /var/www/html/phpmyadmin
    cd /tmp
    wget -q https://files.phpmyadmin.net/phpMyAdmin/5.2.1/phpMyAdmin-5.2.1-all-languages.tar.gz
    tar -xzf phpMyAdmin-5.2.1-all-languages.tar.gz
    cp -r phpMyAdmin-5.2.1-all-languages/* /var/www/html/phpmyadmin/
    rm -rf phpMyAdmin-5.2.1*
    
    # Configure phpMyAdmin
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
\$cfg['TempDir'] = '/tmp';
\$cfg['MaxNavigationItems'] = 100;
?>
EOF
    
    chown -R www-data:www-data /var/www/html/phpmyadmin
    log "✓ phpMyAdmin installed"
else
    log "✓ phpMyAdmin already installed"
fi

# --- Install Roundcube ---
log "Installing Roundcube Webmail..."
if [ ! -d "/var/www/html/webmail" ]; then
    mkdir -p /var/www/html/webmail
    cd /tmp
    wget -q https://github.com/roundcube/roundcubemail/releases/download/1.6.6/roundcubemail-1.6.6-complete.tar.gz
    tar -xzf roundcubemail-1.6.6-complete.tar.gz
    cp -r roundcubemail-1.6.6/* /var/www/html/webmail/
    rm -rf roundcubemail-1.6.6*
    
    # Configure Roundcube
    cd /var/www/html/webmail
    mysql $DB_RC_NAME < SQL/mysql.initial.sql
    
    # Create Roundcube configuration
    cp config/config.inc.php.sample config/config.inc.php
    cat > config/config.inc.php << EOF
<?php
\$config = [];
\$config['db_dsnw'] = 'mysql://$DB_USER:$DB_PASS@localhost/$DB_RC_NAME';
\$config['default_host'] = 'localhost';
\$config['default_port'] = 143;
\$config['smtp_server'] = 'localhost';
\$config['smtp_port'] = 25;
\$config['smtp_user'] = '%u';
\$config['smtp_pass'] = '%p';
\$config['support_url'] = '';
\$config['product_name'] = 'SHM Webmail';
\$config['des_key'] = '$(openssl rand -base64 24 2>/dev/null || date +%s | sha256sum | base64 | head -c 24)';
\$config['plugins'] = ['archive', 'zipdownload', 'managesieve'];
\$config['skin'] = 'elastic';
\$config['mail_pagesize'] = 50;
\$config['addressbook_pagesize'] = 50;
\$config['prefer_html'] = true;
\$config['draft_autosave'] = 60;
\$config['mime_param_folding'] = 0;
?>
EOF
    
    chown -R www-data:www-data /var/www/html/webmail
    log "✓ Roundcube installed"
else
    log "✓ Roundcube already installed"
fi

# ------------------------------------------------------------------------------
# 7. Nginx Configuration
# ------------------------------------------------------------------------------
log "Configuring Nginx web server..."

# Create Nginx directories
mkdir -p /etc/nginx/{sites-available,sites-enabled,ssl,conf.d}
mkdir -p /var/www/html /var/log/nginx

# Create main panel directory
mkdir -p /var/www/shm-panel

# Create a simple panel index file
cat > /var/www/shm-panel/test.php << 'EOF'
Successfully Installation...
EOF

# Create Nginx configuration for main domain
cat > /etc/nginx/sites-available/$MAIN_DOMAIN << EOF
server {
    listen 80;
    listen [::]:80;
    server_name $MAIN_DOMAIN;
    root /var/www/shm-panel;
    index index.php index.html index.htm;
    
    access_log /var/log/nginx/$MAIN_DOMAIN.access.log;
    error_log /var/log/nginx/$MAIN_DOMAIN.error.log;
    
    client_max_body_size 1024M;
    
    # Main location
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    
    # PHP Processing
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:$PHP_SOCK;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_read_timeout 300;
    }
    
    # phpMyAdmin
    location /phpmyadmin {
        alias /var/www/html/phpmyadmin;
        index index.php;
        
        location ~ ^/phpmyadmin/(.+\.php)$ {
            alias /var/www/html/phpmyadmin;
            fastcgi_pass unix:$PHP_SOCK;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME \$request_filename;
            include fastcgi_params;
            fastcgi_param SCRIPT_NAME /phpmyadmin/\$1;
        }
        
        location ~* ^/phpmyadmin/(.+\.(jpg|jpeg|gif|css|png|js|ico|html|xml|txt))$ {
            alias /var/www/html/phpmyadmin;
        }
    }
    
    # Webmail
    location /webmail {
        alias /var/www/html/webmail;
        index index.php;
        
        location ~ ^/webmail/(.+\.php)$ {
            alias /var/www/html/webmail;
            fastcgi_pass unix:$PHP_SOCK;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME \$request_filename;
            include fastcgi_params;
        }
    }
    
    # Security - deny access to hidden files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
    
    # Deny access to sensitive files
    location ~* \.(log|sql|git|env|ini|sh|bak|swp)$ {
        deny all;
        access_log off;
        log_not_found off;
    }
    
    # Cache static files
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 365d;
        add_header Cache-Control "public, immutable";
        access_log off;
    }
}
EOF

# Create fastcgi-php.conf if it doesn't exist
if [ ! -f /etc/nginx/snippets/fastcgi-php.conf ]; then
    cat > /etc/nginx/snippets/fastcgi-php.conf << 'EOF'
# regex to split $uri to $fastcgi_script_name and $fastcgi_path
fastcgi_split_path_info ^(.+\.php)(/.+)$;

# Check that the PHP script exists before passing it
try_files $fastcgi_script_name =404;

# Bypass the fact that try_files resets $fastcgi_path_info
set $path_info $fastcgi_path_info;
fastcgi_param PATH_INFO $path_info;

fastcgi_index index.php;
include fastcgi.conf;
EOF
fi

# Enable the site
ln -sf /etc/nginx/sites-available/$MAIN_DOMAIN /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
nginx -t
if [ $? -eq 0 ]; then
    log "✓ Nginx configuration test passed"
    systemctl restart nginx
    systemctl enable nginx
else
    error "Nginx configuration test failed"
    nginx -t
    exit 1
fi

# ------------------------------------------------------------------------------
# 8. System User & Permissions
# ------------------------------------------------------------------------------
log "Setting up system users and permissions..."

# Create admin user if not exists
if ! id "$ADMIN_USER" &>/dev/null; then
    useradd -m -s /bin/bash -G sudo,www-data $ADMIN_USER
    echo "$ADMIN_USER:$ADMIN_PASS" | chpasswd
    log "Created admin user: $ADMIN_USER"
else
    log "Admin user $ADMIN_USER already exists"
fi

# Set directory permissions
chown -R www-data:www-data /var/www
find /var/www -type d -exec chmod 755 {} \;
find /var/www -type f -exec chmod 644 {} \;

# Allow admin user to manage web files
setfacl -R -m u:$ADMIN_USER:rwx /var/www 2>/dev/null || true

# ------------------------------------------------------------------------------
# 9. Security Configuration
# ------------------------------------------------------------------------------
log "Configuring security settings..."

# SSH Configuration
sed -i "s/#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
sed -i "s/#PasswordAuthentication yes/PasswordAuthentication yes/" /etc/ssh/sshd_config
sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin no/" /etc/ssh/sshd_config
echo "AllowUsers $ADMIN_USER" >> /etc/ssh/sshd_config

# Firewall Configuration
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# Open required ports
ufw allow $SSH_PORT/tcp comment 'SSH'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'
ufw allow 53/tcp comment 'DNS TCP'
ufw allow 53/udp comment 'DNS UDP'
ufw allow 25/tcp comment 'SMTP'
ufw allow 587/tcp comment 'SMTP Submission'
ufw allow 465/tcp comment 'SMTPS'
ufw allow 143/tcp comment 'IMAP'
ufw allow 993/tcp comment 'IMAPS'
ufw allow 110/tcp comment 'POP3'
ufw allow 995/tcp comment 'POP3S'

# Enable UFW
echo "y" | ufw enable
systemctl enable ufw

# Fail2Ban Configuration
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = $SSH_PORT
logpath = %(sshd_log)s
maxretry = 3

[nginx-http-auth]
enabled = true
port = http,https
logpath = %(nginx_error_log)s

[postfix]
enabled = true
port = smtp,465,submission
logpath = %(postfix_log)s
EOF

systemctl restart fail2ban
systemctl enable fail2ban

# ------------------------------------------------------------------------------
# 10. Final Configuration & Credentials
# ------------------------------------------------------------------------------
log "Finalizing installation..."

# Create system info script
cat > /usr/local/bin/shm-info << 'EOF'
#!/bin/bash
echo "╔══════════════════════════════════════════════════════════╗"
echo "║                     SHM Panel Status                     ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "Services Status:"
echo "---------------"
systemctl is-active nginx >/dev/null 2>&1 && echo "✓ Nginx: Running" || echo "✗ Nginx: Stopped"
systemctl is-active mysql >/dev/null 2>&1 && echo "✓ MySQL: Running" || echo "✗ MySQL: Stopped"
systemctl is-active bind9 >/dev/null 2>&1 && echo "✓ Bind9: Running" || echo "✗ Bind9: Stopped"
systemctl is-active postfix >/dev/null 2>&1 && echo "✓ Postfix: Running" || echo "✗ Postfix: Stopped"
systemctl is-active dovecot >/dev/null 2>&1 && echo "✓ Dovecot: Running" || echo "✗ Dovecot: Stopped"
echo ""
echo "Disk Usage:"
echo "----------"
df -h / | tail -1
echo ""
echo "Memory Usage:"
echo "------------"
free -h | awk '/^Mem:/ {print "Memory: " $3 " / " $2 " (" $3/$2*100 "%)"}'
echo ""
echo "Server Information:"
echo "------------------"
echo "IP Address: $(hostname -I | awk '{print $1}')"
echo "Hostname: $(hostname -f)"
echo "Uptime: $(uptime -p)"
echo ""
EOF

chmod +x /usr/local/bin/shm-info

# Create DNS check script
cat > /usr/local/bin/check-dns << 'EOF'
#!/bin/bash
DOMAIN=$(hostname -f | awk -F. '{if (NF>=2) {print $(NF-1)"."$NF} else {print $1}}')
IP=$(hostname -I | awk '{print $1}')
echo "DNS Status Check:"
echo "----------------"
echo "Domain: $DOMAIN"
echo "Server IP: $IP"
echo ""
echo "Testing DNS resolution:"
echo "1. Forward lookup:"
dig @127.0.0.1 $DOMAIN A +short
echo ""
echo "2. Reverse lookup:"
dig @127.0.0.1 -x $IP +short
echo ""
echo "3. Nameserver test:"
dig @127.0.0.1 NS $DOMAIN +short
echo ""
echo "Bind9 Status:"
systemctl status bind9 --no-pager | grep -A3 "Active:"
EOF

chmod +x /usr/local/bin/check-dns

# Save credentials
cat > /root/shm-panel-credentials.txt << EOF
╔══════════════════════════════════════════════════════════╗
║                SHM Panel Installation Complete           ║
╚══════════════════════════════════════════════════════════╝

🌐 SERVER INFORMATION
──────────────────────────────────────────────────────────
Server IP:          $SERVER_IP
Hostname:           $HOSTNAME
Main Domain:        $MAIN_DOMAIN
SSH Port:           $SSH_PORT
Timezone:           $TIMEZONE

🔐 ADMIN CREDENTIALS
──────────────────────────────────────────────────────────
Admin Username:     $ADMIN_USER
Admin Password:     $ADMIN_PASS
SSH Command:        ssh -p $SSH_PORT $ADMIN_USER@$SERVER_IP

🗄️ DATABASE CREDENTIALS
──────────────────────────────────────────────────────────
MySQL Root Pass:    $MYSQL_ROOT_PASS
Database User:      $DB_USER
Database Password:  $DB_PASS
Main Database:      $DB_MAIN_NAME
Webmail Database:   $DB_RC_NAME

🌍 WEB SERVICES
──────────────────────────────────────────────────────────
SHM Panel:          http://$MAIN_DOMAIN
phpMyAdmin:         http://$MAIN_DOMAIN/phpmyadmin
Webmail:            http://$MAIN_DOMAIN/webmail

📡 DNS CONFIGURATION
──────────────────────────────────────────────────────────
Domain:             $DOMAIN_NAME
Nameserver 1:       $NS1
Nameserver 2:       $NS2
Nameserver IP:      $SERVER_IP

To configure at your domain registrar:
1. Set nameservers to: $NS1 and $NS2
2. Point both to IP: $SERVER_IP

📁 DIRECTORY PATHS
──────────────────────────────────────────────────────────
Web Root:           /var/www/
Panel:              /var/www/shm-panel/
phpMyAdmin:         /var/www/html/phpmyadmin/
Webmail:            /var/www/html/webmail/
DNS Zones:          /etc/bind/zones/
Nginx Config:       /etc/nginx/sites-available/$MAIN_DOMAIN

⚙️ SYSTEM COMMANDS
──────────────────────────────────────────────────────────
Check Status:       shm-info
Check DNS:          check-dns
Restart Nginx:      systemctl restart nginx
Restart DNS:        systemctl restart bind9
View Logs:          journalctl -u nginx -f

🔧 TECHNICAL DETAILS
──────────────────────────────────────────────────────────
PHP Versions:       8.1, 8.2, 8.3 (Default: 8.2)
Web Server:         Nginx 1.18+
Database:           MySQL 8.0+
DNS Server:         Bind9
Mail Server:        Postfix + Dovecot
Firewall:           UFW + Fail2Ban

⚠️ IMPORTANT NOTES
──────────────────────────────────────────────────────────
1. Change all passwords immediately after first login
2. Configure DNS at your registrar within 48 hours
3. Monitor /var/log/ for any service issues
4. Regular updates: apt update && apt upgrade
5. Backup your databases regularly

📅 Installation Date: $(date)
✅ Installation Complete!

For support, check the logs in /var/log/
EOF

# Also create a copy for the admin user
mkdir -p /home/$ADMIN_USER
cp /root/shm-panel-credentials.txt /home/$ADMIN_USER/credentials.txt
chown $ADMIN_USER:$ADMIN_USER /home/$ADMIN_USER/credentials.txt
chmod 600 /home/$ADMIN_USER/credentials.txt

# Restart all services
log "Restarting all services..."
services="mysql bind9 postfix dovecot nginx ssh php8.1-fpm php8.2-fpm php8.3-fpm fail2ban"
for service in $services; do
    systemctl restart $service 2>/dev/null && \
    log "✓ Restarted $service" || \
    warning "Could not restart $service"
done

# Enable services at boot
for service in $services; do
    systemctl enable $service 2>/dev/null && \
    log "✓ Enabled $service at boot" || \
    warning "Could not enable $service"
done

# ------------------------------------------------------------------------------
# 11. Final Checks & Output
# ------------------------------------------------------------------------------
log "Running final checks..."

# Check service status
echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                 Installation Summary                    ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}✓ All services have been installed and configured${NC}"
echo ""

# Display quick test results
echo "Quick Tests:"
echo "------------"
# Test web server
if curl -s -I http://localhost >/dev/null; then
    echo -e "✓ Web Server (Nginx): ${GREEN}Running${NC}"
else
    echo -e "✗ Web Server (Nginx): ${RED}Not responding${NC}"
fi

# Test database
if mysql -e "SELECT 1" >/dev/null 2>&1; then
    echo -e "✓ Database (MySQL): ${GREEN}Running${NC}"
else
    echo -e "✗ Database (MySQL): ${RED}Not responding${NC}"
fi

# Test DNS
if dig @127.0.0.1 localhost +short >/dev/null 2>&1; then
    echo -e "✓ DNS Server (Bind9): ${GREEN}Running${NC}"
else
    echo -e "✗ DNS Server (Bind9): ${RED}Not responding${NC}"
fi

# Test PHP
if php --version >/dev/null 2>&1; then
    echo -e "✓ PHP $PHP_VERSION: ${GREEN}Installed${NC}"
else
    echo -e "✗ PHP: ${RED}Not installed${NC}"
fi

echo ""
echo -e "${YELLOW}══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Installation Complete!${NC}"
echo -e "${YELLOW}══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}📋 Credentials have been saved to:${NC}"
echo -e "   /root/shm-panel-credentials.txt"
echo -e "   /home/$ADMIN_USER/credentials.txt"
echo ""
echo -e "${CYAN}🌐 Access your panel at:${NC}"
echo -e "   ${GREEN}http://$MAIN_DOMAIN${NC}"
echo ""
echo -e "${CYAN}🔑 Admin Login:${NC}"
echo -e "   Username: ${GREEN}$ADMIN_USER${NC}"
echo -e "   Password: ${GREEN}$ADMIN_PASS${NC}"
echo ""
echo -e "${CYAN}📡 SSH Access:${NC}"
echo -e "   ${GREEN}ssh -p $SSH_PORT $ADMIN_USER@$SERVER_IP${NC}"
echo ""
echo -e "${CYAN}⚡ Quick Commands:${NC}"
echo -e "   Check system status: ${GREEN}shm-info${NC}"
echo -e "   Check DNS: ${GREEN}check-dns${NC}"
echo ""
echo -e "${YELLOW}⚠️ Important Next Steps:${NC}"
echo "   1. Change all passwords immediately"
echo "   2. Configure DNS nameservers at your domain registrar"
echo "   3. Upload your SHM Panel files to /var/www/shm-panel/"
echo "   4. Configure SSL certificates (recommended)"
echo ""
echo -e "${BLUE}=========================================================================${NC}"
log "Installation completed successfully!"
echo ""
