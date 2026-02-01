#!/bin/bash

################################################################################
# SHM PANEL - DOMAIN CREATION SCRIPT
# ============================================================================
# Purpose: Create a new domain with proper directory structure, Nginx config,
#          PHP-FPM socket, and automatic .htaccess conversion.
#
# Usage: add-domain.sh <domain> <username> [php_version]
#        add-domain.sh example.com client1 8.2
#
# Requirements:
#   - Root access (or sudo)
#   - Nginx installed and running
#   - PHP-FPM installed
#   - Proper file permissions
#
# Author: SHM Panel Team
# Version: 1.0 Production
################################################################################

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

DOMAIN="${1:-}"
USERNAME="${2:-}"
PHP_VERSION="${3:-8.2}"

# Base paths
CLIENTS_BASE="/var/www/clients"
NGINX_SITES_AVAILABLE="/etc/nginx/sites-available"
NGINX_SITES_ENABLED="/etc/nginx/sites-enabled"
PHP_FPM_POOL_DIR="/etc/php/$PHP_VERSION/fpm/pool.d"
LOGS_DIR="/var/log/shm-panel"
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "${LOGS_DIR}/domain-creation.log"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "${LOGS_DIR}/domain-creation.log"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "${LOGS_DIR}/domain-creation.log"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "${LOGS_DIR}/domain-creation.log"
}

# ============================================================================
# VALIDATION
# ============================================================================

validate_inputs() {
    log_info "Validating input parameters..."

    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi

    # Validate domain format
    if [[ ! $DOMAIN =~ ^([a-z0-9]+(-[a-z0-9]+)*\.)+[a-z]{2,}$ ]]; then
        log_error "Invalid domain format: $DOMAIN"
        exit 1
    fi

    # Validate username (alphanumeric + underscore)
    if [[ ! $USERNAME =~ ^[a-z0-9_-]+$ ]]; then
        log_error "Invalid username format: $USERNAME"
        exit 1
    fi

    # Validate PHP version format
    if [[ ! $PHP_VERSION =~ ^[0-9]\.[0-9]$ ]]; then
        log_error "Invalid PHP version format: $PHP_VERSION (use X.Y format, e.g., 8.2)"
        exit 1
    fi

    # Check if domain already exists
    if [[ -d "$CLIENTS_BASE/$DOMAIN" ]]; then
        log_error "Domain directory already exists: $CLIENTS_BASE/$DOMAIN"
        exit 1
    fi

    # Check if user exists in system
    if ! id "$USERNAME" &>/dev/null; then
        log_error "System user does not exist: $USERNAME"
        exit 1
    fi

    # Verify Nginx is installed
    if ! command -v nginx &>/dev/null; then
        log_error "Nginx is not installed"
        exit 1
    fi

    # Verify PHP-FPM is installed
    if ! command -v php-fpm$PHP_VERSION &>/dev/null; then
        log_error "PHP-FPM $PHP_VERSION is not installed"
        exit 1
    fi

    # Verify PHP-FPM pool directory exists
    if [[ ! -d "$PHP_FPM_POOL_DIR" ]]; then
        log_error "PHP-FPM pool directory not found: $PHP_FPM_POOL_DIR"
        exit 1
    fi

    log_success "All input validations passed"
}

# ============================================================================
# DIRECTORY STRUCTURE CREATION
# ============================================================================

create_directory_structure() {
    log_info "Creating directory structure for $DOMAIN..."

    local domain_path="$CLIENTS_BASE/$DOMAIN"
    local user_id
    local user_gid
    user_id=$(id -u "$USERNAME")
    user_gid=$(id -g "$USERNAME")

    # Create main domain directory
    mkdir -p "$domain_path"
    log_info "Created: $domain_path"

    # Create subdirectories
    mkdir -p "$domain_path/public_html"
    mkdir -p "$domain_path/logs"
    mkdir -p "$domain_path/nginx"
    mkdir -p "$domain_path/private"
    mkdir -p "$domain_path/backups"
    log_success "Created all subdirectories"

    # Set permissions: User owns their domain, web server can read/write logs
    chown -R "$user_id:$user_gid" "$domain_path"
    chmod -R 755 "$domain_path"
    chmod 770 "$domain_path/logs"
    chmod 770 "$domain_path/nginx"
    chmod 770 "$domain_path/private"
    chmod 770 "$domain_path/backups"
    log_success "Set permissions correctly"

    # Ensure public_html is web-accessible
    chmod 755 "$domain_path/public_html"
}

# ============================================================================
# DEFAULT FILES CREATION
# ============================================================================

create_default_files() {
    log_info "Creating default files for $DOMAIN..."

    local domain_path="$CLIENTS_BASE/$DOMAIN"
    local php_root="$domain_path/public_html"
    local user_id
    user_id=$(id -u "$USERNAME")

    # Create default index.php
    cat > "$php_root/index.php" << 'EOF'
<?php
/**
 * SHM Panel - Default Welcome Page
 * This is the default landing page. Replace this with your content.
 */
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Welcome to <?php echo htmlspecialchars($_SERVER['HTTP_HOST'] ?? 'Your Domain'); ?></title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            color: #333;
        }
        .container {
            background: white;
            border-radius: 10px;
            padding: 40px;
            max-width: 600px;
            box-shadow: 0 10px 40px rgba(0, 0, 0, 0.1);
            text-align: center;
        }
        h1 {
            color: #667eea;
            margin-bottom: 10px;
        }
        .domain {
            font-size: 18px;
            color: #666;
            margin-bottom: 30px;
            font-family: 'Courier New', monospace;
        }
        .content {
            line-height: 1.6;
            color: #555;
        }
        .footer {
            margin-top: 30px;
            padding-top: 20px;
            border-top: 1px solid #eee;
            font-size: 12px;
            color: #999;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Welcome!</h1>
        <div class="domain"><?php echo htmlspecialchars($_SERVER['HTTP_HOST'] ?? 'Your Domain'); ?></div>
        <div class="content">
            <p>Your domain is up and running on SHM Panel.</p>
            <p>Replace this file with your own content at <code>/public_html/index.php</code></p>
        </div>
        <div class="footer">
            <p>Powered by <strong>SHM Panel</strong> - Premium Hosting Control Panel</p>
        </div>
    </div>
</body>
</html>
EOF

    chown "$user_id:$user_id" "$php_root/index.php"
    chmod 644 "$php_root/index.php"
    log_success "Created default index.php"

    # Create default .htaccess with common rules
    cat > "$php_root/.htaccess" << 'EOF'
# ============================================================================
# SHM Panel - Auto-Generated .htaccess
# ============================================================================
# These rules are automatically converted to Nginx syntax and applied.
# Modify this file to change URL rewriting behavior.
# Changes are detected automatically and applied within seconds.
#
# Supported Rules:
#   - RewriteRule (most common patterns)
#   - RewriteCond
#   - Force HTTPS
#   - Clean URLs (PHP file hiding)
# ============================================================================

<IfModule mod_rewrite.c>
    RewriteEngine On

    # --- SECURITY ---
    # Prevent direct access to sensitive files
    RewriteRule ^\.htaccess$ - [F]
    RewriteRule ^\.git - [F]
    RewriteRule ^\.env - [F]
    RewriteRule ^composer\.(json|lock) - [F]

    # --- CLEAN URLs (PHP HIDING) ---
    # Convert /page to /page.php (if page.php exists)
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteCond %{REQUEST_FILENAME} !-d
    RewriteRule ^([a-zA-Z0-9_-]+)/?$ $1.php [QSA,L]

    # --- FORCE TRAILING SLASH ---
    # RewriteCond %{REQUEST_FILENAME} !-f
    # RewriteCond %{REQUEST_FILENAME} !-d
    # RewriteRule ^(.+)$ /$1/ [R=301,L]

    # --- FORCE HTTPS (uncomment to enable) ---
    # RewriteCond %{HTTPS} !=on
    # RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [R=301,L]

</IfModule>
EOF

    chown "$user_id:$user_id" "$php_root/.htaccess"
    chmod 644 "$php_root/.htaccess"
    log_success "Created default .htaccess"
}

# ============================================================================
# NGINX CONFIGURATION
# ============================================================================

create_nginx_config() {
    log_info "Creating Nginx server block for $DOMAIN..."

    local domain_path="$CLIENTS_BASE/$DOMAIN"
    local nginx_config="$NGINX_SITES_AVAILABLE/$DOMAIN.conf"
    local fpm_socket="/run/php/php${PHP_VERSION}-fpm-${DOMAIN}.sock"

    # Validate domain_path exists and is readable
    if [[ ! -d "$domain_path/public_html" ]]; then
        log_error "Domain public_html directory does not exist: $domain_path/public_html"
        exit 1
    fi

    # Create Nginx server block
    cat > "$nginx_config" << NGINX_CONFIG
# ============================================================================
# SHM Panel - Nginx Server Block for $DOMAIN
# ============================================================================
# Auto-generated on: $(date)
# Do NOT edit this file manually - it is managed by SHM Panel
# ============================================================================

server {
    listen 80;
    listen [::]:80;
    
    server_name $DOMAIN www.$DOMAIN;
    
    # --- PATHS (CRITICAL) ---
    root $domain_path/public_html;
    
    # --- LOGGING ---
    access_log $domain_path/logs/access.log combined;
    error_log $domain_path/logs/error.log warn;
    
    # --- SECURITY HEADERS ---
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    
    # --- GZIP COMPRESSION ---
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript 
               application/json application/javascript application/xml+rss 
               application/atom+xml image/svg+xml;
    
    # --- STATIC FILES CACHE ---
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
    
    # --- DENY DIRECT ACCESS TO SENSITIVE FILES ---
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
    
    location ~ ~$ {
        deny all;
        access_log off;
        log_not_found off;
    }
    
    # --- DENY ACCESS TO SENSITIVE PATHS ---
    location ~ ^/(wp-admin|wp-includes|wp-content/plugins)/ {
        deny all;
    }
    
    # --- PHP-FPM CONFIGURATION ---
    location ~ \.php$ {
        # CRITICAL: Use domain-specific PHP-FPM socket
        fastcgi_pass unix:$fpm_socket;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
        
        # Timeouts
        fastcgi_connect_timeout 60s;
        fastcgi_send_timeout 60s;
        fastcgi_read_timeout 60s;
        
        # Don't allow access to PHP files in upload directories
        location ~ /(uploads|files)/.*\.php$ {
            deny all;
        }
    }
    
    # --- HTACCESS REWRITES (AUTO-CONVERTED) ---
    # These rules are automatically generated from .htaccess
    include $domain_path/nginx/rewrites.conf;
    
    # --- DEFAULT LOCATION ---
    location / {
        # Try to serve file directly, if not redirect to index.php
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
}
NGINX_CONFIG

    log_success "Created Nginx server block: $nginx_config"
}

# ============================================================================
# PHP-FPM SOCKET CREATION
# ============================================================================

create_php_fpm_socket() {
    log_info "Creating PHP-FPM socket pool for $DOMAIN..."

    local domain_path="$CLIENTS_BASE/$DOMAIN"
    local pool_name="$DOMAIN"
    local pool_file="$PHP_FPM_POOL_DIR/$pool_name.conf"
    local fpm_socket="/run/php/php${PHP_VERSION}-fpm-${DOMAIN}.sock"
    local user_id
    user_id=$(id -u "$USERNAME")

    # Check if pool already exists
    if [[ -f "$pool_file" ]]; then
        log_warn "PHP-FPM pool already exists, removing old one..."
        rm -f "$pool_file"
    fi

    # Create PHP-FPM pool configuration
    cat > "$pool_file" << PHP_FPM_CONFIG
; ============================================================================
; SHM Panel - PHP-FPM Pool Configuration for $DOMAIN
; ============================================================================
; Auto-generated on: $(date)
; Do NOT edit this file manually
; ============================================================================

[$pool_name]
; Process pooling
pm = dynamic
pm.max_children = 20
pm.start_servers = 5
pm.min_spare_servers = 3
pm.max_spare_servers = 10
pm.max_requests = 500

; User/Group
user = $USERNAME
group = $USERNAME

; Socket
listen = $fpm_socket
listen.owner = www-data
listen.group = www-data
listen.mode = 0660

; PHP Settings (inherited from php.ini)
php_admin_value[upload_max_filesize] = 100M
php_admin_value[post_max_size] = 100M
php_admin_value[memory_limit] = 256M
php_admin_value[max_execution_time] = 300

; Security
php_admin_value[disable_functions] = system,exec,shell_exec,passthru,proc_open,proc_nice
php_admin_value[display_errors] = Off
php_admin_flag[log_errors] = On
php_admin_value[error_log] = $domain_path/logs/php-error.log

; Environment
env[DOMAIN] = $DOMAIN
env[PHP_VERSION] = $PHP_VERSION

; Logging
catch_workers_output = yes
access.log = $domain_path/logs/php-access.log
access.format = "%R - %u %t \"%m %r\" %s %Q %T %f %C %M %e %w %d %e"

; Timeout
request_terminate_timeout = 300
request_slowlog_timeout = 10s
slowlog = $domain_path/logs/php-slow.log
PHP_FPM_CONFIG

    log_success "Created PHP-FPM pool: $pool_file"

    # Ensure log directory exists and has proper permissions
    local user_id
    user_id=$(id -u "$USERNAME")
    touch "$domain_path/logs/php-error.log" "$domain_path/logs/php-access.log" "$domain_path/logs/php-slow.log"
    chown "$user_id:$user_id" "$domain_path/logs/php-"*.log
    chmod 644 "$domain_path/logs/php-"*.log
}

# ============================================================================
# REWRITES CONF INITIALIZATION
# ============================================================================

init_rewrites_conf() {
    log_info "Initializing rewrites.conf for $DOMAIN..."

    local domain_path="$CLIENTS_BASE/$DOMAIN"
    local rewrites_file="$domain_path/nginx/rewrites.conf"

    # Create empty rewrites.conf with header comment
    cat > "$rewrites_file" << 'REWRITES'
# ============================================================================
# SHM Panel - Nginx Rewrites for Automatic .htaccess Conversion
# ============================================================================
# This file is AUTO-GENERATED from .htaccess by the SHM Panel htaccess converter.
# DO NOT EDIT THIS FILE MANUALLY.
# 
# Timestamp: Will be updated whenever .htaccess is modified
# Monitored by: shm-htaccess-watcher.service
# ============================================================================

# Placeholder: Rules will be generated from .htaccess on first conversion
REWRITES

    local user_id
    user_id=$(id -u "$USERNAME")
    chown "$user_id:$user_id" "$rewrites_file"
    chmod 644 "$rewrites_file"

    log_success "Initialized rewrites.conf"

    # Convert .htaccess immediately
    if command -v htaccess-converter &>/dev/null; then
        log_info "Running initial .htaccess conversion..."
        htaccess-converter "$domain_path" 2>&1 || log_warn "Initial .htaccess conversion failed (may be expected)"
    fi
}

# ============================================================================
# NGINX SITE ENABLEMENT
# ============================================================================

enable_nginx_site() {
    log_info "Enabling Nginx site: $DOMAIN..."

    local domain_path="$CLIENTS_BASE/$DOMAIN"
    local nginx_config="$NGINX_SITES_AVAILABLE/$DOMAIN.conf"
    local nginx_enabled="$NGINX_SITES_ENABLED/$DOMAIN.conf"

    # Create symlink
    if [[ ! -L "$nginx_enabled" ]]; then
        ln -s "$nginx_config" "$nginx_enabled"
        log_success "Created Nginx symlink"
    fi
}

# ============================================================================
# NGINX VALIDATION & RELOAD
# ============================================================================

validate_and_reload_nginx() {
    log_info "Validating Nginx configuration..."

    # Test Nginx syntax
    if ! nginx -t 2>&1 | grep -q "successful"; then
        log_error "Nginx configuration test failed!"
        log_error "Rolling back changes..."
        
        # Rollback: remove symlink
        rm -f "$NGINX_SITES_ENABLED/$DOMAIN.conf"
        
        # Remove Nginx config
        rm -f "$NGINX_SITES_AVAILABLE/$DOMAIN.conf"
        
        log_error "Domain creation failed due to Nginx config errors"
        exit 1
    fi

    log_success "Nginx configuration is valid"

    # Reload Nginx (graceful reload)
    log_info "Reloading Nginx..."
    if systemctl reload nginx; then
        log_success "Nginx reloaded successfully"
    else
        log_error "Failed to reload Nginx"
        rm -f "$NGINX_SITES_ENABLED/$DOMAIN.conf"
        exit 1
    fi
}

# ============================================================================
# PHP-FPM SERVICE RESTART
# ============================================================================

restart_php_fpm() {
    log_info "Restarting PHP-FPM $PHP_VERSION..."

    if systemctl restart "php$PHP_VERSION-fpm"; then
        log_success "PHP-FPM restarted successfully"
    else
        log_error "Failed to restart PHP-FPM"
        exit 1
    fi
}

# ============================================================================
# VERIFICATION
# ============================================================================

verify_domain_creation() {
    log_info "Verifying domain creation..."

    local domain_path="$CLIENTS_BASE/$DOMAIN"
    local checks_passed=0
    local checks_total=0

    # Check 1: Directory structure
    checks_total=$((checks_total + 1))
    if [[ -d "$domain_path/public_html" ]] && [[ -d "$domain_path/logs" ]] && [[ -d "$domain_path/nginx" ]]; then
        log_success "✓ Directory structure verified"
        checks_passed=$((checks_passed + 1))
    else
        log_error "✗ Directory structure incomplete"
    fi

    # Check 2: Nginx config
    checks_total=$((checks_total + 1))
    if [[ -f "$NGINX_SITES_AVAILABLE/$DOMAIN.conf" ]] && [[ -L "$NGINX_SITES_ENABLED/$DOMAIN.conf" ]]; then
        log_success "✓ Nginx configuration verified"
        checks_passed=$((checks_passed + 1))
    else
        log_error "✗ Nginx configuration missing"
    fi

    # Check 3: PHP-FPM pool
    checks_total=$((checks_total + 1))
    if [[ -f "$PHP_FPM_POOL_DIR/$DOMAIN.conf" ]]; then
        log_success "✓ PHP-FPM pool verified"
        checks_passed=$((checks_passed + 1))
    else
        log_error "✗ PHP-FPM pool missing"
    fi

    # Check 4: Rewrites file
    checks_total=$((checks_total + 1))
    if [[ -f "$domain_path/nginx/rewrites.conf" ]]; then
        log_success "✓ Rewrites configuration verified"
        checks_passed=$((checks_passed + 1))
    else
        log_error "✗ Rewrites configuration missing"
    fi

    # Check 5: Default files
    checks_total=$((checks_total + 1))
    if [[ -f "$domain_path/public_html/index.php" ]] && [[ -f "$domain_path/public_html/.htaccess" ]]; then
        log_success "✓ Default files verified"
        checks_passed=$((checks_passed + 1))
    else
        log_error "✗ Default files missing"
    fi

    log_info "Verification: $checks_passed/$checks_total checks passed"

    if [[ $checks_passed -eq $checks_total ]]; then
        return 0
    else
        return 1
    fi
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║           SHM PANEL - DOMAIN CREATION SCRIPT                   ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    
    log_info "Starting domain creation for: $DOMAIN (user: $USERNAME, PHP: $PHP_VERSION)"

    # Create logs directory
    mkdir -p "$LOGS_DIR"

    # Validate inputs
    validate_inputs

    # Create directory structure
    create_directory_structure

    # Create default files
    create_default_files

    # Create Nginx configuration
    create_nginx_config

    # Create PHP-FPM socket pool
    create_php_fpm_socket

    # Initialize rewrites configuration
    init_rewrites_conf

    # Enable Nginx site
    enable_nginx_site

    # Validate and reload Nginx
    validate_and_reload_nginx

    # Restart PHP-FPM
    restart_php_fpm

    # Verify
    if verify_domain_creation; then
        log_success "Domain created successfully!"
        echo ""
        echo "╔════════════════════════════════════════════════════════════════╗"
        echo "║                    DOMAIN READY TO USE                         ║"
        echo "╚════════════════════════════════════════════════════════════════╝"
        echo ""
        echo "Domain:     $DOMAIN"
        echo "Path:       $CLIENTS_BASE/$DOMAIN"
        echo "User:       $USERNAME"
        echo "PHP:        $PHP_VERSION"
        echo ""
        echo "Next Steps:"
        echo "  1. Edit .htaccess at: $CLIENTS_BASE/$DOMAIN/public_html/.htaccess"
        echo "  2. Add your files to: $CLIENTS_BASE/$DOMAIN/public_html/"
        echo "  3. Configure DNS to point to this server"
        echo ""
        exit 0
    else
        log_error "Domain verification failed!"
        exit 1
    fi
}

# Run main function
main "$@"
