# 🖥️ SHM — Server Hosting Management Panel

The **SHM Panel** is a lightweight web-based control panel for managing servers, hosting environments, and PHP-based applications.  
This guide walks you through installing and configuring SHM on an Ubuntu-based server using **PHP 8.4**, **Nginx**, and **MySQL**.

---

## 📋 Requirements

- Ubuntu 22.04+ (or compatible Debian-based distro)
- Root or sudo privileges
- Internet access
- Domain name (e.g., `server.sellvell.com`)

---

## 🚀 Installation Steps

### **Step 1 — Update the System**

```bash
sudo apt update && sudo apt upgrade -y
```

---

### **Step 2 — Install Required Packages**

```bash
sudo apt install -y nginx mysql-server unzip git curl openssl
```

---

### **Step 3 — Install PHP 8.4 and Extensions**

```bash
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update

sudo apt install -y php8.4 php8.4-fpm php8.4-mysql php8.4-cli php8.4-curl php8.4-zip php8.4-mbstring php8.4-xml php8.4-gd php8.4-bcmath
```

Enable and start PHP-FPM:

```bash
sudo systemctl enable php8.4-fpm
sudo systemctl start php8.4-fpm
```

---

### **Step 4 — Prepare the Web Root**

```bash
sudo mkdir -p /var/www/shm-panel
cd /var/www
sudo git clone https://github.com/vivzon/shm.git shm-panel
```

Verify files:

```bash
ls -l /var/www/shm-panel/
```

Fix permissions:

```bash
sudo chown -R www-data:www-data /var/www/shm-panel/
sudo chmod -R 755 /var/www/shm-panel/
```

---

### **Step 5 — Create the SHM Application User**

```bash
sudo useradd -r -s /bin/false shmuser
```

---

### **Step 6 — Run the Deployment Script**

Make it executable:

```bash
sudo chmod +x /var/www/shm-panel/install.sh
```

Run it:

```bash
sudo /var/www/shm-panel/install.sh
```

This script will:

- OS detection
- Full PHP 8.4 + MariaDB + nginx stack installation
- Secure setup
- Panel project structure
- Auto-generated configs
- Full routing system
- Modules (domains, login, dashboard)
- Database schema
- Security features (CSRF, hashed passwords, login attempts)
- Logs, backups, encryption keys
- Service configuration

---

### **Step 7 — Create a secure MySQL user for SHM Panel**

```bash
CREATE USER 'shm_user'@'localhost' IDENTIFIED BY 'StrongPassword123!';  
GRANT ALL PRIVILEGES ON shm_panel.* TO 'shm_user'@'localhost';  
FLUSH PRIVILEGES;  
```

Restart services (if needed):
 
```bash
systemctl restart nginx
systemctl restart php8.4-fpm
```

### **Step 7.1 — Configure Nginx**

Create a new config file:

```bash
sudo nano /etc/nginx/sites-available/shm-panel.conf
```

Paste the following:

```nginx
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name 147.79.71.199 server.sellvell.com;

    root /var/www/shm-panel;
    index index.php index.html;

    access_log /var/log/nginx/shm_access.log;
    error_log  /var/log/nginx/shm_error.log;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.4-fpm.sock;  # <- change if your socket is different
    }

    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|webp)$ {
        try_files $uri $uri/ =404;
        access_log off;
        expires max;
    }
}
```

Enable the site and reload Nginx:

```bash
//sudo ln -s /etc/nginx/sites-available/shm-panel.conf /etc/nginx/sites-enabled/

sudo ln -sf /etc/nginx/sites-available/shm-panel.conf /etc/nginx/sites-enabled/shm-panel.conf

sudo nginx -t
sudo systemctl restart nginx
```

---

### **Step 8 — Test PHP**

Create a test file:

```bash
echo "<?php phpinfo(); ?>" | sudo tee /var/www/shm-panel/test.php
sudo chown www-data:www-data /var/www/shm-panel/test.php
```

Open in your browser:

```
http://<your-server-ip>/test.php
```

If PHP loads correctly, remove the file:

```bash
sudo rm /var/www/shm-panel/test.php
```

---

### **Step 9 — Complete Installation via Web Interface**

Open your browser and go to:

```
http://<your-server-ip>/install/
```

Follow the on-screen installation wizard.  
Use the credentials displayed by the deployment script or check:

```
/root/shm-deployment-info.txt
```

---

### **Step 10 — Secure the Installation**

Remove the installer folder:

```bash
sudo rm -rf /var/www/shm-panel/install
```

Enable and configure the firewall:

```bash
sudo ufw allow 'Nginx Full'
sudo ufw enable
```

(Optional) Enable HTTPS with Let’s Encrypt:

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d server.sellvell.com
```

---

## 🔒 Security Recommendations

- Regularly update your system:
  ```bash
  sudo apt update && sudo apt upgrade -y
  ```
- Disable MySQL remote root login:
  ```bash
  sudo mysql_secure_installation
  ```
- Backup `/var/www/shm-panel/includes/config.php` securely.
- Keep database credentials private.
- Use HTTPS (SSL) for all panel access.

---

## 🧠 Useful Commands

Restart services:

```bash
sudo systemctl restart nginx
sudo systemctl restart php8.4-fpm
sudo systemctl restart mysql
```

Check Nginx syntax:

```bash
sudo nginx -t
```

View logs:

```bash
sudo tail -f /var/log/nginx/shm-panel.error.log
sudo journalctl -u php8.4-fpm -n 50
```

---

## 🌐 Access the Panel

Once installation is complete, access your SHM panel at:

- **HTTP:**  [http://server.sellvell.com/](http://server.sellvell.com/)
- **HTTPS (recommended):**  [https://server.sellvell.com/](https://server.sellvell.com/)

---

## 🧰 Directory Structure

```
/var/www/shm-panel/
│
├── includes/
│   └── config.php        # Application configuration file
├── deploy-shm.sh         # Deployment script
├── install/              # Web-based installer (remove after setup)
├── public/               # Web-accessible files
├── logs/                 # Log files
└── ...
```

---

## 📦 Backup & Maintenance

Backup database and config regularly:

```bash
sudo mysqldump -u root -p shm_db > /root/shm-backup.sql
sudo tar -czvf /root/shm-files-backup.tar.gz /var/www/shm-panel
```

To restore:

```bash
sudo mysql -u root -p shm_db < /root/shm-backup.sql
sudo tar -xzvf /root/shm-files-backup.tar.gz -C /
```

---

## ✅ Done!

Your **SHM Server Hosting Management Panel** is now fully installed and ready to use 🎉  
Manage your hosting environment securely and efficiently.

---

### 🧩 Author
**SHM Development Team (Vivzon Technologies)**  
📧 Support: info@vivzon.in  
🌐 Website: [https://vivzon.in](https://vivzon.in)
