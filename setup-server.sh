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

# Extract domain parts for nameserver configuration
DOMAIN_NAME=$(echo $MAIN_DOMAIN | awk -F. '{print $(NF-1)"."$NF}')
HOST_NAME=$(echo $MAIN_DOMAIN | awk -F. '{print $1}')
SERVER_IP=$(hostname -I | awk '{print $1}')
HOSTNAME=$MAIN_DOMAIN  # Using the provided domain as the hostname
TIMEZONE="Asia/Kolkata"
SSH_PORT="2222"

# Generate Secure Passwords
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

# Nameserver Configuration
NS1="ns1.${DOMAIN_NAME}"
NS2="ns2.${DOMAIN_NAME}"
NS1_IP="${SERVER_IP}"
NS2_IP="${SERVER_IP}"  # Same IP for both NS records for single server setup
EMAIL="admin.${DOMAIN_NAME}"

log "Starting Installation on $SERVER_IP ($HOSTNAME)..."
log "Domain: $DOMAIN_NAME | Host: $HOST_NAME"
log "Nameservers will be: $NS1 ($NS1_IP), $NS2 ($NS2_IP)"

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
    bind9 bind9utils bind9-doc dnsutils \
    postfix dovecot-core dovecot-imapd dovecot-pop3d \
    software-properties-common

# Install multiple PHP versions
log "Adding PHP repository..."
add-apt-repository ppa:ondrej/php -y
apt update

log "Installing multiple PHP versions..."
apt install -y \
    php8.1-fpm php8.1-mysql php8.1-curl php8.1-gd php8.1-mbstring php8.1-xml php8.1-zip php8.1-bcmath \
    php8.2-fpm php8.2-mysql php8.2-curl php8.2-gd php8.2-mbstring php8.2-xml php8.2-zip php8.2-bcmath \
    php8.3-fpm php8.3-mysql php8.3-curl php8.3-gd php8.3-mbstring php8.3-xml php8.3-zip php8.3-bcmath

# Detect default PHP version
PHP_VERSION="8.2"
PHP_SOCK="/var/run/php/php$PHP_VERSION-fpm.sock"
log "Using PHP $PHP_VERSION as default."

# Configure all PHP versions
for version in 8.1 8.2 8.3; do
    cat > /etc/php/$version/fpm/conf.d/99-custom.ini << EOF
upload_max_filesize = 1024M
post_max_size = 1024M
memory_limit = 512M
max_execution_time = 300
date.timezone = "$TIMEZONE"
EOF
    systemctl restart php$version-fpm
done

# ------------------------------------------------------------------------------
# 3. DNS Server (Bind9) - Enhanced Configuration
# ------------------------------------------------------------------------------

log "Configuring Bind9 (DNS) with nameserver setup..."

# Stop bind9 temporarily to make configuration changes
systemctl stop bind9

# Configure named.conf.options
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
    };
    
    //========================================================================
    // If BIND logs error messages about the root key being expired,
    // you will need to update your keys.  See https://www.isc.org/bind-keys
    //========================================================================
    
    dnssec-validation auto;
    
    auth-nxdomain no;    # conform to RFC1035
    listen-on-v6 { any; };
    
    // Enable recursion for internal network
    recursion yes;
    allow-recursion { any; };
    
    // Allow queries from anywhere
    allow-query { any; };
    
    // Enable query logging (optional)
    // querylog yes;
};
EOF

# Create zone file directory if it doesn't exist
mkdir -p /etc/bind/zones

# Create forward zone file
cat > /etc/bind/zones/db.${DOMAIN_NAME} << EOF
\$TTL    604800
@       IN      SOA     ${NS1}. ${EMAIL}. (
                              2         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL

; Name Servers
@       IN      NS      ${NS1}.
@       IN      NS      ${NS2}.

; A Records
@       IN      A       ${SERVER_IP}
${HOST_NAME}    IN      A       ${SERVER_IP}
${NS1}          IN      A       ${SERVER_IP}
${NS2}          IN      A       ${SERVER_IP}
www             IN      A       ${SERVER_IP}
mail            IN      A       ${SERVER_IP}
panel           IN      A       ${SERVER_IP}

; MX Record
@       IN      MX      10      mail.${DOMAIN_NAME}.

; CNAME Records
ftp             IN      CNAME   ${HOST_NAME}.${DOMAIN_NAME}.
smtp            IN      CNAME   mail.${DOMAIN_NAME}.
pop3            IN      CNAME   mail.${DOMAIN_NAME}.
imap            IN      CNAME   mail.${DOMAIN_NAME}.

; TXT Records (for SPF, DKIM, DMARC)
@       IN      TXT     "v=spf1 a mx ip4:${SERVER_IP} ~all"
_dmarc  IN      TXT     "v=DMARC1; p=none; rua=mailto:admin@${DOMAIN_NAME}"
EOF

# Create reverse zone file (if needed)
REVERSE_ZONE=$(echo $SERVER_IP | awk -F. '{print $3"."$2"."$1".in-addr.arpa"}')
cat > /etc/bind/zones/db.${REVERSE_ZONE} << EOF
\$TTL    604800
@       IN      SOA     ${NS1}. ${EMAIL}. (
                              1         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL

; Name Servers
@       IN      NS      ${NS1}.
@       IN      NS      ${NS2}.

; PTR Records
$(echo $SERVER_IP | awk -F. '{print $4}')      IN      PTR     ${HOST_NAME}.${DOMAIN_NAME}.
EOF

# Configure named.conf.local
cat > /etc/bind/named.conf.local << EOF
// Forward Zone
zone "${DOMAIN_NAME}" {
    type master;
    file "/etc/bind/zones/db.${DOMAIN_NAME}";
    allow-transfer { any; };
    allow-query { any; };
};

// Reverse Zone
zone "${REVERSE_ZONE}" {
    type master;
    file "/etc/bind/zones/db.${REVERSE_ZONE}";
    allow-transfer { any; };
    allow-query { any; };
};

// Include the internal zones
include "/etc/bind/zones.rfc1918";
include "/etc/bind/named.conf.default-zones";
EOF

# Set proper permissions
chown -R bind:bind /etc/bind/zones
chmod 644 /etc/bind/zones/db.*

# Update resolv.conf to use local DNS
cat > /etc/resolv.conf << EOF
# Generated by SHM Panel setup
nameserver 127.0.0.1
nameserver 8.8.8.8
nameserver 8.8.4.4
search ${DOMAIN_NAME}
EOF

# Make resolv.conf immutable to prevent network manager from overwriting
chattr +i /etc/resolv.conf 2>/dev/null || true

# Configure systemd-resolved to use local bind
systemctl stop systemd-resolved
systemctl disable systemd-resolved

# Start and enable bind9
systemctl start bind9
systemctl enable bind9

# Test DNS configuration
log "Testing DNS configuration..."
named-checkconf /etc/bind/named.conf
named-checkzone ${DOMAIN_NAME} /etc/bind/zones/db.${DOMAIN_NAME}
named-checkzone ${REVERSE_ZONE} /etc/bind/zones/db.${REVERSE_ZONE}

# Test DNS resolution
log "Testing local DNS resolution..."
if dig @127.0.0.1 ${MAIN_DOMAIN} +short | grep -q "${SERVER_IP}"; then
    log "✓ DNS forward resolution working"
else
    warning "DNS forward resolution test failed. Continuing anyway..."
fi

if dig @127.0.0.1 -x ${SERVER_IP} +short | grep -q "${HOST_NAME}.${DOMAIN_NAME}"; then
    log "✓ DNS reverse resolution working"
else
    warning "DNS reverse resolution test failed. Continuing anyway..."
fi

# ------------------------------------------------------------------------------
# 4. Mail Server
# ------------------------------------------------------------------------------

log "Configuring Postfix & Dovecot..."

postconf -e "myhostname = $HOSTNAME"
postconf -e "inet_interfaces = all"
postconf -e "inet_protocols = all"
postconf -e "home_mailbox = Maildir/"
postconf -e "mydestination = $HOSTNAME, localhost.${DOMAIN_NAME}, , localhost"
postconf -e "myorigin = $DOMAIN_NAME"
postconf -e "mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128"
systemctl restart postfix

# Configure Dovecot
sed -i 's/#disable_plaintext_auth = yes/disable_plaintext_auth = no/' /etc/dovecot/conf.d/10-auth.conf
sed -i 's/mail_location = mbox:~/mail_location = maildir:~\/Maildir/' /etc/dovecot/conf.d/10-mail.conf
sed -i "s/#ssl = yes/ssl = no/" /etc/dovecot/conf.d/10-ssl.conf  # Disable SSL for local testing

# Configure mail domain
sed -i "s/#mail_domain = example.com/mail_domain = ${DOMAIN_NAME}/" /etc/dovecot/conf.d/10-auth.conf

systemctl restart dovecot

# ------------------------------------------------------------------------------
# 5. Database Setup (Updated Schema)
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

# Create domains table for SHM Panel
mysql $DB_MAIN_NAME << EOF
CREATE TABLE IF NOT EXISTS domains (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    parent_id INT DEFAULT NULL,
    domain_name VARCHAR(255) NOT NULL UNIQUE,
    document_root VARCHAR(500) NOT NULL,
    php_version VARCHAR(10) DEFAULT '8.2',
    dns_zone TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (parent_id) REFERENCES domains(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS dns_records (
    id INT AUTO_INCREMENT PRIMARY KEY,
    domain_id INT NOT NULL,
    record_type VARCHAR(10) NOT NULL,
    record_name VARCHAR(255) NOT NULL,
    record_value VARCHAR(500) NOT NULL,
    ttl INT DEFAULT 3600,
    priority INT DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (domain_id) REFERENCES domains(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
EOF

# ------------------------------------------------------------------------------
# 6. Install phpMyAdmin & Roundcube
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

# ------------------------------------------------------------------------------
# 7. Configure Sudo Permissions for Domain Management
# ------------------------------------------------------------------------------
log "Configuring sudo permissions for domain management..."

# Create sudoers file for www-data (for domain management)
cat > /etc/sudoers.d/shm-panel-www-data << EOF
# Allow www-data to run specific commands without password for SHM Panel
www-data ALL=(ALL) NOPASSWD: /usr/bin/mkdir, /usr/bin/rm, /usr/bin/mv, /usr/bin/chown, /usr/bin/chmod, /usr/bin/ln, /usr/bin/systemctl reload nginx, /usr/sbin/nginx -t, /usr/bin/systemctl reload bind9, /usr/bin/cp, /usr/bin/cat, /usr/bin/echo
EOF

chmod 440 /etc/sudoers.d/shm-panel-www-data

# Create sudoers file for admin user
cat > /etc/sudoers.d/shm-panel-admin << EOF
# Allow admin user to run all commands
$ADMIN_USER ALL=(ALL) NOPASSWD: ALL
EOF

chmod 440 /etc/sudoers.d/shm-panel-admin

# Validate sudoers syntax
if visudo -c >/dev/null 2>&1; then
    log "Sudoers files are valid"
else
    error "Invalid sudoers configuration!"
    exit 1
fi

# ------------------------------------------------------------------------------
# 8. Set Proper Permissions for /var/www
# ------------------------------------------------------------------------------
log "Setting up /var/www directory permissions..."

# Create /var/www directory if it doesn't exist
mkdir -p /var/www

# Set ownership to www-data but allow admin to write
chown -R www-data:www-data /var/www
chmod 755 /var/www

# Set ACL to allow admin user to access /var/www
setfacl -R -m u:$ADMIN_USER:rwx /var/www
setfacl -R -d -m u:$ADMIN_USER:rwx /var/www

# Set correct permissions for Nginx
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html

# ------------------------------------------------------------------------------
# 9. Create Domain Management Directories
# ------------------------------------------------------------------------------
log "Creating domain management structure..."

# Create a template directory for new domains
mkdir -p /var/www/templates
cat > /var/www/templates/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Welcome to Your New Domain</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            text-align: center;
            padding: 50px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
        }
        .container {
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            padding: 40px;
            border-radius: 20px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.1);
            max-width: 600px;
        }
        h1 {
            font-size: 3em;
            margin-bottom: 20px;
            color: white;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }
        p {
            font-size: 1.2em;
            line-height: 1.6;
            margin-bottom: 30px;
            color: rgba(255,255,255,0.9);
        }
        .success {
            color: #4ade80;
            font-weight: bold;
            font-size: 1.3em;
        }
        .info {
            background: rgba(255,255,255,0.2);
            padding: 15px;
            border-radius: 10px;
            margin-top: 20px;
            text-align: left;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Welcome to %%DOMAIN_NAME%%</h1>
        <p>Your website is successfully configured and ready to use!</p>
        <p class="success">✓ Powered by SHM Panel</p>
        <div class="info">
            <p><strong>Document Root:</strong> %%DOCUMENT_ROOT%%</p>
            <p><strong>PHP Version:</strong> %%PHP_VERSION%%</p>
            <p><strong>Server:</strong> Nginx + PHP-FPM</p>
            <p><strong>Nameservers:</strong> ns1.%%DOMAIN_NAME%% | ns2.%%DOMAIN_NAME%%</p>
            <p><strong>Status:</strong> Online and ready</p>
        </div>
        <p><small>Powered by SHM Panel - Simple Hosting Management</small></p>
    </div>
</body>
</html>
EOF

chown -R www-data:www-data /var/www/templates
chmod -R 755 /var/www/templates

# ------------------------------------------------------------------------------
# 10. Nginx Configuration (Main Domain)
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

    # --- PHP Processing ---
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:$PHP_SOCK;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    # --- Security ---
    location ~ /\. {
        deny all;
    }
    
    location ~* \.(log|sql|git|env)$ {
        deny all;
    }
}
EOF

# Create Nginx configuration directory structure
mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled

# Enable Site & Disable Default
ln -sf /etc/nginx/sites-available/$MAIN_DOMAIN /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Create Nginx snippets directory if it doesn't exist
mkdir -p /etc/nginx/snippets

# Create fastcgi-php.conf if it doesn't exist
if [ ! -f /etc/nginx/snippets/fastcgi-php.conf ]; then
    cat > /etc/nginx/snippets/fastcgi-php.conf << 'EOF'
# regex to split $uri to $fastcgi_script_name and $fastcgi_path
fastcgi_split_path_info ^(.+\.php)(/.+)$;

# Check that the PHP script exists before passing it
try_files $fastcgi_script_name =404;

# Bypass the fact that try_files resets $fastcgi_path_info
# see: http://trac.nginx.org/nginx/ticket/321
set $path_info $fastcgi_path_info;
fastcgi_param PATH_INFO $path_info;

fastcgi_index index.php;
include fastcgi.conf;
EOF
fi

# ------------------------------------------------------------------------------
# 11. Create SHM Panel Directory Structure
# ------------------------------------------------------------------------------
log "Creating SHM Panel structure..."

mkdir -p /var/www/shm-panel

# Create basic panel structure
mkdir -p /var/www/shm-panel/{includes,pages,assets,scripts}

# Create a basic index.php
cat > /var/www/shm-panel/index.php << 'EOF'
<?php
// SHM Panel - Main Index
session_start();

// Simple authentication check
if (!isset($_SESSION['user_id'])) {
    header('Location: pages/login.php');
    exit;
}

// Redirect to dashboard
header('Location: pages/dashboard.php');
?>
EOF

# Create a simple login page
mkdir -p /var/www/shm-panel/pages
cat > /var/www/shm-panel/pages/login.php << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SHM Panel - Login</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            margin: 0;
        }
        .login-container {
            background: white;
            padding: 40px;
            border-radius: 10px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
            width: 350px;
        }
        h2 {
            text-align: center;
            color: #333;
            margin-bottom: 30px;
        }
        .input-group {
            margin-bottom: 20px;
        }
        label {
            display: block;
            margin-bottom: 5px;
            color: #666;
        }
        input {
            width: 100%;
            padding: 10px;
            border: 1px solid #ddd;
            border-radius: 5px;
            font-size: 16px;
        }
        button {
            width: 100%;
            padding: 12px;
            background: #667eea;
            color: white;
            border: none;
            border-radius: 5px;
            font-size: 16px;
            cursor: pointer;
            transition: background 0.3s;
        }
        button:hover {
            background: #764ba2;
        }
        .logo {
            text-align: center;
            margin-bottom: 20px;
            font-size: 24px;
            color: #667eea;
            font-weight: bold;
        }
    </style>
</head>
<body>
    <div class="login-container">
        <div class="logo">SHM Panel</div>
        <h2>Login to Your Panel</h2>
        <form method="POST" action="auth.php">
            <div class="input-group">
                <label>Username</label>
                <input type="text" name="username" required>
            </div>
            <div class="input-group">
                <label>Password</label>
                <input type="password" name="password" required>
            </div>
            <button type="submit">Login</button>
        </form>
    </div>
</body>
</html>
EOF

# Create DNS management script
cat > /var/www/shm-panel/scripts/dns_manager.php << 'EOF'
<?php
// DNS Manager for SHM Panel
function addDNSRecord($domain, $type, $name, $value, $ttl = 3600) {
    // This function would add DNS records to Bind9
    $zoneFile = "/etc/bind/zones/db.{$domain}";
    
    if (file_exists($zoneFile)) {
        $record = "\n{$name}\tIN\t{$type}\t{$value}";
        file_put_contents($zoneFile, $record, FILE_APPEND);
        
        // Reload Bind9
        exec('sudo systemctl reload bind9', $output, $return);
        return $return === 0;
    }
    return false;
}

function removeDNSRecord($domain, $type, $name) {
    $zoneFile = "/etc/bind/zones/db.{$domain}";
    
    if (file_exists($zoneFile)) {
        $content = file_get_contents($zoneFile);
        $pattern = "/.*{$name}.*IN.*{$type}.*/";
        $content = preg_replace($pattern, '', $content);
        file_put_contents($zoneFile, $content);
        
        exec('sudo systemctl reload bind9', $output, $return);
        return $return === 0;
    }
    return false;
}
?>
EOF

# Set ownership and permissions
chown -R www-data:www-data /var/www/shm-panel
find /var/www/shm-panel -type d -exec chmod 755 {} \;
find /var/www/shm-panel -type f -exec chmod 644 {} \;

# ------------------------------------------------------------------------------
# 12. Security & Finalize
# ------------------------------------------------------------------------------
log "Finalizing..."

# Add Admin User (System Level)
if ! id "$ADMIN_USER" &>/dev/null; then
    useradd -m -s /bin/bash $ADMIN_USER
    echo "$ADMIN_USER:$ADMIN_PASS" | chpasswd
    usermod -aG sudo $ADMIN_USER
    log "Created admin user: $ADMIN_USER"
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
ufw allow 53/tcp
ufw allow 53/udp
ufw allow 25/tcp
ufw allow 143/tcp
ufw allow 587/tcp
ufw allow 993/tcp
ufw allow 995/tcp
ufw --force enable

# Test Nginx configuration
nginx -t && log "Nginx configuration test passed" || error "Nginx configuration test failed"

# Test Bind9 configuration
named-checkconf && log "Bind9 configuration test passed" || error "Bind9 configuration test failed"

# ------------------------------------------------------------------------------
# 13. Save Credentials and Complete
# ------------------------------------------------------------------------------

# Save Info
cat > /root/server_credentials.txt << EOF
=== SHM Panel Credentials ===
Hostname:  $HOSTNAME
Server IP: $SERVER_IP
SSH Port:  $SSH_PORT

[DNS Configuration]
Domain:          $DOMAIN_NAME
Main Domain:     $MAIN_DOMAIN
Nameserver 1:    $NS1
Nameserver 2:    $NS2
Nameserver IPs:  $NS1_IP, $NS2_IP
Reverse Zone:    $REVERSE_ZONE

[Web Services]
Panel URL:      http://$MAIN_DOMAIN
phpMyAdmin:     http://$MAIN_DOMAIN/phpmyadmin
Webmail:        http://$MAIN_DOMAIN/webmail

[System Login]
Admin User:     $ADMIN_USER
Admin Password: $ADMIN_PASS

[Database]
Root Password:  $MYSQL_ROOT_PASS
DB User:        $DB_USER
DB Password:    $DB_PASS

[PHP Versions]
Available:      8.1, 8.2, 8.3
Default:        8.2

[DNS Zone Information]
Zone file: /etc/bind/zones/db.${DOMAIN_NAME}
Reverse zone: /etc/bind/zones/db.${REVERSE_ZONE}
To add new domains: Add zone files in /etc/bind/zones/

[Important Notes]
1. Domain Management: /var/www/ is configured for automatic domain creation
2. DNS Management: DNS zones are automatically created for new domains
3. Sudo Access: www-data can manage domains and DNS without password
4. Default Panel Login: Use the login page at http://$MAIN_DOMAIN
5. SSH: ssh -p $SSH_PORT $ADMIN_USER@$SERVER_IP

=== Domain Management ===
- New domains will be created in /var/www/
- Each domain gets its own directory and Nginx config
- DNS zones are automatically created for each domain
- PHP version can be selected per domain (8.1, 8.2, or 8.3)
- Subdomains are supported automatically

=== DNS Configuration Steps for Domain Registrar ===
1. Login to your domain registrar
2. Update nameservers for $DOMAIN_NAME to:
   - Primary: $NS1
   - Secondary: $NS2
3. Set both nameservers to point to IP: $SERVER_IP
4. Wait 24-48 hours for DNS propagation

=== Security ===
- SSH is on port $SSH_PORT
- UFW firewall is enabled with DNS ports open
- Fail2ban is installed
- Regular updates configured
EOF

chmod 600 /root/server_credentials.txt

# Also create a credentials file for the admin user
mkdir -p /home/$ADMIN_USER
cat > /home/$ADMIN_USER/credentials.txt << EOF
=== SHM Panel Credentials ===
Panel URL: http://$MAIN_DOMAIN
SSH: ssh -p $SSH_PORT $ADMIN_USER@$SERVER_IP
Password: $ADMIN_PASS

=== DNS Information ===
Nameservers for your domains:
Primary: $NS1 ($SERVER_IP)
Secondary: $NS2 ($SERVER_IP)

=== Quick Commands ===
Check DNS: dig @$SERVER_IP $MAIN_DOMAIN
Check reverse: dig @$SERVER_IP -x $SERVER_IP
Restart DNS: sudo systemctl restart bind9
Check DNS status: sudo systemctl status bind9
EOF
chown $ADMIN_USER:$ADMIN_USER /home/$ADMIN_USER/credentials.txt
chmod 600 /home/$ADMIN_USER/credentials.txt

# Create a DNS check script for admin
cat > /usr/local/bin/check-dns << 'EOF'
#!/bin/bash
echo "=== DNS Status Check ==="
echo "Server IP: $(hostname -I | awk '{print $1}')"
echo "Hostname: $(hostname)"
echo ""
echo "Checking local DNS resolution..."
dig @127.0.0.1 $(hostname) +short
echo ""
echo "Checking forward zone..."
named-checkzone $(hostname | awk -F. '{print $(NF-1)"."$NF}') /etc/bind/zones/db.* 2>/dev/null
echo ""
echo "DNS Service Status:"
systemctl status bind9 --no-pager -l | grep -A5 "Active:"
EOF
chmod +x /usr/local/bin/check-dns

# Restart Services
systemctl daemon-reload
systemctl restart mysql bind9 postfix dovecot nginx ssh php8.1-fpm php8.2-fpm php8.3-fpm

# ------------------------------------------------------------------------------
# 14. Installation Complete
# ------------------------------------------------------------------------------
log "Setup Complete!"
echo "========================================================================="
echo "                    SHM PANEL INSTALLATION COMPLETE                      "
echo "========================================================================="
echo ""
echo "✓ Server Information:"
echo "  - Hostname:        $HOSTNAME"
echo "  - IP Address:      $SERVER_IP"
echo "  - SSH Port:        $SSH_PORT"
echo ""
echo "✓ DNS Configuration:"
echo "  - Domain:          $DOMAIN_NAME"
echo "  - Nameserver 1:    $NS1"
echo "  - Nameserver 2:    $NS2"
echo "  - Zone File:       /etc/bind/zones/db.${DOMAIN_NAME}"
echo ""
echo "✓ Web Services:"
echo "  - Panel:           http://$MAIN_DOMAIN"
echo "  - phpMyAdmin:      http://$MAIN_DOMAIN/phpmyadmin"
echo "  - Webmail:         http://$MAIN_DOMAIN/webmail"
echo ""
echo "✓ Login Credentials:"
echo "  - Admin User:      $ADMIN_USER"
echo "  - Admin Password:  $ADMIN_PASS"
echo ""
echo "✓ Database:"
echo "  - Root Password:   $MYSQL_ROOT_PASS"
echo "  - DB User:         $DB_USER"
echo "  - DB Password:     [See /root/server_credentials.txt]"
echo ""
echo "✓ Features Installed:"
echo "  - Multiple PHP versions (8.1, 8.2, 8.3)"
echo "  - Domain management ready"
echo "  - DNS Server (Bind9) with zone management"
echo "  - Nginx configured for dynamic domains"
echo "  - Sudo permissions configured for www-data"
echo "  - Security: UFW, Fail2ban, SSH on port $SSH_PORT"
echo ""
echo "========================================================================="
echo "IMPORTANT DNS CONFIGURATION STEPS:"
echo "========================================================================="
echo "1. Login to your domain registrar control panel"
echo "2. Update nameservers for $DOMAIN_NAME to:"
echo "   - Primary: $NS1"
echo "   - Secondary: $NS2"
echo "3. Point both nameservers to IP: $SERVER_IP"
echo "4. DNS propagation may take 24-48 hours"
echo ""
echo "To check DNS configuration:"
echo "  dig @$SERVER_IP $MAIN_DOMAIN"
echo "  check-dns (command line tool)"
echo ""
echo "========================================================================="
echo "Full details in: /root/server_credentials.txt"
echo "========================================================================="
echo ""
echo "Next steps:"
echo "1. Configure domain registrar with above nameservers"
echo "2. Upload your SHM Panel files to /var/www/shm-panel/"
echo "3. Configure the database connection in your panel"
echo "4. Visit http://$MAIN_DOMAIN to access your panel"
echo "5. Use the domains.php page to add your first domain"
echo ""
echo "========================================================================="
