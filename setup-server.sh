#!/usr/bin/env bash
# server.sh - Robust SHM Panel install script (LEMP + DNS + Mail + phpMyAdmin + Roundcube)
# Tested approach: Debian/Ubuntu family. Run as root.
set -euo pipefail
trap 'echo "[ERROR] Script failed at line $LINENO"; exit 1' ERR

# -------------------------
# Configuration - edit if needed
# -------------------------
TIMEZONE="Asia/Kolkata"
SSH_PORT="2222"

# Optional: set your git repo URL to deploy the panel app into /var/www/shm-panel
# If empty, the script will create a safe placeholder and you can copy your app later.
GIT_REPO="" # e.g. "https://github.com/yourusername/shm-panel.git"

# Credentials generation (secure random)
MYSQL_ROOT_PASS=$(openssl rand -base64 32)
DB_MAIN_NAME="shm_panel"
DB_RC_NAME="roundcubemail"
DB_USER="shm_db_user"
DB_PASS=$(openssl rand -base64 24)

ADMIN_USER="shmadmin"
ADMIN_PASS=$(openssl rand -base64 16)

PMA_SECRET=$(openssl rand -hex 16)

# Packages (you can tweak)
PKGS=(
  curl wget git unzip htop acl zip nginx mysql-server \
  php-fpm php-mysql php-curl php-gd php-mbstring php-xml php-zip php-bcmath php-json php-intl php-soap php-ldap php-imagick \
  ufw fail2ban bind9 bind9utils bind9-doc postfix dovecot-core dovecot-imapd dovecot-pop3d software-properties-common
)

# -------------------------
# Utility logging functions
# -------------------------
timestamp() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo -e "[\033[0;32mINFO\033[0m] $(timestamp) $*"; }
warn() { echo -e "[\033[0;33mWARN\033[0m] $(timestamp) $*"; }
err() { echo -e "[\033[0;31mERR \033[0m] $(timestamp) $*"; }

# -------------------------
# Preflight checks
# -------------------------
if [ "$(id -u)" -ne 0 ]; then
  err "Please run this script as root."
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
log "Setting timezone to $TIMEZONE"
timedatectl set-timezone "$TIMEZONE" || warn "timedatectl failed (maybe not available)"

# -------------------------
# Update & install packages
# -------------------------
log "Updating apt repositories..."
apt-get update -y
log "Installing packages..."
apt-get install -y "${PKGS[@]}"

# -------------------------
# Determine PHP FPM socket and service name
# -------------------------
detect_php_fpm() {
  # prefer installed php-fpm service names, try common versions
  for v in 8.3 8.2 8.1 8.0 7.4; do
    if systemctl list-units --full -all | grep -q "php${v}-fpm.service"; then
      PHP_VERSION=${v}
      PHP_FPM_SERVICE="php${v}-fpm"
      break
    fi
  done

  # fallback: parse `php -v`
  if [ -z "${PHP_VERSION-}" ]; then
    if command -v php >/dev/null 2>&1; then
      php_ver="$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')"
      PHP_VERSION="${php_ver}"
      PHP_FPM_SERVICE="php${PHP_VERSION}-fpm"
    else
      # default to 8.1
      PHP_VERSION="8.1"
      PHP_FPM_SERVICE="php${PHP_VERSION}-fpm"
      warn "php CLI not found; defaulting to PHP $PHP_VERSION"
    fi
  fi

  # socket path
  PHP_SOCK="/var/run/php/php${PHP_VERSION}-fpm.sock"
  if [ ! -S "$PHP_SOCK" ]; then
    warn "PHP FPM socket $PHP_SOCK not found. Will try service name $PHP_FPM_SERVICE. Ensure php-fpm is running."
  fi

  log "Detected PHP version: $PHP_VERSION (service: $PHP_FPM_SERVICE, sock: $PHP_SOCK)"
}
detect_php_fpm

# -------------------------
# PHP configuration tweaks (session, upload limits, timezone)
# -------------------------
log "Applying PHP FPM configuration tweaks..."
PHP_INI_FPM="/etc/php/${PHP_VERSION}/fpm/php.ini"
PHP_INI_CLI="/etc/php/${PHP_VERSION}/cli/php.ini"

if [ -f "$PHP_INI_FPM" ]; then
  sed -i "s@^;*\s*upload_max_filesize.*@upload_max_filesize = 1024M@" "$PHP_INI_FPM"
  sed -i "s@^;*\s*post_max_size.*@post_max_size = 1024M@" "$PHP_INI_FPM"
  sed -i "s@^;*\s*memory_limit.*@memory_limit = 512M@" "$PHP_INI_FPM"
  sed -i "s@^;*\s*max_execution_time.*@max_execution_time = 300@" "$PHP_INI_FPM"
  sed -i "s@^;*\s*date.timezone.*@date.timezone = ${TIMEZONE}@g" "$PHP_INI_FPM"
fi

# Ensure session settings
PHP_SESSION_DIR="/var/lib/php/sessions"
mkdir -p "$PHP_SESSION_DIR"
chown -R www-data:www-data "$PHP_SESSION_DIR"
chmod 1733 "$PHP_SESSION_DIR"

# Ensure php.ini session settings for FPM
if [ -f "$PHP_INI_FPM" ]; then
  php_admin_values="
session.save_path = \"$PHP_SESSION_DIR\"
session.cookie_path = \"/\"
session.use_strict_mode = 1
session.cookie_httponly = 1
session.cookie_secure = 0
session.cookie_samesite = \"Lax\"
"
  # create override conf
  echo "$php_admin_values" > "/etc/php/${PHP_VERSION}/fpm/conf.d/99-shm-session.ini"
fi

# Restart PHP FPM
if systemctl is-enabled --quiet "$PHP_FPM_SERVICE"; then
  log "Restarting $PHP_FPM_SERVICE"
  systemctl restart "$PHP_FPM_SERVICE"
else
  log "Starting & enabling $PHP_FPM_SERVICE"
  systemctl enable --now "$PHP_FPM_SERVICE" || warn "Failed to start $PHP_FPM_SERVICE; continue and check service"
fi

# -------------------------
# MySQL setup + secure adjustments
# -------------------------
log "Starting MySQL server..."
systemctl enable --now mysql

# Wait for mysql socket
for i in {1..15}; do
  if mysqladmin ping >/dev/null 2>&1; then break; fi
  sleep 1
done

log "Securing MySQL root user & creating DBs/users..."
# Use temporary .my.cnf to run mysql commands without exposing on commandline
MYCNF="/root/.my.cnf"
cat > "$MYCNF" <<EOF
[client]
user=root
password=
EOF
chmod 600 "$MYCNF"

# If MySQL root has no password (fresh install), set password
# Use mysql_native_password for compatibility
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASS}';" || true
mysql -e "DELETE FROM mysql.user WHERE User='';"
mysql -e "DROP DATABASE IF EXISTS test;"
mysql -e "FLUSH PRIVILEGES;"

# Write .my.cnf with password for subsequent commands
cat > "$MYCNF" <<EOF
[client]
user=root
password=${MYSQL_ROOT_PASS}
EOF
chmod 600 "$MYCNF"

# Create databases and DB user
mysql --defaults-file="$MYCNF" -e "CREATE DATABASE IF NOT EXISTS \`${DB_MAIN_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql --defaults-file="$MYCNF" -e "CREATE DATABASE IF NOT EXISTS \`${DB_RC_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql --defaults-file="$MYCNF" -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
mysql --defaults-file="$MYCNF" -e "GRANT ALL PRIVILEGES ON *.* TO '${DB_USER}'@'localhost' WITH GRANT OPTION;"
mysql --defaults-file="$MYCNF" -e "FLUSH PRIVILEGES;"

# Import schema for panel (safe idempotent SQL)
cat > /tmp/shm_schema.sql <<'EOSQL'
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
  PRIMARY KEY (`id`), UNIQUE KEY `domain_name` (`domain_name`), KEY `user_id` (`user_id')
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

INSERT IGNORE INTO `users` (`username`, `email`, `password`, `role`, `status`) VALUES 
('admin', 'admin@localhost', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'superadmin', 'active');
INSERT IGNORE INTO `hosting_plans` (`name`, `disk_space_mb`) VALUES ('Basic', 1000);
SET FOREIGN_KEY_CHECKS=1;
EOSQL

mysql --defaults-file="$MYCNF" "$DB_MAIN_NAME" < /tmp/shm_schema.sql
rm -f /tmp/shm_schema.sql

# -------------------------
# Web apps: phpMyAdmin & Roundcube
# -------------------------
log "Installing phpMyAdmin..."
mkdir -p /var/www/html/phpmyadmin
cd /tmp
PMA_VER="5.2.1"
wget -q "https://files.phpmyadmin.net/phpMyAdmin/${PMA_VER}/phpMyAdmin-${PMA_VER}-all-languages.zip"
unzip -q "phpMyAdmin-${PMA_VER}-all-languages.zip"
cp -r "phpMyAdmin-${PMA_VER}-all-languages/"* /var/www/html/phpmyadmin/
rm -rf "phpMyAdmin-${PMA_VER}-all-languages*" phpMyAdmin-*

cat > /var/www/html/phpmyadmin/config.inc.php <<EOF
<?php
\$cfg['blowfish_secret'] = '${PMA_SECRET}';
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

log "Installing Roundcube (webmail)..."
mkdir -p /var/www/html/webmail
cd /tmp
RC_VER="1.6.6"
wget -q "https://github.com/roundcube/roundcubemail/releases/download/${RC_VER}/roundcubemail-${RC_VER}-complete.tar.gz"
tar -xzf "roundcubemail-${RC_VER}-complete.tar.gz"
cp -r "roundcubemail-${RC_VER}/"/* /var/www/html/webmail/
rm -rf "roundcubemail-${RC_VER}"* roundcubemail-*
chown -R www-data:www-data /var/www/html/webmail

# Import roundcube DB if SQL exists
if [ -f /var/www/html/webmail/SQL/mysql.initial.sql ]; then
  log "Importing roundcube initial schema..."
  mysql --defaults-file="$MYCNF" "$DB_RC_NAME" < /var/www/html/webmail/SQL/mysql.initial.sql || warn "Roundcube initial import failed"
fi

# Roundcube config
cat > /var/www/html/webmail/config/config.inc.php <<EOF
<?php
\$config['db_dsnw'] = 'mysql://${DB_USER}:${DB_PASS}@localhost/${DB_RC_NAME}';
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
chown -R www-data:www-data /var/www/html/webmail

# -------------------------
# Nginx configuration
# -------------------------
log "Configuring Nginx site..."
cat > /etc/nginx/sites-available/shm-panel <<'NGINX'
server {
    listen 80;
    server_name _; # change to your domain or IP

    root /var/www/shm-panel;
    index index.php index.html;

    # Main Panel
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    # phpMyAdmin - use alias so docroot remains /var/www/shm-panel for main panel
    location /phpmyadmin {
        alias /var/www/html/phpmyadmin/;
        index index.php;
        try_files $uri $uri/ =404;
    }
    location ~ ^/phpmyadmin/(.+\.php)$ {
        alias /var/www/html/phpmyadmin/$1;
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:__PHP_SOCK__;
        fastcgi_param SCRIPT_FILENAME /var/www/html/phpmyadmin/$1;
    }

    # Roundcube (Webmail)
    location /webmail {
        alias /var/www/html/webmail/;
        index index.php;
        try_files $uri $uri/ =404;
    }
    location ~ ^/webmail/(.+\.php)$ {
        alias /var/www/html/webmail/$1;
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:__PHP_SOCK__;
        fastcgi_param SCRIPT_FILENAME /var/www/html/webmail/$1;
    }

    # PHP handling for panel (default)
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:__PHP_SOCK__;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    # deny hidden files
    location ~ /\. {
        deny all;
    }
}
NGINX

# Replace __PHP_SOCK__ placeholder with actual socket path
sed -i "s#__PHP_SOCK__#${PHP_SOCK}#g" /etc/nginx/sites-available/shm-panel

ln -sf /etc/nginx/sites-available/shm-panel /etc/nginx/sites-enabled/shm-panel
rm -f /etc/nginx/sites-enabled/default

# Reload nginx
nginx -t && systemctl reload nginx

# -------------------------
# Deploy or prepare panel app directory
# -------------------------
log "Preparing /var/www/shm-panel webroot..."
mkdir -p /var/www/shm-panel
if [ -n "$GIT_REPO" ]; then
  if [ -d /var/www/shm-panel/.git ]; then
    log "Updating existing repo in /var/www/shm-panel"
    cd /var/www/shm-panel && git pull --rebase || warn "git pull failed"
  else
    log "Cloning app repository into /var/www/shm-panel"
    rm -rf /var/www/shm-panel/*
    git clone "$GIT_REPO" /var/www/shm-panel
  fi
else
  # If no repo provided, create a safe placeholder and a correct index.php router example
  if [ ! -f /var/www/shm-panel/index.php ] || ! grep -q "getPageMap" /var/www/shm-panel/index.php 2>/dev/null; then
    log "Creating placeholder panel skeleton in /var/www/shm-panel (no GIT_REPO provided)."
    cat > /var/www/shm-panel/index.php <<'PHP'
<?php
// Minimal router skeleton to demonstrate correct behavior for clean URLs
session_start();
if (!file_exists(__DIR__ . '/includes')) {
    mkdir(__DIR__ . '/includes', 0755, true);
}
echo "<h1>Place your panel in /var/www/shm-panel or set GIT_REPO and re-run the script.</h1>";
PHP
  fi
fi

chown -R www-data:www-data /var/www/shm-panel

# -------------------------
# System user & SSH config
# -------------------------
log "Creating admin system user and configuring SSH..."
if ! id -u "$ADMIN_USER" >/dev/null 2>&1; then
  useradd -m -s /bin/bash "$ADMIN_USER"
  echo "${ADMIN_USER}:${ADMIN_PASS}" | chpasswd
  usermod -aG sudo "$ADMIN_USER"
fi

# Harden SSH
if grep -q "^#Port 22" /etc/ssh/sshd_config 2>/dev/null; then
  sed -i "s/^#Port 22/Port ${SSH_PORT}/" /etc/ssh/sshd_config
else
  sed -i "s/^Port .*/Port ${SSH_PORT}/" /etc/ssh/sshd_config || echo "Port ${SSH_PORT}" >> /etc/ssh/sshd_config
fi
sed -i "s/^PermitRootLogin .*/PermitRootLogin no/" /etc/ssh/sshd_config || echo "PermitRootLogin no" >> /etc/ssh/sshd_config
if ! grep -q "^AllowUsers" /etc/ssh/sshd_config; then
  echo "AllowUsers ${ADMIN_USER}" >> /etc/ssh/sshd_config
else
  # ensure our admin is in AllowUsers line
  if ! grep -q "^AllowUsers .*${ADMIN_USER}" /etc/ssh/sshd_config; then
    sed -i "s/^AllowUsers /AllowUsers ${ADMIN_USER} /" /etc/ssh/sshd_config
  fi
fi
systemctl reload sshd || warn "sshd reload failed"

# -------------------------
# Firewall
# -------------------------
log "Configuring UFW firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow "${SSH_PORT}/tcp"
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 53    # DNS
ufw allow 25    # SMTP
ufw allow 143   # IMAP
ufw allow 587   # Submission
ufw --force enable

# -------------------------
# Finalize services & credentials output
# -------------------------
log "Enabling & restarting services..."
systemctl enable --now nginx mysql bind9 postfix dovecot fail2ban || warn "Some services failed to start"

CREDENTIALS_FILE="/root/server_credentials.txt"
cat > "$CREDENTIALS_FILE" <<EOF
=== SHM Panel Credentials ===
Server IP: $(hostname -I | awk '{print $1}')
SSH Port:  ${SSH_PORT}

[System User]
SSH User:  ${ADMIN_USER}
SSH Pass:  ${ADMIN_PASS}

[Database]
Root Pass: ${MYSQL_ROOT_PASS}
DB User:   ${DB_USER}
DB Pass:   ${DB_PASS}
DB Name:   ${DB_MAIN_NAME}

[Webapps]
phpMyAdmin: http://$(hostname -I | awk '{print $1}')/phpmyadmin
Webmail:    http://$(hostname -I | awk '{print $1}')/webmail
Panel root: http://$(hostname -I | awk '{print $1}')

[Defaults]
Panel admin user: admin / admin123 (inserted into DB)
EOF
chmod 600 "$CREDENTIALS_FILE"

log "Installation complete. Credentials saved to $CREDENTIALS_FILE"
echo "-----------------------------------------------------"
echo " Access phpMyAdmin: http://$(hostname -I | awk '{print $1}')/phpmyadmin"
echo " Access Webmail:    http://$(hostname -I | awk '{print $1}')/webmail"
echo " Main Panel root:   http://$(hostname -I | awk '{print $1}')"
echo " SSH:               ssh -p ${SSH_PORT} ${ADMIN_USER}@$(hostname -I | awk '{print $1}')"
echo "-----------------------------------------------------"

# Provide simple next steps
cat <<'STEPS'

Next steps (recommended):
1) If you provided a GIT_REPO, ensure the repository contains your panel files (index.php, includes/, pages/).
2) Verify sessions are working:
   - Check /var/lib/php/sessions is owned by www-data and writable.
   - Use curl to test login cookie: curl -i -c c.txt http://server/phpmyadmin
3) Inspect /root/server_credentials.txt for generated passwords.
4) If you use a domain, update server_name in /etc/nginx/sites-available/shm-panel and run:
   nginx -t && systemctl reload nginx
5) Secure postfix/dovecot and obtain TLS certs (Let's Encrypt) if exposing mail/web.

STEPS

exit 0
