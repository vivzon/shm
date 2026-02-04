#!/bin/bash

# SHM Master Installation Script
# Supports: Ubuntu 22.04 / 24.04 LTS

set -e

echo "Starting SHM Installation..."

# 1. Update System
apt update && apt upgrade -y

# 2. Install Dependencies
apt install -y nginx mariadb-server php-fpm php-mysql php-xml php-mbstring \
    php-curl php-zip php-gd php-intl php-bcmath curl git unzip zip \
    certbot python3-certbot-nginx redis-server supervisor ufw fail2ban

# 3. Secure MySQL
# (In a real script, we would handle this interactively or with a seed)
# For now, we assume it's a fresh install.

# 4. Setup SHM Directory Structure
SHM_BASE="/usr/local/shm"
mkdir -p "$SHM_BASE"
mkdir -p "$SHM_BASE/scripts"
mkdir -p "$SHM_BASE/templates"
mkdir -p "$SHM_BASE/logs"

# Copy scripts and templates (this assumes we are running from the cloned repo)
cp -r scripts/* "$SHM_BASE/scripts/"
cp -r templates/* "$SHM_BASE/templates/"
chmod +x "$SHM_BASE/scripts/"*.sh
chmod +x "$SHM_BASE/scripts/shm-manage"

# 5. Symbolic link for shm-manage
ln -sf "$SHM_BASE/scripts/shm-manage" /usr/local/bin/shm-manage

# 6. Configure Sudoers for Laravel (panel user)
# We will assume 'shm-panel' is the user running the Laravel app.
# echo "shm-panel ALL=(ALL) NOPASSWD: /usr/local/bin/shm-manage" > /etc/sudoers.d/shm

# 7. Setup Firewall
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw allow 3306
ufw --force enable

echo "SHM Infrastructure Installed Successfully!"
echo "Next step: Scaffold the Laravel Web Panel."
