# shm
- install PHP 8.4, Nginx, MySQL
- set up your project files under /var/www/shm-panel
- configure permissions and database
- run the app securely

# Step 1 — Update the system
  bash - apt update && apt upgrade -y

# Step 2 — Install required packages
  bash - apt install -y nginx mysql-server unzip git curl openssl

# Step 3 — Install PHP 8.4 and extensions
  bash - add-apt-repository ppa:ondrej/php -y
  bash - apt update
  bash - apt install -y php8.4 php8.4-fpm php8.4-mysql php8.4-cli php8.4-curl php8.4-zip php8.4-mbstring php8.4-xml php8.4-gd php8.4-bcmath

  # Enable and start PHP-FPM:
    bash - systemctl enable php8.4-fpm
    bash - systemctl start php8.4-fpm

# Step 4 — Prepare web root
  bash - mkdir -p /var/www/shm-panel
  bash - cd /var/www/shm-panel
  
  # Go to your web directory
    bash - cd /var/www/
  
  # Clone the GitHub project
    bash - git clone https://github.com/vivzon/shm.git shm-panel
  
  # Verify files
    bash - ls -l /var/www/shm-panel/

  # ptionally set permissions
    If this is for a web panel (PHP, Node.js, etc.), fix permissions:

    bash - chown -R www-data:www-data /var/www/shm-panel/
    bash - chmod -R 755 /var/www/shm-panel/

# Step 5 — Create the SHM application user
  bash - useradd -r -s /bin/false shmuser

# Step 6 — Create the deployment script
  # executable:
    bash - chmod +x /var/www/shm-panel/deploy-shm.sh
    
  # Run it:
    bash - /var/www/shm-panel/deploy-shm.sh or ./deploy-shm.sh

# It will:
  ✅ create /var/www/shm-panel/includes/config.php
  ✅ set permissions
  ✅ create the MySQL database and user
  ✅ restart services

# Step 7 — Configure Nginx
  Create /etc/nginx/sites-available/shm-panel.conf:

  # bash:
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
  bash - ln -s /etc/nginx/sites-available/shm-panel.conf /etc/nginx/sites-enabled/
  bash - nginx -t
  bash - systemctl restart nginx

# Step 8 — Test PHP

  # bash:
  echo "<?php phpinfo(); ?>" > /var/www/shm-panel/test.php
  chown www-data:www-data /var/www/shm-panel/test.php

  Visit http://<your-server-ip>/test.php — you should see the PHP 8.4 info page.
  
# Then remove it:
  bash - rm /var/www/shm-panel/test.php

# Step 9 — Finish installation via web
  http://<your-server-ip>/install/

  Follow the on-screen instructions.
  Use the credentials printed at the end of your deployment script (or check /root/shm-deployment-info.txt).

# Step 10 — Secure the setup
  bash - rm -rf /var/www/shm-panel/install

  # Optionally install a firewall:
  bash - ufw allow 'Nginx Full'
  bash - ufw enable

# ✅ Done!
Your SHM Panel should now be accessible at
http://<your-server-ip>/

  
