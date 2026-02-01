# SHM Panel Domain Management - Quick Reference

## Installation

```bash
sudo /path/to/shm-panel/scripts/install-domain-management.sh
```

---

## Commands

### Create Domain
```bash
sudo add-domain example.com client1 8.2
```

### Remove Domain
```bash
sudo remove-domain example.com
sudo remove-domain example.com --force
```

### List Domains
```bash
sudo list-domains
sudo list-domains client1
```

### Domain Info
```bash
sudo domain-info example.com
```

### Convert .htaccess
```bash
sudo htaccess-converter /var/www/clients/example.com
```

### Enable Domain
```bash
sudo enable-domain example.com
```

### Disable Domain
```bash
sudo disable-domain example.com
```

---

## Monitoring

### Service Status
```bash
systemctl status shm-htaccess-watcher
```

### Service Logs
```bash
journalctl -u shm-htaccess-watcher -f
```

### Detailed Logs
```bash
tail -f /var/log/shm-panel/domain-creation.log
tail -f /var/log/shm-panel/htaccess-watcher.log
```

### Domain Access Logs
```bash
tail -f /var/www/clients/example.com/logs/access.log
tail -f /var/www/clients/example.com/logs/error.log
tail -f /var/www/clients/example.com/logs/php-error.log
```

---

## Troubleshooting

### Nginx Won't Reload
```bash
sudo nginx -t              # Test configuration
sudo systemctl reload nginx # Reload gracefully
```

### Check Domain Directory
```bash
ls -lah /var/www/clients/example.com/
ls -lah /var/www/clients/example.com/public_html/
```

### Check PHP-FPM Socket
```bash
ls -lah /run/php/php8.2-fpm-example.com.sock
systemctl status php8.2-fpm
```

### Check Nginx Config
```bash
cat /etc/nginx/sites-available/example.com.conf
cat /etc/nginx/sites-enabled/example.com.conf
```

### Check Rewrites
```bash
cat /var/www/clients/example.com/nginx/rewrites.conf
```

### Check .htaccess
```bash
cat /var/www/clients/example.com/public_html/.htaccess
```

---

## File Locations

```
Binary Scripts:
  /usr/local/bin/add-domain
  /usr/local/bin/htaccess-converter
  /usr/local/bin/shm-htaccess-watcher

Systemd Service:
  /etc/systemd/system/shm-htaccess-watcher.service

Domain Structure:
  /var/www/clients/{domain}/
  ├── public_html/            (website files)
  ├── logs/                   (access & error logs)
  ├── nginx/rewrites.conf     (auto-generated)
  └── private/                (private files)

Nginx Configs:
  /etc/nginx/sites-available/{domain}.conf
  /etc/nginx/sites-enabled/{domain}.conf

PHP-FPM Pool:
  /etc/php/8.2/fpm/pool.d/{domain}.conf

Logs:
  /var/log/shm-panel/domain-creation.log
  /var/log/shm-panel/htaccess-watcher.log
  /var/www/clients/{domain}/logs/access.log
  /var/www/clients/{domain}/logs/error.log
```

---

## Common Patterns

### Clean URLs (Hide .php)
In `.htaccess`:
```apache
RewriteRule ^([a-zA-Z0-9_-]+)/?$ $1.php [QSA,L]
```

Result: `/login` → `/login.php`

### SEO URLs with Parameters
In `.htaccess`:
```apache
RewriteRule ^products/([0-9]+)/(.*)$ products.php?id=$1&name=$2 [QSA,L]
```

Result: `/products/123/widget` → `/products.php?id=123&name=widget`

### Force HTTPS
In `.htaccess`:
```apache
RewriteCond %{HTTPS} !=on
RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [R=301,L]
```

### Deny Sensitive Files
In `.htaccess`:
```apache
RewriteRule ^\.env$ - [F]
RewriteRule ^\.git - [F]
```

---

## Service Management

### Start Service
```bash
sudo systemctl start shm-htaccess-watcher
```

### Stop Service
```bash
sudo systemctl stop shm-htaccess-watcher
```

### Restart Service
```bash
sudo systemctl restart shm-htaccess-watcher
```

### Enable on Boot
```bash
sudo systemctl enable shm-htaccess-watcher
```

### Disable on Boot
```bash
sudo systemctl disable shm-htaccess-watcher
```

---

## Security Checks

### List All Domains
```bash
find /var/www/clients -maxdepth 2 -name "nginx" -type d
```

### Check Enabled Sites
```bash
ls -lah /etc/nginx/sites-enabled/
```

### Verify Root Paths
```bash
grep "root " /etc/nginx/sites-available/*.conf
```

### Check for NULL Roots
```bash
grep "root $" /etc/nginx/sites-available/*.conf  # Should return nothing
```

---

## Backup & Restore

### Backup Domain
```bash
sudo tar -czf domain-backup.tar.gz /var/www/clients/example.com
```

### Restore Domain
```bash
sudo tar -xzf domain-backup.tar.gz -C /
```

### List Backups
```bash
ls -lah /var/backups/shm-panel-*.tar.gz
```

---

## Performance Metrics

### Check Domain Size
```bash
du -sh /var/www/clients/example.com/
du -sh /var/www/clients/example.com/public_html/
```

### Check Log Sizes
```bash
ls -lh /var/www/clients/example.com/logs/
```

### Count Active Domains
```bash
ls /var/www/clients/ | wc -l
```

### List PHP Pools
```bash
ls /etc/php/8.2/fpm/pool.d/
```

---

## Version Info

```bash
# Check script version
head -20 /usr/local/bin/add-domain

# Check Nginx version
nginx -v

# Check PHP-FPM version
php-fpm8.2 -v

# Check inotify-tools
inotifywait -v
```

---

## Frequently Asked Questions

**Q: How do I edit a domain's rewrite rules?**
A: Edit `/var/www/clients/{domain}/public_html/.htaccess`. The watcher will auto-convert within 2-3 seconds.

**Q: Can I manually edit rewrites.conf?**
A: Not recommended. It will be overwritten when .htaccess changes. Edit .htaccess instead.

**Q: How do I prevent a domain from loading?**
A: Use `sudo disable-domain example.com`. To delete it, use `sudo remove-domain example.com`.

**Q: What PHP versions are supported?**
A: Any installed version (e.g., 8.0, 8.1, 8.2, 8.3). Specified at domain creation.

**Q: Can I change PHP version for a domain?**
A: Create a new domain with the desired PHP version. Migration of files is manual.

**Q: Are domains automatically backed up?**
A: Yes, when removed. Backups are stored in `/var/backups/shm-panel-*.tar.gz`.

**Q: How do I restore from backup?**
A: `sudo tar -xzf /var/backups/shm-panel-{domain}-{date}.tar.gz -C /`

**Q: Can multiple users share a domain?**
A: No. Each domain belongs to one system user. Create separate domains for different users.

---

Last Updated: 2026-01-29
