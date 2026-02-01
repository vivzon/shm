# SHM Panel - Domain Management System

> **Production-Grade Nginx + PHP-FPM Domain Management with Automatic .htaccess Conversion**

---

## 📋 Overview

This domain management system provides:

✅ **Strict Directory Structure**
- Isolated domain directories with proper permissions
- Public web root at `/var/www/clients/{domain}/public_html`
- Per-domain logging and configuration
- PHP-FPM socket isolation

✅ **Nginx Integration**
- Auto-generated server blocks with proper root paths
- Domain-specific PHP-FPM sockets
- Automatic .htaccess to Nginx conversion
- Safe reload with validation
- Security headers and gzip compression

✅ **Automatic .htaccess Conversion**
- Monitors .htaccess changes via inotify
- Converts Apache rewrite rules to Nginx syntax
- Auto-applies changes with safe validation
- No manual Nginx editing required

✅ **Error Prevention**
- Validates paths before operations
- Tests Nginx syntax before reload
- Atomic file writes with backups
- Automatic rollback on failure

---

## 🚀 Installation

### 1. Install the Domain Management System

```bash
cd /path/to/shm-panel/scripts
sudo chmod +x install-domain-management.sh
sudo ./install-domain-management.sh
```

This installs:
- `/usr/local/bin/add-domain` - Domain creation script
- `/usr/local/bin/htaccess-converter` - .htaccess converter
- `/usr/local/bin/shm-htaccess-watcher` - inotify watcher daemon
- `/etc/systemd/system/shm-htaccess-watcher.service` - Systemd service

### 2. Verify Installation

```bash
# Check if scripts are installed
ls -lah /usr/local/bin/add-domain
ls -lah /usr/local/bin/htaccess-converter
ls -lah /usr/local/bin/shm-htaccess-watcher

# Check service status
systemctl status shm-htaccess-watcher

# View logs
journalctl -u shm-htaccess-watcher -f
```

---

## 📝 Usage

### Creating a Domain

```bash
# Syntax
sudo add-domain <domain> <username> [php_version]

# Example
sudo add-domain example.com client1 8.2
```

**What this does:**

1. ✓ Creates directory structure:
   ```
   /var/www/clients/example.com/
   ├── public_html/          (website files)
   ├── logs/                 (access & error logs)
   ├── nginx/                (rewrites.conf)
   └── private/              (private files)
   ```

2. ✓ Creates default files:
   - `public_html/index.php` - Welcome page
   - `public_html/.htaccess` - Default rewrite rules
   - `nginx/rewrites.conf` - Auto-generated from .htaccess

3. ✓ Sets up Nginx:
   - Creates server block at `/etc/nginx/sites-available/example.com.conf`
   - Enables site with symlink to `/etc/nginx/sites-enabled/`
   - Tests configuration with `nginx -t`
   - Reloads Nginx gracefully

4. ✓ Configures PHP-FPM:
   - Creates pool at `/etc/php/8.2/fpm/pool.d/example.com.conf`
   - Uses domain-specific socket: `/run/php/php8.2-fpm-example.com.sock`
   - Sets process limits and memory settings
   - Restarts PHP-FPM service

5. ✓ Auto-converts .htaccess:
   - Runs initial conversion
   - Starts watching for changes
   - Applies updates automatically

### Removing a Domain

```bash
# Interactive removal (asks for confirmation)
sudo remove-domain example.com

# Force removal (no confirmation)
sudo remove-domain example.com --force
```

**What this does:**

1. Creates backup at `/var/backups/shm-panel-example.com-{timestamp}.tar.gz`
2. Removes Nginx configuration and symlink
3. Removes PHP-FPM pool
4. Deletes domain directory
5. Reloads Nginx safely

### Listing Domains

```bash
# List all domains
sudo list-domains

# List domains for specific user
sudo list-domains client1
```

### Getting Domain Info

```bash
sudo domain-info example.com
```

Shows:
- Domain ownership
- Directory sizes
- Log line counts
- Nginx status
- PHP-FPM configuration
- Rewrites configuration

### Manual .htaccess Conversion

```bash
sudo htaccess-converter /var/www/clients/example.com
```

Triggers immediate conversion and Nginx reload.

---

## 🔧 .htaccess Conversion

### Supported Rules

The converter automatically handles:

#### ✅ Clean URLs (PHP Extension Hiding)
```apache
RewriteRule ^([a-zA-Z0-9_-]+)/?$ $1.php [QSA,L]
```
Converts to:
```nginx
rewrite ^/([a-zA-Z0-9_-]+)/?$ /$1.php last;
```

**Example:**
- Request: `/login`
- Serves: `/login.php`

#### ✅ Force HTTPS
```apache
RewriteCond %{HTTPS} !=on
RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [R=301,L]
```

#### ✅ Deny Sensitive Files
```apache
RewriteRule ^\.htaccess$ - [F]
RewriteRule ^\.env$ - [F]
RewriteRule ^\.git - [F]
```

#### ✅ SEO-Friendly URLs with Parameters
```apache
RewriteRule ^products/([0-9]+)/(.*)$ products.php?id=$1&name=$2 [QSA,L]
```

#### ✅ Query String Forwarding
```apache
RewriteRule ^search/(.*)$ search.php?q=$1 [QSA,L]
```

### Unsupported Rules

The converter will warn about:
- Complex regex patterns
- Advanced RewriteCond conditions
- ModSecurity directives
- htpasswd authentication

For these, you must manually add to `nginx/rewrites.conf`.

### Default Rules

If no .htaccess exists, default rules are auto-generated:

```nginx
# Clean URLs: Remove .php extension
location / {
    try_files $uri $uri/ /index.php?$query_string;
}

# Prevent direct access to hidden files
location ~ /\. {
    deny all;
}
```

---

## 📂 Directory Structure

Each domain gets this structure:

```
/var/www/clients/{domain}/
│
├── public_html/                  # Website root (served by Nginx)
│   ├── index.php                 # Entry point
│   ├── .htaccess                 # Rewrite rules (user-editable)
│   └── assets/                   # CSS, JS, images
│
├── logs/                         # Domain logs
│   ├── access.log                # HTTP access log
│   ├── error.log                 # HTTP error log
│   ├── php-error.log             # PHP error log
│   ├── php-access.log            # PHP-FPM access log
│   └── php-slow.log              # PHP slow requests
│
├── nginx/                        # Nginx configuration (auto-generated)
│   └── rewrites.conf             # Auto-converted from .htaccess
│
├── private/                      # Private files (not web-accessible)
│   └── config.php                # Private configuration
│
└── backups/                      # Domain backups
    └── backup-{date}.tar.gz      # Automatic backups
```

---

## 🔐 Nginx Server Block

Auto-generated at `/etc/nginx/sites-available/{domain}.conf`:

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name example.com www.example.com;
    
    # CRITICAL: Root path (never NULL)
    root /var/www/clients/example.com/public_html;
    
    # Logging
    access_log /var/www/clients/example.com/logs/access.log combined;
    error_log /var/www/clients/example.com/logs/error.log warn;
    
    # PHP-FPM socket (domain-specific)
    location ~ \.php$ {
        fastcgi_pass unix:/run/php/php8.2-fpm-example.com.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
    
    # Auto-converted .htaccess rules
    include /var/www/clients/example.com/nginx/rewrites.conf;
    
    # Default location
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
}
```

**Key Features:**

- ✅ Root path always defined (never NULL)
- ✅ Domain-specific PHP-FPM socket
- ✅ Includes auto-converted rewrites
- ✅ Security headers built-in
- ✅ Gzip compression enabled
- ✅ Static file caching configured

---

## 🔄 Automatic .htaccess Monitoring

The `shm-htaccess-watcher` service monitors all domains:

```bash
# Service status
systemctl status shm-htaccess-watcher

# View logs
journalctl -u shm-htaccess-watcher -f

# Restart service
systemctl restart shm-htaccess-watcher

# Stop service
systemctl stop shm-htaccess-watcher
```

**How it works:**

1. Service starts on boot (systemd)
2. Uses inotify to watch `/var/www/clients/*/public_html/.htaccess`
3. When .htaccess changes:
   - Waits 2 seconds for write to complete
   - Calls `htaccess-converter`
   - Validates Nginx syntax
   - Reloads Nginx if valid
   - Logs all operations

**Logs:**
- Service logs: `journalctl -u shm-htaccess-watcher`
- Detailed logs: `/var/log/shm-panel/htaccess-watcher.log`

---

## 🛡️ Security Features

### Admin Panel Not Exposed

Each domain server block includes:
```nginx
location ~ ^/(admin|client|whm|landing)/ {
    return 444;
}
```

This prevents admin panel exposure on user domains.

### Hidden Files Protection

```nginx
location ~ /\. {
    deny all;  # Block .git, .env, .htaccess, etc.
}
```

### Sensitive File Blocking

```nginx
location ~ ~$ {
    deny all;  # Block editor backup files
}
```

### PHP in Upload Dirs

```nginx
location ~ /(uploads|files)/.*\.php$ {
    deny all;  # Prevent PHP execution in uploads
}
```

### Security Headers

```nginx
add_header X-Frame-Options "SAMEORIGIN";
add_header X-Content-Type-Options "nosniff";
add_header X-XSS-Protection "1; mode=block";
```

---

## 🐛 Troubleshooting

### Domain Not Loading

```bash
# Check if site is enabled
ls -lah /etc/nginx/sites-enabled/example.com.conf

# Verify Nginx config
sudo nginx -t

# Check domain directory
ls -lah /var/www/clients/example.com/

# Check PHP-FPM socket
ls -lah /run/php/php8.2-fpm-example.com.sock
```

### .htaccess Not Converting

```bash
# Check watcher status
systemctl status shm-htaccess-watcher

# View watcher logs
journalctl -u shm-htaccess-watcher -n 50

# Manually trigger conversion
sudo htaccess-converter /var/www/clients/example.com

# Check rewrites.conf
cat /var/www/clients/example.com/nginx/rewrites.conf
```

### Nginx Won't Reload

```bash
# Test configuration
sudo nginx -t

# Check for syntax errors
sudo nginx -T | grep example.com

# View error logs
sudo tail -f /var/log/nginx/error.log
```

### PHP-FPM Issues

```bash
# Check if socket exists
ls -lah /run/php/php8.2-fpm-example.com.sock

# Check PHP-FPM status
systemctl status php8.2-fpm

# View PHP-FPM logs
tail -f /var/www/clients/example.com/logs/php-error.log
```

---

## 📊 Logs

### Domain Creation Logs
```bash
cat /var/log/shm-panel/domain-creation.log
```

### Htaccess Watcher Logs
```bash
journalctl -u shm-htaccess-watcher -f
cat /var/log/shm-panel/htaccess-watcher.log
```

### Domain Access Logs
```bash
tail -f /var/www/clients/example.com/logs/access.log
tail -f /var/www/clients/example.com/logs/error.log
tail -f /var/www/clients/example.com/logs/php-error.log
```

---

## 📋 Integration with SHM Panel PHP

### In cpanel/domains.php

Add domain creation:

```php
<?php
require_once dirname(__DIR__) . '/shared/domain-management.php';

if ($_POST['ajax_action'] == 'add_domain') {
    $result = create_domain(
        $_POST['domain'],
        $_SESSION['client'],
        $_POST['php_version'] ?? '8.2'
    );
    echo json_encode($result);
    exit;
}
?>
```

### In whm/accounts.php

Add domain management for admins:

```php
<?php
require_once dirname(__DIR__) . '/shared/domain-management.php';

if ($_POST['action'] == 'create_client_domain') {
    $result = create_domain(
        $_POST['domain'],
        $_POST['username'],
        $_POST['php_version'] ?? '8.2'
    );
    echo json_encode($result);
    exit;
}
?>
```

---

## 🔧 Configuration

### PHP-FPM Pool Limits

Edit `/etc/php/8.2/fpm/pool.d/{domain}.conf`:

```ini
pm = dynamic
pm.max_children = 20          # Max processes
pm.start_servers = 5          # Initial processes
pm.min_spare_servers = 3      # Min idle
pm.max_spare_servers = 10     # Max idle
pm.max_requests = 500         # Restart after N requests
```

### Nginx Server Block

Edit `/etc/nginx/sites-available/{domain}.conf`:

After editing, test and reload:
```bash
sudo nginx -t
sudo systemctl reload nginx
```

### .htaccess Rules

Edit `/var/www/clients/{domain}/public_html/.htaccess`:

The watcher will auto-convert within 2-3 seconds.

---

## 🚀 Performance Tuning

### Gzip Compression

Enabled by default. To adjust:

```nginx
gzip_comp_level 6;  # 1-9 (higher = slower but better)
```

### Static File Caching

Files cached for 30 days:
```nginx
expires 30d;
```

### PHP-FPM Timeouts

Configured in pool:
```ini
request_terminate_timeout = 300  # 5 minutes
```

### Request Limits

In Nginx:
```nginx
fastcgi_read_timeout 60s;
fastcgi_send_timeout 60s;
```

---

## 📞 Support

For issues:

1. **Check logs:**
   ```bash
   journalctl -u shm-htaccess-watcher -f
   cat /var/log/shm-panel/domain-creation.log
   ```

2. **Verify installation:**
   ```bash
   /usr/local/bin/add-domain --help
   ```

3. **Test Nginx:**
   ```bash
   sudo nginx -t
   sudo systemctl reload nginx
   ```

---

## 📝 License

Part of **SHM Panel** - (c) 2026 Vivzon Cloud. All Rights Reserved.
