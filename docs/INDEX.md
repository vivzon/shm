# SHM Panel - Domain Management System
# Complete Implementation Guide

---

## 📦 What You're Getting

A **production-grade, enterprise-safe domain management system** for SHM Panel with:

✅ **Automatic domain creation** with proper Nginx + PHP-FPM setup  
✅ **Automatic .htaccess conversion** to Nginx syntax via inotify  
✅ **Zero manual Nginx editing** - users only edit .htaccess  
✅ **True domain isolation** - per-domain PHP-FPM sockets  
✅ **Safe operations** - validates before reload, atomic writes, auto-rollback  
✅ **Production tested** - comprehensive error handling & logging  

---

## 📁 File Structure

```
shm-panel/
├── scripts/
│   ├── add-domain.sh                          (~2,200 lines - Main script)
│   ├── htaccess-converter.sh                  (~1,200 lines - Converter)
│   ├── shm-htaccess-watcher.sh                (~600 lines - Watcher)
│   ├── shm-domain-commands.sh                 (~400 lines - CLI wrapper)
│   └── install-domain-management.sh           (~400 lines - Installer)
│
├── shared/
│   └── domain-management.php                  (~400 lines - PHP integration)
│
├── systemd/
│   └── shm-htaccess-watcher.service           (Systemd service unit)
│
├── docs/
│   ├── DOMAIN_MANAGEMENT.md                   (Complete guide)
│   └── DOMAIN_QUICK_REFERENCE.md              (Quick commands)
│
├── examples/
│   └── CPANEL_DOMAINS_INTEGRATION.php         (Integration example)
│
└── DOMAIN_SYSTEM_SUMMARY.md                   (This overview)
```

---

## 🚀 Quick Start

### 1. Install the System

```bash
# Run the installer
sudo /path/to/shm-panel/scripts/install-domain-management.sh

# Verify installation
systemctl status shm-htaccess-watcher
ls -lah /usr/local/bin/add-domain
```

### 2. Create Your First Domain

```bash
sudo add-domain example.com client1 8.2
```

### 3. Verify Domain Works

```bash
# Check it's enabled
ls /etc/nginx/sites-enabled/example.com.conf

# Check PHP-FPM socket
ls /run/php/php8.2-fpm-example.com.sock

# Check website loads
curl -I http://example.com/
```

### 4. Test .htaccess Auto-Conversion

```bash
# Edit .htaccess
nano /var/www/clients/example.com/public_html/.htaccess

# Make a change and save
# The service will auto-convert within 2-3 seconds

# Verify conversion
cat /var/www/clients/example.com/nginx/rewrites.conf
```

---

## 📚 Documentation Map

| Document | Purpose | Read Time |
|----------|---------|-----------|
| **DOMAIN_MANAGEMENT.md** | Comprehensive guide with all features | 15 min |
| **DOMAIN_QUICK_REFERENCE.md** | Quick command reference | 3 min |
| **DOMAIN_SYSTEM_SUMMARY.md** | Technical overview & architecture | 10 min |
| **CPANEL_DOMAINS_INTEGRATION.php** | Code integration example | 10 min |

---

## 🎯 Key Features Explained

### ✨ Automatic Domain Creation

When you run `sudo add-domain example.com client1 8.2`:

1. ✓ Creates `/var/www/clients/example.com/` structure
2. ✓ Creates default `index.php` and `.htaccess`
3. ✓ Generates Nginx server block (no NULL root!)
4. ✓ Creates PHP-FPM pool with domain-specific socket
5. ✓ Enables site and reloads Nginx safely
6. ✓ Converts `.htaccess` to Nginx rules
7. ✓ Starts monitoring for `.htaccess` changes

**Result:** Domain is LIVE and ready to use.

### 🔄 Automatic .htaccess Conversion

When user edits `.htaccess`:

1. inotify detects file change
2. `shm-htaccess-watcher` (running as service) is notified
3. Parses Apache rewrite rules
4. Converts to Nginx syntax
5. Writes to `nginx/rewrites.conf`
6. Validates Nginx config
7. Reloads Nginx gracefully
8. Logs the operation

**Result:** Changes take effect in 2-3 seconds, no manual intervention.

### 🛡️ Safety Features

**All operations are safe:**
- ✓ Input validation on all parameters
- ✓ Path existence checks
- ✓ Nginx syntax validation before reload
- ✓ Atomic file writes with backups
- ✓ Automatic rollback on failure
- ✓ Comprehensive error logging
- ✓ No silent failures

### 🔐 Security Hardening

**Every domain is locked down:**
- ✓ No NULL roots (impossible to serve wrong content)
- ✓ Admin panel never exposed on user domains
- ✓ Hidden files (`.env`, `.git`) blocked
- ✓ PHP in uploads directory blocked
- ✓ Security headers configured
- ✓ Domain isolation via PHP-FPM sockets

---

## 📋 All Commands

### Domain Creation
```bash
sudo add-domain example.com client1 8.2
```

### Domain Removal
```bash
sudo remove-domain example.com
sudo remove-domain example.com --force
```

### List Domains
```bash
sudo list-domains
sudo list-domains client1
```

### Domain Information
```bash
sudo domain-info example.com
```

### Manual .htaccess Conversion
```bash
sudo htaccess-converter /var/www/clients/example.com
```

### Enable/Disable Domain
```bash
sudo enable-domain example.com
sudo disable-domain example.com
```

### Service Management
```bash
systemctl status shm-htaccess-watcher
systemctl restart shm-htaccess-watcher
journalctl -u shm-htaccess-watcher -f
```

---

## 🔗 Integration Points

### PHP Integration

```php
require_once 'shared/domain-management.php';

// Create domain via PHP
$result = create_domain('example.com', 'client1', '8.2');

// Remove domain
$result = remove_domain('example.com');

// Manual conversion
$result = convert_htaccess('example.com');

// Get domain info
$info = get_domain_info('example.com');
```

### Bash Integration (shm-manage)

Add these functions to shm-manage:
```bash
cmd_add_domain <domain> <user> [php_version]
cmd_remove_domain <domain>
cmd_list_domains [user]
cmd_convert_htaccess <domain_path>
cmd_enable_domain <domain>
cmd_disable_domain <domain>
cmd_domain_info <domain>
```

See `scripts/shm-domain-commands.sh` for implementation.

### Web UI Integration

Example included in `examples/CPANEL_DOMAINS_INTEGRATION.php`:
- Add domain form
- Domain list with actions
- .htaccess conversion button
- Domain info modal
- Delete with confirmation

---

## ⚙️ Technical Details

### Directory Structure per Domain

```
/var/www/clients/example.com/
├── public_html/                 # Website root
│   ├── index.php                # Default page
│   ├── .htaccess                # User edits these
│   └── assets/                  # Static files
├── logs/                        # All logs
│   ├── access.log
│   ├── error.log
│   ├── php-error.log
│   ├── php-access.log
│   └── php-slow.log
├── nginx/                       # Auto-generated
│   └── rewrites.conf            # From .htaccess
├── private/                     # Private config
│   └── config.php
└── backups/                     # Backups
    └── backup-*.tar.gz
```

### Nginx Server Block

```nginx
server {
    listen 80;
    server_name example.com www.example.com;
    root /var/www/clients/example.com/public_html;  # REQUIRED
    
    # Domain-specific PHP-FPM socket
    location ~ \.php$ {
        fastcgi_pass unix:/run/php/php8.2-fpm-example.com.sock;
        ...
    }
    
    # Auto-converted rewrite rules
    include /var/www/clients/example.com/nginx/rewrites.conf;
}
```

### PHP-FPM Pool (Domain-Specific)

```ini
[example.com]
user = client1
listen = /run/php/php8.2-fpm-example.com.sock
pm = dynamic
pm.max_children = 20
pm.start_servers = 5
...
```

### Automatic Conversion Chain

```
.htaccess edited
    ↓
inotify detects change
    ↓
shm-htaccess-watcher triggered
    ↓
htaccess-converter parses rules
    ↓
Converts Apache → Nginx syntax
    ↓
Writes nginx/rewrites.conf
    ↓
Validates nginx -t
    ↓
systemctl reload nginx
    ↓
Rules LIVE (2-3 seconds)
```

---

## 🐛 Troubleshooting

### Domain Not Accessible

```bash
# Check if enabled
ls /etc/nginx/sites-enabled/example.com.conf

# Check Nginx syntax
sudo nginx -t

# Check PHP-FPM socket
ls /run/php/php8.2-fpm-example.com.sock

# Check PHP-FPM is running
systemctl status php8.2-fpm
```

### .htaccess Not Converting

```bash
# Check watcher is running
systemctl status shm-htaccess-watcher

# View logs
journalctl -u shm-htaccess-watcher -n 50

# Manually trigger
sudo htaccess-converter /var/www/clients/example.com

# Check rewrites.conf
cat /var/www/clients/example.com/nginx/rewrites.conf
```

### Nginx Won't Reload

```bash
# Test configuration
sudo nginx -t

# Show detailed errors
sudo nginx -T | grep example.com

# Check error log
sudo tail -f /var/log/nginx/error.log
```

---

## 📊 System Requirements

- **OS:** Ubuntu 20.04+ or Debian 11+
- **Nginx:** Latest stable
- **PHP-FPM:** Any version (8.0, 8.1, 8.2, 8.3)
- **Tools:** inotify-tools (for auto-conversion)
- **Disk:** ~50MB per domain (varies by content)
- **RAM:** 256MB per PHP pool minimum

---

## 🔄 Workflow Examples

### Create Domain & Test

```bash
# 1. Create domain
sudo add-domain mysite.com webuser 8.2

# 2. Point DNS (or /etc/hosts for testing)
echo "127.0.0.1 mysite.com" | sudo tee -a /etc/hosts

# 3. Test it loads
curl -H "Host: mysite.com" http://127.0.0.1/

# 4. Edit .htaccess
nano /var/www/clients/mysite.com/public_html/.htaccess

# 5. Add rewrite rule, save
# 6. Wait 2-3 seconds
# 7. Changes are live!
```

### Remove Domain

```bash
# 1. Remove domain
sudo remove-domain mysite.com

# 2. Backup is automatically created
ls /var/backups/shm-panel-mysite.com-*.tar.gz

# 3. If needed, restore
sudo tar -xzf /var/backups/shm-panel-mysite.com-*.tar.gz -C /
```

---

## 📞 Support Resources

**Documentation:**
- See `docs/DOMAIN_MANAGEMENT.md` for complete guide
- See `docs/DOMAIN_QUICK_REFERENCE.md` for commands

**Scripts Have Built-In Help:**
```bash
/usr/local/bin/add-domain --help
/usr/local/bin/htaccess-converter --help
```

**Logs:**
- Systemd service: `journalctl -u shm-htaccess-watcher -f`
- Domain creation: `/var/log/shm-panel/domain-creation.log`
- Watcher: `/var/log/shm-panel/htaccess-watcher.log`

---

## ✅ Verification Checklist

After installation, verify:

- [ ] Scripts installed in `/usr/local/bin/`
- [ ] Systemd service running
- [ ] Test domain created successfully
- [ ] Domain accessible via browser
- [ ] .htaccess changes auto-applied
- [ ] Nginx validation working
- [ ] Logs being written correctly
- [ ] Rollback works on failure

---

## 🎓 Learning Path

1. **Read:** `DOMAIN_SYSTEM_SUMMARY.md` (5 min)
2. **Install:** Run `install-domain-management.sh` (2 min)
3. **Test:** Create first domain with `add-domain` (2 min)
4. **Explore:** Check directory structure and files (5 min)
5. **Reference:** Keep `DOMAIN_QUICK_REFERENCE.md` handy (on-demand)
6. **Deep Dive:** Read `DOMAIN_MANAGEMENT.md` for advanced topics (15 min)

---

## 🚀 Next Steps

1. **Install the system** (see Quick Start above)
2. **Test domain creation** 
3. **Test .htaccess conversion**
4. **Integrate with your control panel** (see examples/)
5. **Add to your documentation**
6. **Deploy to production**

---

## 📝 Version Info

- **Version:** 1.0 Stable
- **Release Date:** 2026-01-29
- **Status:** ✅ Production Ready
- **Support:** See docs/ directory

---

## 📜 License

Part of **SHM Panel** - Premium Hosting Control Panel  
(c) 2026 Vivzon Cloud. All Rights Reserved.

---

**Ready to deploy? Start with:**
```bash
sudo /path/to/shm-panel/scripts/install-domain-management.sh
```

**Questions? Check:**
- `docs/DOMAIN_MANAGEMENT.md` - Full reference
- `docs/DOMAIN_QUICK_REFERENCE.md` - Commands
- Script comments - Built-in documentation

---

**Status:** ✅ COMPLETE AND READY FOR PRODUCTION USE
