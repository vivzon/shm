#!/usr/bin/env bash
# server.sh - Robust SHM Panel installer (Hardened & Verified)
# Usage: run as root on a fresh Ubuntu 20.04/22.04/24.04 or Debian 11/12.
set -euo pipefail
trap 'echo "[ERROR] Script failed at line $LINENO"; exit 1' ERR

# -------------------------
# Config
# -------------------------
TIMEZONE="Asia/Kolkata"
SSH_PORT="2222"
GIT_REPO="" # e.g. "https://github.com/you/repo.git"

# Generate secure credentials if not provided in ENV
MYSQL_ROOT_PASS="${MYSQL_ROOT_PASS:-$(openssl rand -base64 32)}"
DB_MAIN_NAME="${DB_MAIN_NAME:-shm_panel}"
DB_RC_NAME="${DB_RC_NAME:-roundcubemail}"
DB_USER="${DB_USER:-shm_db_user}"
DB_PASS="${DB_PASS:-$(openssl rand -base64 24)}"
ADMIN_USER="${ADMIN_USER:-shmadmin}"
ADMIN_PASS="${ADMIN_PASS:-$(openssl rand -base64 16)}"
PMA_SECRET="${PMA_SECRET:-$(openssl rand -hex 16)}"

# -------------------------
# Logging & Helper Functions
# -------------------------
timestamp(){ date '+%Y-%m-%d %H:%M:%S'; }
log(){ echo -e "[\033[0;32mINFO\033[0m] $(timestamp) $*"; }
warn(){ echo -e "[\033[0;33mWARN\033[0m] $(timestamp) $*"; }
err(){ echo -e "[\033[0;31mERR\033[0m] $(timestamp) $*"; }

if [ "$(id -u)" -ne 0 ]; then err "Run as root"; exit 1; fi

# -------------------------
# 1. System Prep
# -------------------------
log "Setting timezone to $TIMEZONE..."
timedatectl set-timezone "$TIMEZONE" || true

log "Updating apt repositories..."
export DEBIAN_FRONTEND=noninteractive

# Prevent MySQL install from asking for password
echo "mysql-server mysql-server/root_password password $MYSQL_ROOT_PASS" | debconf-set-selections
echo "mysql-server mysql-server/root_password_again password $MYSQL_ROOT_PASS" | debconf-set-selections

apt-get update -y
# Install base dependencies
apt-get install -y curl wget git unzip htop acl zip software-properties-common gnupg2

# -------------------------
# 2. Install LEMP & Extras
# -------------------------
log "Installing Nginx, MySQL, PHP, Mail stack..."
PKGS=(nginx mysql-server ufw fail2ban bind9 bind9utils \
      postfix dovecot-core dovecot-imapd dovecot-pop3d \
      php-fpm php-mysql php-curl php-gd php-mbstring php-xml \
      php-zip php-bcmath php-json php-intl php-soap php-ldap php-imagick)

apt-get install -y "${PKGS[@]}"

# -------------------------
# 3. PHP Configuration
# -------------------------
# Detect actual installed PHP version
if [ -z "$(command -v php)" ]; then err "PHP failed to install"; exit 1; fi
PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
PHP_FPM_SERVICE="php${PHP_VERSION}-fpm"
PHP_SOCK="/run/php/php${PHP_VERSION}-fpm.sock"

log "Configuring PHP $PHP_VERSION ($PHP_FPM_SERVICE)..."

# Ensure FPM is running
systemctl enable --now "$PHP_FPM_SERVICE"

# Apply PHP Tweaks
PHP_INI_FPM="/etc/php/${PHP_VERSION}/fpm/php.ini"
PHP_SESSION_DIR="/var/lib/php/sessions"

mkdir -p "$PHP_SESSION_DIR"
chmod 1733 "$PHP_SESSION_DIR"
chown root:root "$PHP_SESSION_DIR" # Sticky bit handles permissions

if [ -f "$PHP_INI_FPM" ]; then
  sed -i "s/^;*upload_max_filesize.*/upload_max_filesize = 1024M/" "$PHP_INI_FPM"
  sed -i "s/^;*post_max_size.*/post_max_size = 1024M/" "$PHP_INI_FPM"
  sed -i "s/^;*memory_limit.*/memory_limit = 512M/" "$PHP_INI_FPM"
  sed -i "s/^;*max_execution_time.*/max_execution_time = 300/" "$PHP_INI_FPM"
  sed -i "s|^;*date.timezone.*|date.timezone = ${TIMEZONE}|" "$PHP_INI_FPM"
  
  # Force session path
  cat > "/etc/php/${PHP_VERSION}/fpm/conf.d/99-shm-session.ini" <<EOF
session.save_path = "${PHP_SESSION_DIR}"
session.cookie_httponly = 1
EOF
  systemctl restart "$PHP_FPM_SERVICE"
fi

# -------------------------
# 4. MySQL Hardening & Root Access
# -------------------------
log "Configuring MySQL..."
systemctl enable --now mysql

# Wait for MySQL to be ready
log "Waiting for MySQL to accept connections..."
for i in {1..30}; do
  if mysqladmin ping --silent; then break; fi
  sleep 1
done

# Helper to execute SQL as root (trying socket first, then password file)
mysql_exec() {
  if [ -f /root/.my.cnf ]; then
    mysql --defaults-file=/root/.my.cnf -e "$1"
  else
    # Try sudo socket execution
    sudo mysql -e "$1" 2>/dev/null || mysql -u root -e "$1"
  fi
}

# Set Root Password (Handle MySQL vs MariaDB syntax)
log "Securing MySQL root account..."

# Create .my.cnf for future non-interactive access
cat > /root/.my.cnf <<EOF
[client]
user=root
password=${MYSQL_ROOT_PASS}
EOF
chmod 600 /root/.my.cnf

# Attempt to set password.
# MySQL 8+ uses caching_sha2_password by default.
# We try to set mysql_native_password for compatibility with older PHP apps, 
# but if that fails (MySQL 8.4+), we fall back to caching_sha2_password.
# Note: 'ALTER USER' works on modern MariaDB and MySQL.
QUERY_NATIVE="ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASS}';"
QUERY_DEFAULT="ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASS}';"

# Try native first via Socket
if sudo mysql -e "$QUERY_NATIVE" 2>/dev/null; then
    log "Root password set (native auth)."
elif sudo mysql -e "$QUERY_DEFAULT" 2>/dev/null; then
    log "Root password set (default auth)."
else
    # If socket failed, maybe password was already set by debconf?
    if mysql --defaults-file=/root/.my.cnf -e "SELECT 1;" >/dev/null 2>&1; then
        log "Root password already set correctly."
    else
        warn "Could not set MySQL root password via socket. Attempting skip-grant-tables recovery..."
        
        systemctl stop mysql
        mkdir -p /var/run/mysqld && chown mysql:mysql /var/run/mysqld
        nohup /usr/sbin/mysqld --skip-grant-tables --skip-networking --user=mysql >/tmp/mysqld.log 2>&1 &
        bg_pid=$!
        sleep 5
        
        # Reset password
        mysql -u root -e "FLUSH PRIVILEGES; $QUERY_NATIVE FLUSH PRIVILEGES;" || \
        mysql -u root -e "FLUSH PRIVILEGES; $QUERY_DEFAULT FLUSH PRIVILEGES;"
        
        kill "$bg_pid" || true
        sleep 3
        systemctl start mysql
    fi
fi

# Hardening
mysql_exec "DELETE FROM mysql.user WHERE User='';"
mysql_exec "DROP DATABASE IF EXISTS test;"
mysql_exec "FLUSH PRIVILEGES;"

# -------------------------
# 5. Database & Schema
# -------------------------
log "Creating Databases..."
mysql_exec "CREATE DATABASE IF NOT EXISTS \`${DB_MAIN_NAME}\`;"
mysql_exec "CREATE DATABASE IF NOT EXISTS \`${DB_RC_NAME}\`;"
mysql_exec "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
mysql_exec "GRANT ALL PRIVILEGES ON *.* TO '${DB_USER}'@'localhost' WITH GRANT OPTION;"
mysql_exec "FLUSH PRIVILEGES;"

# Schema
cat > /tmp/shm_schema.sql <<EOSQL
CREATE TABLE IF NOT EXISTS \`users\` (
  \`id\` int NOT NULL AUTO_INCREMENT,
  \`username\` varchar(50) NOT NULL,
  \`email\` varchar(100) NOT NULL,
  \`password\` varchar(255) NOT NULL,
  \`role\` enum('superadmin','admin','user') NOT NULL DEFAULT 'user',
  PRIMARY KEY (\`id\`), UNIQUE KEY (\`username\`)
) ENGINE=InnoDB;
INSERT IGNORE INTO \`users\` (\`username\`,\`email\`,\`password\`,\`role\`)
VALUES ('admin','admin@localhost','\$2y\$10\$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi','superadmin');
EOSQL
mysql_exec "USE \`${DB_MAIN_NAME}\`; SOURCE /tmp/shm_schema.sql;"

# -------------------------
# 6. Install Web Apps
# -------------------------
# phpMyAdmin
log "Installing phpMyAdmin..."
rm -rf /var/www/html/phpmyadmin
mkdir -p /var/www/html/phpmyadmin
wget -qO- https://files.phpmyadmin.net/phpMyAdmin/5.2.1/phpMyAdmin-5.2.1-all-languages.tar.gz | tar xz -C /var/www/html/phpmyadmin --strip-components=1
cat > /var/www/html/phpmyadmin/config.inc.php <<EOF
<?php
\$cfg['blowfish_secret'] = '${PMA_SECRET}';
\$i=0; \$i++;
\$cfg['Servers'][\$i]['auth_type'] = 'cookie';
\$cfg['Servers'][\$i]['host'] = 'localhost';
\$cfg['Servers'][\$i]['AllowNoPassword'] = false;
?>
EOF
chown -R www-data:www-data /var/www/html/phpmyadmin

# Roundcube
log "Installing Roundcube..."
rm -rf /var/www/html/webmail
mkdir -p /var/www/html/webmail
RC_URL="https://github.com/roundcube/roundcubemail/releases/download/1.6.6/roundcubemail-1.6.6-complete.tar.gz"
wget -qO- "$RC_URL" | tar xz -C /var/www/html/webmail --strip-components=1

# Init Roundcube DB
if [ -f /var/www/html/webmail/SQL/mysql.initial.sql ]; then
  mysql_exec "USE \`${DB_RC_NAME}\`; SOURCE /var/www/html/webmail/SQL/mysql.initial.sql;"
fi

cat > /var/www/html/webmail/config/config.inc.php <<EOF
<?php
\$config['db_dsnw'] = 'mysql://${DB_USER}:${DB_PASS}@localhost/${DB_RC_NAME}';
\$config['default_host'] = 'localhost';
\$config['smtp_server'] = 'localhost';
\$config['smtp_port'] = 25;
\$config['des_key'] = '$(openssl rand -hex 12)';
\$config['plugins'] = ['archive','zipdownload'];
?>
EOF
chown -R www-data:www-data /var/www/html/webmail

# -------------------------
# 7. Nginx Setup
# -------------------------
log "Configuring Nginx..."
cat > /etc/nginx/sites-available/shm-panel <<NGINX
server {
    listen 80 default_server;
    server_name _;
    root /var/www/shm-panel;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    # Aliases for Tools
    location /phpmyadmin {
        alias /var/www/html/phpmyadmin;
        index index.php;
        try_files \$uri \$uri/ /index.php;
        location ~ ^/phpmyadmin/(.+\.php)$ {
            alias /var/www/html/phpmyadmin/\$1;
            include snippets/fastcgi-php.conf;
            fastcgi_pass unix:${PHP_SOCK};
            fastcgi_param SCRIPT_FILENAME \$request_filename;
        }
    }

    location /webmail {
        alias /var/www/html/webmail;
        index index.php;
        try_files \$uri \$uri/ /index.php;
        location ~ ^/webmail/(.+\.php)$ {
            alias /var/www/html/webmail/\$1;
            include snippets/fastcgi-php.conf;
            fastcgi_pass unix:${PHP_SOCK};
            fastcgi_param SCRIPT_FILENAME \$request_filename;
        }
    }

    # PHP Handler
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:${PHP_SOCK};
    }
}
NGINX

ln -sf /etc/nginx/sites-available/shm-panel /etc/nginx/sites-enabled/shm-panel
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx

# -------------------------
# 8. Deploy Panel Source
# -------------------------
mkdir -p /var/www/shm-panel
if [ -n "${GIT_REPO}" ]; then
  log "Deploying from GIT..."
  rm -rf /var/www/shm-panel/*
  git clone --depth 1 "${GIT_REPO}" /var/www/shm-panel
else
  log "Creating placeholder..."
  echo "<?php echo '<h1>SHM Panel Installed Successfully</h1>'; ?>" > /var/www/shm-panel/index.php
fi
chown -R www-data:www-data /var/www/shm-panel

# -------------------------
# 9. Security & User
# -------------------------
log "Securing SSH and System..."

# Create Admin User
if ! id "$ADMIN_USER" &>/dev/null; then
  useradd -m -s /bin/bash "$ADMIN_USER"
  echo "${ADMIN_USER}:${ADMIN_PASS}" | chpasswd
  usermod -aG sudo "$ADMIN_USER"
fi

# SSH Config (Safe Sed)
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
sed -i -E "s/^#?Port .*/Port ${SSH_PORT}/" /etc/ssh/sshd_config
sed -i -E "s/^#?PermitRootLogin .*/PermitRootLogin no/" /etc/ssh/sshd_config
if ! grep -q "AllowUsers" /etc/ssh/sshd_config; then
  echo "AllowUsers ${ADMIN_USER}" >> /etc/ssh/sshd_config
fi

# Firewall
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow "${SSH_PORT}/tcp"
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 25/tcp
ufw allow 587/tcp
ufw allow 143/tcp
ufw --force enable

systemctl restart sshd

# -------------------------
# 10. Finish
# -------------------------
CRED_FILE="/root/shm_credentials.txt"
cat > "${CRED_FILE}" <<EOF
==================================================
           SHM PANEL INSTALL COMPLETE
==================================================
Server IP:  $(hostname -I | awk '{print $1}')
SSH User:   ${ADMIN_USER}
SSH Pass:   ${ADMIN_PASS}
SSH Port:   ${SSH_PORT}

[Database]
Root Pass:  ${MYSQL_ROOT_PASS}
DB User:    ${DB_USER}
DB Pass:    ${DB_PASS}
DB Name:    ${DB_MAIN_NAME}

[URLs]
Panel:      http://$(hostname -I | awk '{print $1}')/
phpMyAdmin: http://$(hostname -I | awk '{print $1}')/phpmyadmin/
Webmail:    http://$(hostname -I | awk '{print $1}')/webmail/

Note: MySQL Root config saved to /root/.my.cnf
==================================================
EOF
chmod 600 "${CRED_FILE}"

log "Installation Complete!"
cat "${CRED_FILE}"
