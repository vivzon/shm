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
DOMAIN_NAME=$(hostname)
TIMEZONE="Asia/Kolkata"
ADMIN_USER="shmadmin"
SSH_PORT="2222"
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)
APP_USER="shmuser"
APP_USER_PASSWORD=$(openssl rand -base64 16)
PHPMYADMIN_PASSWORD=$(openssl rand -base64 16)

log "Starting VPS Server Setup for SHM Panel"
log "Server IP: $SERVER_IP"
log "Domain: $DOMAIN_NAME"

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

# Install additional PHP extensions for phpMyAdmin and mail
apt install -y \
    php-imagick php-phpseclib php-psr-cache \
    php-psr-container php-psr-log \
    php-symfony-cache php-symfony-expression-language

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
    mkdir -p /root/.secure
    echo "Admin User: $ADMIN_USER" > /root/.secure/server_credentials.txt
    echo "Admin Password: $ADMIN_PASSWORD" >> /root/.secure/server_credentials.txt
    echo "App User: $APP_USER" >> /root/.secure/server_credentials.txt
    echo "App Password: $APP_USER_PASSWORD" >> /root/.secure/server_credentials.txt
    echo "MySQL Root Password: $MYSQL_ROOT_PASSWORD" >> /root/.secure/server_credentials.txt
    echo "phpMyAdmin Password: $PHPMYADMIN_PASSWORD" >> /root/.secure/server_credentials.txt
    chmod 600 /root/.secure/server_credentials.txt
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
ufw allow 53
ufw allow 53/udp
ufw allow 25
ufw allow 587
ufw allow 465
ufw allow 993
ufw allow 995
ufw allow 110
ufw allow 143
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

[postfix]
enabled = true
port = smtp,ssmtp,submission
logpath = /var/log/mail.log

[dovecot]
enabled = true
port = pop3,pop3s,imap,imaps
logpath = /var/log/mail.log
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

# Install and configure phpMyAdmin
log "Installing phpMyAdmin..."
debconf-set-selections <<< "phpmyadmin phpmyadmin/reconfigure-webserver multiselect nginx"
debconf-set-selections <<< "phpmyadmin phpmyadmin/dbconfig-install boolean true"
debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/admin-pass password $MYSQL_ROOT_PASSWORD"
debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/app-pass password $PHPMYADMIN_PASSWORD"
debconf-set-selections <<< "phpmyadmin phpmyadmin/app-password-confirm password $PHPMYADMIN_PASSWORD"

apt install -y phpmyadmin

# Create phpMyAdmin nginx configuration
cat > /etc/nginx/conf.d/phpmyadmin.conf << EOF
server {
    listen 8080;
    server_name $SERVER_IP;
    
    root /usr/share/phpmyadmin;
    index index.php index.html index.htm;
    
    access_log /var/log/nginx/phpmyadmin.access.log;
    error_log /var/log/nginx/phpmyadmin.error.log;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    location ~ ^/(doc|sql|setup)/ {
        deny all;
    }
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php$PHP_VERSION-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
    
    location ~ /\.ht {
        deny all;
    }
}
EOF

# Secure phpMyAdmin
cat > /usr/share/phpmyadmin/.htaccess << EOF
AuthType Basic
AuthName "Restricted Files"
AuthUserFile /etc/phpmyadmin/.htpasswd
Require valid-user
EOF

# Create phpMyAdmin admin user
htpasswd -bc /etc/phpmyadmin/.htpasswd admin $PHPMYADMIN_PASSWORD

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
sendmail_path = /usr/sbin/sendmail -t -i
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

# Install and configure Mail Server (Postfix + Dovecot)
log "Installing and configuring Mail Server..."
apt install -y postfix dovecot-core dovecot-imapd dovecot-pop3d dovecot-mysql

# Configure Postfix
log "Configuring Postfix..."
postconf -e "myhostname = $DOMAIN_NAME"
postconf -e "mydestination = \$myhostname, localhost.\$mydomain, localhost"
postconf -e "myorigin = \$mydomain"
postconf -e "mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128"
postconf -e "home_mailbox = Maildir/"
postconf -e "smtpd_banner = \$myhostname ESMTP"
postconf -e "mailbox_size_limit = 0"
postconf -e "message_size_limit = 104857600"
postconf -e "smtpd_tls_security_level = may"
postconf -e "smtpd_tls_auth_only = yes"
postconf -e "smtpd_tls_cert_file = /etc/ssl/certs/ssl-cert-snakeoil.pem"
postconf -e "smtpd_tls_key_file = /etc/ssl/private/ssl-cert-snakeoil.key"

# Configure Dovecot
log "Configuring Dovecot..."
cat > /etc/dovecot/conf.d/10-mail.conf << EOF
mail_location = maildir:~/Maildir
namespace inbox {
  inbox = yes
}
EOF

cat > /etc/dovecot/conf.d/10-auth.conf << EOF
disable_plaintext_auth = yes
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
  unix_listener lmtp {
    mode = 0666
  }
}

service imap {
}

service pop3 {
}

service auth {
  unix_listener auth-userdb {
    mode = 0666
    user = postfix
    group = postfix
  }
}

service auth-worker {
  user = root
}
EOF

# Install and configure BIND9 DNS Server
log "Installing and configuring BIND9 DNS Server..."
apt install -y bind9 bind9utils bind9-doc

# Configure BIND options
cat > /etc/bind/named.conf.options << EOF
options {
    directory "/var/cache/bind";
    listen-on { any; };
    listen-on-v6 { any; };
    forwarders {
        8.8.8.8;
        8.8.4.4;
        1.1.1.1;
    };
    allow-query { any; };
    recursion yes;
    allow-recursion { any; };
    dnssec-validation auto;
    auth-nxdomain no;
    listen-on port 53 { any; };
};
EOF

# Create primary zone configuration
cat > /etc/bind/named.conf.local << EOF
// Primary zone for $DOMAIN_NAME
zone "$DOMAIN_NAME" {
    type master;
    file "/etc/bind/db.$DOMAIN_NAME";
};

// Reverse zone for $SERVER_IP
zone "$(echo $SERVER_IP | cut -d. -f3- | awk -F. '{print $2"."$1}').in-addr.arpa" {
    type master;
    file "/etc/bind/db.$(echo $SERVER_IP | cut -d. -f1-3)";
};
EOF

# Create forward zone file
cat > /etc/bind/db.$DOMAIN_NAME << EOF
\$TTL    604800
@       IN      SOA     ns1.$DOMAIN_NAME. admin.$DOMAIN_NAME. (
                              2024010101    ; Serial
                          604800     ; Refresh
                           86400     ; Retry
                        2419200     ; Expire
                          604800 )   ; Negative Cache TTL

; Name servers
@       IN      NS      ns1.$DOMAIN_NAME.
@       IN      NS      ns2.$DOMAIN_NAME.

; A records
@       IN      A       $SERVER_IP
ns1     IN      A       $SERVER_IP
ns2     IN      A       $SERVER_IP
www     IN      A       $SERVER_IP
mail    IN      A       $SERVER_IP
smtp    IN      A       $SERVER_IP
imap    IN      A       $SERVER_IP
pop     IN      A       $SERVER_IP
webmail IN      A       $SERVER_IP
phpmyadmin IN   A       $SERVER_IP

; MX record
@       IN      MX 10   mail.$DOMAIN_NAME.

; TXT records for mail security
@       IN      TXT     "v=spf1 mx a ~all"
_dmarc  IN      TXT     "v=DMARC1; p=none; rua=mailto:admin@$DOMAIN_NAME"
EOF

# Create reverse zone file
REVERSE_ZONE=$(echo $SERVER_IP | cut -d. -f1-3)
cat > /etc/bind/db.$REVERSE_ZONE << EOF
\$TTL    604800
@       IN      SOA     ns1.$DOMAIN_NAME. admin.$DOMAIN_NAME. (
                              2024010101    ; Serial
                          604800     ; Refresh
                           86400     ; Retry
                        2419200     ; Expire
                          604800 )   ; Negative Cache TTL

; Name servers
@       IN      NS      ns1.$DOMAIN_NAME.
@       IN      NS      ns2.$DOMAIN_NAME.

; PTR records
$(echo $SERVER_IP | cut -d. -f4)       IN      PTR     $DOMAIN_NAME.
$(echo $SERVER_IP | cut -d. -f4)       IN      PTR     ns1.$DOMAIN_NAME.
$(echo $SERVER_IP | cut -d. -f4)       IN      PTR     mail.$DOMAIN_NAME.
EOF

# Set proper permissions for BIND
chown bind:bind /etc/bind/db.*
named-checkconf
named-checkzone $DOMAIN_NAME /etc/bind/db.$DOMAIN_NAME
named-checkzone $(echo $SERVER_IP | cut -d. -f3- | awk -F. '{print $2"."$1}').in-addr.arpa /etc/bind/db.$REVERSE_ZONE

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

# Create webmail configuration (Roundcube)
cat > /etc/nginx/sites-available/webmail << EOF
server {
    listen 8081;
    server_name _;
    root /var/www/webmail;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php$PHP_VERSION-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
    
    client_max_body_size 50M;
}
EOF

# Enable sites
ln -sf /etc/nginx/sites-available/shm-panel /etc/nginx/sites-enabled/
ln -sf /etc/nginx/sites-available/webmail /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Create application directory
log "Creating application directory..."
mkdir -p /var/www/shm-panel
mkdir -p /var/www/webmail
chown -R $APP_USER:www-data /var/www/shm-panel
chown -R $APP_USER:www-data /var/www/webmail
chmod 755 /var/www/shm-panel
chmod 755 /var/www/webmail

# Install Roundcube Webmail
log "Installing Roundcube Webmail..."
cd /tmp
wget -q https://github.com/roundcube/roundcubemail/releases/download/1.6.4/roundcubemail-1.6.4-complete.tar.gz
tar -xzf roundcubemail-1.6.4-complete.tar.gz
mv roundcubemail-1.6.4/* /var/www/webmail/
chown -R www-data:www-data /var/www/webmail
chmod -R 755 /var/www/webmail

# Create Roundcube database
mysql -e "CREATE DATABASE roundcube;"
mysql -e "CREATE USER 'roundcube'@'localhost' IDENTIFIED BY '$PHPMYADMIN_PASSWORD';"
mysql -e "GRANT ALL PRIVILEGES ON roundcube.* TO 'roundcube'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# Import Roundcube schema
mysql roundcube < /var/www/webmail/SQL/mysql.initial.sql

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
systemctl start postfix
systemctl start dovecot
systemctl start bind9

# Check service status
echo "Service Status:"
echo "MySQL: $(systemctl is-active mysql)"
echo "Nginx: $(systemctl is-active nginx)"
echo "PHP-FPM: $(systemctl is-active php8.1-fpm)"
echo "Fail2Ban: $(systemctl is-active fail2ban)"
echo "Postfix: $(systemctl is-active postfix)"
echo "Dovecot: $(systemctl is-active dovecot)"
echo "BIND9: $(systemctl is-active bind9)"

# Display credentials (first run only)
if [ -f /root/first-run ]; then
    echo "=== SHM Panel First Run Information ==="
    echo "Admin SSH User: $(grep 'Admin User' /root/.secure/server_credentials.txt | cut -d: -f2)"
    echo "Admin SSH Password: $(grep 'Admin Password' /root/.secure/server_credentials.txt | cut -d: -f2)"
    echo "App User: $(grep 'App User' /root/.secure/server_credentials.txt | cut -d: -f2)"
    echo "App Password: $(grep 'App Password' /root/.secure/server_credentials.txt | cut -d: -f2)"
    echo "MySQL Root Password: $(grep 'MySQL Root' /root/.secure/server_credentials.txt | cut -d: -f2)"
    echo "phpMyAdmin Password: $(grep 'phpMyAdmin' /root/.secure/server_credentials.txt | cut -d: -f2)"
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
echo "Postfix: $(systemctl is-active postfix)"
echo "Dovecot: $(systemctl is-active dovecot)"
echo "BIND9: $(systemctl is-active bind9)"
echo ""
echo "=== Network ==="
ufw status
echo ""
echo "=== DNS Information ==="
echo "Domain: $(hostname)"
echo "NS Records:"
dig NS $(hostname) +short
echo ""
echo "=== Mail Information ==="
echo "MX Records:"
dig MX $(hostname) +short
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
tar -czf $BACKUP_DIR/$BACKUP_NAME-files.tar.gz /var/www/shm-panel /var/www/webmail

# Backup configurations
tar -czf $BACKUP_DIR/$BACKUP_NAME-config.tar.gz /etc/nginx /etc/mysql /etc/php /etc/postfix /etc/dovecot /etc/bind

# Backup mail data
tar -czf $BACKUP_DIR/$BACKUP_NAME-mail.tar.gz /var/mail

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
systemctl stop postfix
systemctl stop dovecot
systemctl stop bind9

# Restore MySQL
gunzip -c $BACKUP_DIR/$BACKUP_NAME-mysql.sql.gz | mysql

# Restore files
tar -xzf $BACKUP_DIR/$BACKUP_NAME-files.tar.gz -C /

# Restore configurations
tar -xzf $BACKUP_DIR/$BACKUP_NAME-config.tar.gz -C /

# Restore mail
tar -xzf $BACKUP_DIR/$BACKUP_NAME-mail.tar.gz -C /

# Start services
systemctl start mysql
systemctl start nginx
systemctl start postfix
systemctl start dovecot
systemctl start bind9

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
    for service in mysql nginx php8.1-fpm postfix dovecot bind9; do
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
    
    # Check mail queue
    MAIL_QUEUE=$(mailq | grep -c "^[A-F0-9]")
    echo "Mail queue: $MAIL_QUEUE"
    
    # Check DNS
    DNS_QUERY=$(dig +short google.com @localhost 2>/dev/null | head -1)
    if [ -n "$DNS_QUERY" ]; then
        echo "✅ DNS resolving working"
    else
        echo "❌ DNS resolving issues"
    fi
    
} >> $LOG_FILE

# Keep only last 1000 lines in log file
tail -1000 $LOG_FILE > $LOG_FILE.tmp
mv $LOG_FILE.tmp $LOG_FILE
EOF

chmod +x /root/monitor-shm.sh

# Create DNS management script
cat > /root/dns-manager.sh << EOF
#!/bin/bash
# DNS Management Script for SHM Panel

DOMAIN="$DOMAIN_NAME"
ZONE_FILE="/etc/bind/db.\$DOMAIN"
REVERSE_ZONE_FILE="/etc/bind/db.$(echo $SERVER_IP | cut -d. -f1-3)"

case "\$1" in
    add-record)
        if [ -z "\$2" ] || [ -z "\$3" ]; then
            echo "Usage: \$0 add-record <name> <ip> [type]"
            echo "Example: \$0 add-record webserver 192.168.1.10 A"
            exit 1
        fi
        NAME=\$2
        IP=\$3
        TYPE=\${4:-A}
        
        echo "\$NAME     IN      \$TYPE      \$IP" >> \$ZONE_FILE
        systemctl reload bind9
        echo "Added \$TYPE record: \$NAME -> \$IP"
        ;;
        
    add-reverse)
        if [ -z "\$2" ] || [ -z "\$3" ]; then
            echo "Usage: \$0 add-reverse <ip> <hostname>"
            echo "Example: \$0 add-reverse 192.168.1.10 webserver.\$DOMAIN"
            exit 1
        fi
        IP=\$2
        HOSTNAME=\$3
        OCTET=\$(echo \$IP | cut -d. -f4)
        
        echo "\$OCTET     IN      PTR     \$HOSTNAME." >> \$REVERSE_ZONE_FILE
        systemctl reload bind9
        echo "Added PTR record: \$IP -> \$HOSTNAME"
        ;;
        
    list-records)
        echo "=== A Records ==="
        grep "IN\s*A" \$ZONE_FILE
        echo ""
        echo "=== MX Records ==="
        grep "IN\s*MX" \$ZONE_FILE
        echo ""
        echo "=== PTR Records ==="
        grep "IN\s*PTR" \$REVERSE_ZONE_FILE
        ;;
        
    reload)
        named-checkzone \$DOMAIN \$ZONE_FILE
        named-checkzone $(echo $SERVER_IP | cut -d. -f3- | awk -F. '{print $2"."$1}').in-addr.arpa \$REVERSE_ZONE_FILE
        systemctl reload bind9
        echo "DNS zones reloaded"
        ;;
        
    *)
        echo "DNS Management Script"
        echo "Commands:"
        echo "  add-record <name> <ip> [type]  - Add DNS record"
        echo "  add-reverse <ip> <hostname>    - Add reverse DNS record"
        echo "  list-records                   - List all DNS records"
        echo "  reload                         - Reload DNS zones"
        ;;
esac
EOF

chmod +x /root/dns-manager.sh

# Create mail management script
cat > /root/mail-manager.sh << 'EOF'
#!/bin/bash
# Mail Management Script for SHM Panel

case "$1" in
    add-user)
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "Usage: $0 add-user <username> <password>"
            echo "Example: $0 add-user john password123"
            exit 1
        fi
        USERNAME=$2
        PASSWORD=$3
        
        # Create system user for mail
        useradd -m -s /bin/bash $USERNAME
        echo "$USERNAME:$PASSWORD" | chpasswd
        
        # Create Maildir
        sudo -u $USERNAME maildirmake /home/$USERNAME/Maildir
        sudo -u $USERNAME maildirmake /home/$USERNAME/Maildir/.Sent
        sudo -u $USERNAME maildirmake /home/$USERNAME/Maildir/.Drafts
        sudo -u $USERNAME maildirmake /home/$USERNAME/Maildir/.Trash
        sudo -u $USERNAME maildirmake /home/$USERNAME/Maildir/.Junk
        
        echo "Mail user $USERNAME created"
        ;;
        
    list-users)
        echo "=== Mail Users ==="
        getent passwd | grep -E '/home/.*(/bin/bash|/bin/sh)' | cut -d: -f1
        ;;
        
    queue)
        echo "=== Mail Queue ==="
        mailq
        ;;
        
    flush)
        postfix flush
        echo "Mail queue flushed"
        ;;
        
    stats)
        echo "=== Mail Statistics ==="
        echo "Queue: $(mailq | grep -c '^[A-F0-9]') emails"
        echo "Recent connections:"
        tail -20 /var/log/mail.log | grep -E '(connect|disconnect)'
        ;;
        
    *)
        echo "Mail Management Script"
        echo "Commands:"
        echo "  add-user <user> <pass>     - Add mail user"
        echo "  list-users                 - List mail users"
        echo "  queue                      - Show mail queue"
        echo "  flush                      - Flush mail queue"
        echo "  stats                      - Show mail statistics"
        ;;
esac
EOF

chmod +x /root/mail-manager.sh

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
systemctl restart postfix
systemctl restart dovecot
systemctl restart bind9

# Enable services to start on boot
systemctl enable mysql nginx php$PHP_VERSION-fpm fail2ban ssh postfix dovecot bind9

# Create first run flag
touch /root/first-run

# Display completion message
log "VPS Server Setup Completed!"
echo ""
echo "=== IMPORTANT INFORMATION ==="
echo "SSH Port: $SSH_PORT"
echo "Admin User: $ADMIN_USER"
echo "Admin Password: $(grep 'Admin Password' /root/.secure/server_credentials.txt | cut -d: -f2)"
echo "App User: $APP_USER"
echo "App Password: $(grep 'App Password' /root/.secure/server_credentials.txt | cut -d: -f2)"
echo "MySQL Root Password: $(grep 'MySQL Root' /root/.secure/server_credentials.txt | cut -d: -f2)"
echo "phpMyAdmin Password: $(grep 'phpMyAdmin' /root/.secure/server_credentials.txt | cut -d: -f2)"
echo ""
echo "=== SERVICE ACCESS PORTS ==="
echo "Web Server (SHM Panel): http://$SERVER_IP:80"
echo "phpMyAdmin: http://$SERVER_IP:8080 (user: admin)"
echo "Webmail: http://$SERVER_IP:8081"
echo "SMTP: $SERVER_IP:25, 587, 465"
echo "IMAP: $SERVER_IP:143, 993"
echo "POP3: $SERVER_IP:110, 995"
echo "DNS: $SERVER_IP:53"
echo ""
echo "=== DNS INFORMATION ==="
echo "Primary Domain: $DOMAIN_NAME"
echo "Name Server: ns1.$DOMAIN_NAME"
echo "Mail Server: mail.$DOMAIN_NAME"
echo ""
echo "=== MANAGEMENT SCRIPTS ==="
echo "System Info: /root/system-info.sh"
echo "DNS Management: /root/dns-manager.sh"
echo "Mail Management: /root/mail-manager.sh"
echo "Backup: /root/backup-shm.sh"
echo "Restore: /root/restore-shm.sh <backup-timestamp>"
echo "Monitor: /root/monitor-shm.sh"
echo ""
echo "Credentials saved to: /root/.secure/server_credentials.txt"

# Save setup information
cat > /root/setup-info.txt << EOF
SHM Panel Server Setup
======================
Completed: $(date)
Server IP: $SERVER_IP
Domain: $DOMAIN_NAME
SSH Port: $SSH_PORT
Admin User: $ADMIN_USER
App User: $APP_USER
Web Root: /var/www/shm-panel
Database: MySQL (root password in server_credentials.txt)

Services:
- Web Server: Nginx (Port 80, 443)
- Database: MySQL
- phpMyAdmin: Port 8080
- Webmail: Roundcube (Port 8081)
- Mail: Postfix + Dovecot
- DNS: BIND9 (Port 53)

Useful Commands:
- Check status: /root/system-info.sh
- DNS management: /root/dns-manager.sh
- Mail management: /root/mail-manager.sh
- Backup: /root/backup-shm.sh
- Restore: /root/restore-shm.sh <backup-timestamp>
- Monitor: /root/monitor-shm.sh

Service Management:
- MySQL: systemctl status mysql
- Nginx: systemctl status nginx
- PHP-FPM: systemctl status php$PHP_VERSION-fpm
- Fail2Ban: systemctl status fail2ban
- Postfix: systemctl status postfix
- Dovecot: systemctl status dovecot
- BIND9: systemctl status bind9
EOF

log "Setup information saved to /root/setup-info.txt"
echo ""
warning "Important: Configure your domain's NS records to point to this server!"
echo "Nameserver: ns1.$DOMAIN_NAME -> $SERVER_IP"
echo "Update your domain registrar's DNS settings accordingly."
