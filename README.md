# SHM - Server Hosting Management Panel
- install PHP 8.4, Nginx, MySQL
- set up your project files under /var/www/shm-panel
- configure permissions and database
- run the app securely

# Step 1 — Update the system
  apt update && apt upgrade -y

# Step 2 — Install required packages
  apt install -y nginx mysql-server unzip git curl openssl

# Step 3 — Install PHP 8.4 and extensions
  add-apt-repository ppa:ondrej/php -y
  apt update
  apt install -y php8.4 php8.4-fpm php8.4-mysql php8.4-cli php8.4-curl php8.4-zip php8.4-mbstring php8.4-xml php8.4-gd php8.4-bcmath

  # Enable and start PHP-FPM:
    systemctl enable php8.4-fpm
    systemctl start php8.4-fpm

# Step 4 — Prepare web root
  mkdir -p /var/www/shm-panel
  cd /var/www/shm-panel
  
  # Go to your web directory
    cd /var/www/
  
  # Clone the GitHub project
    git clone https://github.com/vivzon/shm.git shm-panel
  
  # Verify files
    ls -l /var/www/shm-panel/

  # ptionally set permissions
    If this is for a web panel (PHP, Node.js, etc.), fix permissions:

    chown -R www-data:www-data /var/www/shm-panel/
    chmod -R 755 /var/www/shm-panel/

# Step 5 — Create the SHM application user
  useradd -r -s /bin/false shmuser

# Step 6 — Create the deployment script
  # executable:
  chmod +x /var/www/shm-panel/deploy-shm.sh
    
  # Run it:
    /var/www/shm-panel/deploy-shm.sh or ./deploy-shm.sh

# It will: 
  ✅ create /var/www/shm-panel/includes/config.php
  ✅ set permissions
  ✅ create the MySQL database and user
  ✅ restart services

# Step 7 — Configure Nginx
  Create /etc/nginx/sites-available/shm-panel.conf:

  server {
      listen 80;
      server_name _;
  
      root /var/www/shm-panel;
      index index.php index.html;
  
      access_log /var/log/nginx/shm-panel.access.log;
      error_log /var/log/nginx/shm-panel.error.log;
  
      location / {
          try_files $uri $uri/ /index.php?$query_string;
      }
  
      location ~ \.php$ {
          include snippets/fastcgi-php.conf;
          fastcgi_pass unix:/var/run/php/php8.4-fpm.sock;
          fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
          include fastcgi_params;
      }
  
      location ~ /\.ht {
          deny all;
      }
  }

# Enable it:
  ln -s /etc/nginx/sites-available/shm-panel.conf /etc/nginx/sites-enabled/
  nginx -t
  systemctl restart nginx

# Step 8 — Test PHP

  # bash:
  echo "<?php phpinfo(); ?>" > /var/www/shm-panel/test.php
  chown www-data:www-data /var/www/shm-panel/test.php

  Visit http://<your-server-ip>/test.php — you should see the PHP 8.4 info page.
  
# Then remove it:
  rm /var/www/shm-panel/test.php

# Step 9 — Finish installation via web
  http://<your-server-ip>/install/

  Follow the on-screen instructions.
  Use the credentials printed at the end of your deployment script (or check /root/shm-deployment-info.txt).

# Step 10 — Secure the setup
  rm -rf /var/www/shm-panel/install

  # Optionally install a firewall:
  ufw allow 'Nginx Full'
  ufw enable

# ✅ Done!
Your SHM Panel should now be accessible at
http://<your-server-ip>/

  
