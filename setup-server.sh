#!/bin/bash
# SHM Panel Full VPS Setup Script
# Root check
if [ "$EUID" -ne 0 ]; then echo "Please run as root"; exit 1; fi
set -e

# --- COLORS ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log(){ echo -e "${GREEN}[$(date +'%F %T')] $1${NC}"; }
error(){ echo -e "${RED}[ERROR] $1${NC}"; }
warning(){ echo -e "${YELLOW}[WARN] $1${NC}"; }

# --- CONFIG ---
SERVER_IP=$(hostname -I | awk '{print $1}')
TIMEZONE="Asia/Kolkata"
ADMIN_USER="shmadmin"
SSH_PORT="2222"
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)
APP_USER="shmuser"
APP_USER_PASSWORD=$(openssl rand -base64 16)

log "Starting VPS Server Setup for SHM Panel"
log "Server IP: $SERVER_IP"

# --- SYSTEM UPDATE ---
log "Updating system..."
apt update && apt upgrade -y
apt install -y curl wget git unzip htop nginx mysql-server php-fpm \
php-mysql php-curl php-gd php-mbstring php-xml php-zip php-bcmath \
php-json php-intl php-soap php-ldap ufw fail2ban logrotate software-properties-common unzip zip

timedatectl set-timezone $TIMEZONE

# --- USERS ---
# App user
if ! id "$APP_USER" &>/dev/null; then
    useradd -m -s /bin/bash $APP_USER
    echo "$APP_USER:$APP_USER_PASSWORD" | chpasswd
    usermod -aG sudo $APP_USER
fi
# Admin user
if ! id "$ADMIN_USER" &>/dev/null; then
    useradd -m -s /bin/bash $ADMIN_USER
    ADMIN_PASSWORD=$(openssl rand -base64 16)
    echo "$ADMIN_USER:$ADMIN_PASSWORD" | chpasswd
    usermod -aG sudo $ADMIN_USER
fi

# Save credentials
cat > /root/server_credentials.txt <<EOF
Admin User: $ADMIN_USER
Admin Password: $ADMIN_PASSWORD
App User: $APP_USER
App Password: $APP_USER_PASSWORD
MySQL Root Password: $MYSQL_ROOT_PASSWORD
EOF
chmod 600 /root/server_credentials.txt

# --- SSH HARDENING ---
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
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
systemctl restart ssh

# --- FIREWALL ---
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow $SSH_PORT
ufw allow 80
ufw allow 443
ufw --force enable

# --- FAIL2BAN ---
systemctl enable fail2ban
cat > /etc/fail2ban/jail.local <<EOF
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
EOF
systemctl restart fail2ban

# --- MYSQL ---
systemctl enable mysql
systemctl start mysql
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD';"
mysql -e "DELETE FROM mysql.user WHERE User='';"
mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
mysql -e "DROP DATABASE IF EXISTS test;"
mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
mysql -e "FLUSH PRIVILEGES;"
cat > /root/.my.cnf <<EOF
[client]
user=root
password=$MYSQL_ROOT_PASSWORD
EOF
chmod 600 /root/.my.cnf

# --- PHP ---
PHP_VERSION=$(php -v | head -n1 | cut -d " " -f2 | cut -d "." -f1,2)
PHP_FPM="php${PHP_VERSION}-fpm"

sed -i "s|;date.timezone =.*|date.timezone = $TIMEZONE|" /etc/php/$PHP_VERSION/fpm/php.ini
systemctl restart $PHP_FPM

# --- NGINX & SHM PANEL ---
mkdir -p /var/www/shm-panel /var/log/shm-panel
chown -R $APP_USER:www-data /var/www/shm-panel /var/log/shm-panel
chmod 755 /var/www/shm-panel

cat > /etc/nginx/sites-available/shm-panel <<EOF
server {
    listen 80;
    server_name _;

    root /var/www/shm-panel;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/$PHP_VERSION-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    client_max_body_size 100M;
    client_body_timeout 300;
}
EOF
ln -sf /etc/nginx/sites-available/shm-panel /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
systemctl restart nginx

# --- PHPMYADMIN ---
apt install -y phpmyadmin php-mbstring php-gettext
phpenmod mbstring
mkdir -p /usr/share/phpmyadmin/tmp
chown -R www-data:www-data /usr/share/phpmyadmin

cat > /etc/nginx/snippets/phpmyadmin.conf <<EOF
location /phpmyadmin {
    root /usr/share/;
    index index.php;
    location ~ ^/phpmyadmin/(.+\.php)\$ {
        try_files \$uri =404;
        root /usr/share/;
        fastcgi_pass unix:/var/run/php/${PHP_VERSION}-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
}
EOF
sed -i '/server_name _;/a \    include snippets/phpmyadmin.conf;' /etc/nginx/sites-available/shm-panel
systemctl reload nginx

# --- WEBMAIL: ROUNDcube & RAINLOOP ---
# Roundcube
apt install -y roundcube roundcube-core roundcube-mysql roundcube-plugins
mysql -e "CREATE DATABASE IF NOT EXISTS roundcube;"
mysql -e "CREATE USER 'roundcube'@'localhost' IDENTIFIED BY '$(openssl rand -base64 16)';"
mysql -e "GRANT ALL PRIVILEGES ON roundcube.* TO 'roundcube'@'localhost'; FLUSH PRIVILEGES;"

cat > /etc/nginx/snippets/roundcube.conf <<EOF
location /roundcube {
    root /usr/share/;
    index index.php;
    location ~ ^/roundcube/(.+\.php)\$ {
        try_files \$uri =404;
        fastcgi_pass unix:/var/run/php/${PHP_VERSION}-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
}
EOF
sed -i '/server_name _;/a \    include snippets/roundcube.conf;' /etc/nginx/sites-available/shm-panel
systemctl reload nginx

# RainLoop
RAINLOOP_DIR="/var/www/rainloop"
mkdir -p $RAINLOOP_DIR
cd /tmp
curl -Lo rainloop-latest.zip https://www.rainloop.net/repository/webmail/rainloop-latest.zip
unzip rainloop-latest.zip -d $RAINLOOP_DIR
chown -R www-data:www-data $RAINLOOP_DIR
rm rainloop-latest.zip

cat > /etc/nginx/snippets/rainloop.conf <<EOF
location /rainloop {
    root $RAINLOOP_DIR;
    index index.php;
    location ~ ^/rainloop/(.+\.php)\$ {
        try_files \$uri =404;
        fastcgi_pass unix:/var/run/php/${PHP_VERSION}-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
}
EOF
sed -i '/server_name _;/a \    include snippets/rainloop.conf;' /etc/nginx/sites-available/shm-panel
systemctl reload nginx

# --- BACKUP & RESTORE ---
cat > /root/backup-shm.sh <<'EOF'
#!/bin/bash
BACKUP_DIR="/root/backups"; DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="shm-backup-$DATE"
mkdir -p $BACKUP_DIR
mysqldump --all-databases > $BACKUP_DIR/$BACKUP_NAME-mysql.sql
gzip $BACKUP_DIR/$BACKUP_NAME-mysql.sql
tar -czf $BACKUP_DIR/$BACKUP_NAME-files.tar.gz /var/www/shm-panel
tar -czf $BACKUP_DIR/$BACKUP_NAME-config.tar.gz /etc/nginx /etc/mysql /etc/php
find $BACKUP_DIR -name "shm-backup-*" -mtime +7 -delete
EOF
chmod +x /root/backup-shm.sh

cat > /root/restore-shm.sh <<'EOF'
#!/bin/bash
BACKUP_DIR="/root/backups"
if [ -z "$1" ]; then echo "Usage: $0 <backup-timestamp>"; exit 1; fi
BACKUP_NAME="shm-backup-$1"
gunzip -c $BACKUP_DIR/$BACKUP_NAME-mysql.sql.gz | mysql
tar -xzf $BACKUP_DIR/$BACKUP_NAME-files.tar.gz -C /
tar -xzf $BACKUP_DIR/$BACKUP_NAME-config.tar.gz -C /
systemctl restart mysql nginx
EOF
chmod +x /root/restore-shm.sh

# --- MONITORING ---
cat > /root/monitor-shm.sh <<'EOF'
#!/bin/bash
LOG_FILE="/var/log/shm-panel/monitor.log"; mkdir -p /var/log/shm-panel
{
for service in mysql nginx php*-fpm; do
    if systemctl is-active --quiet $service; then echo "✅ $service running"; else systemctl restart $service; echo "❌ $service restarted"; fi
done
df -h / | awk 'NR==2 {print "Disk usage: "$5}'
free -m | awk 'NR==2{printf "Memory usage: %.2f%\n",$3*100/$2}'
uptime | awk -F'load average:' '{print "Load avg:"$2}'
mysql -e "SHOW STATUS LIKE 'Threads_connected'" | awk 'NR==2{print "MySQL connections: "$2}'
} >> $LOG_FILE
tail -1000 $LOG_FILE > $LOG_FILE.tmp && mv $LOG_FILE.tmp $LOG_FILE
EOF
chmod +x /root/monitor-shm.sh

(crontab -l 2>/dev/null; echo "*/5 * * * * /root/monitor-shm.sh >/dev/null 2>&1") | crontab -
(crontab -l 2>/dev/null; echo "0 2 * * * /root/backup-shm.sh >/dev/null 2>&1") | crontab -

# --- FINAL INFO ---
systemctl restart mysql nginx $PHP_FPM fail2ban ssh
systemctl enable mysql nginx $PHP_FPM fail2ban ssh

log "Setup completed!"
echo "SSH Port: $SSH_PORT"
echo "Admin User: $ADMIN_USER"
echo "Admin Password: $ADMIN_PASSWORD"
echo "App User: $APP_USER"
echo "App Password: $APP_USER_PASSWORD"
echo "MySQL Root Password: $MYSQL_ROOT_PASSWORD"
echo "phpMyAdmin: http://$SERVER_IP/phpmyadmin"
echo "Roundcube: http://$SERVER_IP/roundcube"
echo "RainLoop: http://$SERVER_IP/rainloop"
