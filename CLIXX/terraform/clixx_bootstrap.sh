#!/bin/bash -xe

# ================================
# Terraform-injected values
# ================================
REGION="${aws_region}"
APP_DOMAIN="dev.clixx.nancy-stack.com"
DB_HOST="${db_host}"
DB_NAME="${db_name}"
DB_USER="${db_user}"
DB_PASS="${db_pass}"
EFS_ID="${efs_id}"
LB_DNS="${lb_dns}"

# ================================
# Install packages
# ================================
sudo yum -y upgrade
sudo yum -y install git amazon-efs-utils mariadb105-server httpd \
  php php-fpm php-mysqlnd php-json php-xml php-gd php-mbstring php-opcache php-zip nc

# ================================
# Configure Apache
# ================================
sudo systemctl enable httpd php-fpm
sudo sed -i 's/AllowOverride None/AllowOverride All/g' /etc/httpd/conf/httpd.conf
echo 'DirectoryIndex index.php index.html' | sudo tee /etc/httpd/conf.d/dir.conf >/dev/null

# ================================
# Mount EFS
# ================================
sudo mkdir -p /var/www/html
if ! grep -q "$EFS_ID" /etc/fstab; then
  echo "$EFS_ID:/  /var/www/html  efs  _netdev,tls  0 0" | sudo tee -a /etc/fstab >/dev/null
fi
sudo mount -a || echo "Mount had issues"
sudo systemctl start httpd php-fpm

# ================================
# Check if fresh deployment needed
# ================================
MARKER="/var/www/html/.deployed"
DB_MARKER="/var/www/html/.db_host"
FORCE_REFRESH=false

if [ -f "$DB_MARKER" ]; then
  PREVIOUS_DB=$(cat "$DB_MARKER")
  [ "$PREVIOUS_DB" != "$DB_HOST" ] && FORCE_REFRESH=true && sudo rm -f "$MARKER"
else
  FORCE_REFRESH=true
fi
echo "$DB_HOST" | sudo tee "$DB_MARKER" >/dev/null

# ================================
# Deploy WordPress (first-time or DB changed)
# ================================
if [ ! -f "$MARKER" ] || [ "$FORCE_REFRESH" = true ]; then
  echo "Deploying WordPress..."
  
  # Clean and clone
  sudo find /var/www/html -mindepth 1 -name ".db_host" -prune -o -exec rm -rf {} + 2>/dev/null || true
  TEMP_DIR=$(mktemp -d)
  git clone --depth 1 https://github.com/stackitgit/CliXX_Retail_Repository.git "$TEMP_DIR"
  sudo cp -r "$TEMP_DIR"/* /var/www/html/
  rm -rf "$TEMP_DIR"

  # Wait for database
  echo "Waiting for database..."
  for i in {1..30}; do
    nc -z "$DB_HOST" 3306 && break
    sleep 10
  done

  # Create wp-config.php
  if [ -f /var/www/html/wp-config-sample.php ]; then
    sudo cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
  fi

  # Update database credentials (handles both fresh and hardcoded values)
  sudo sed -i "s/database_name_here/$DB_NAME/; s/'wordpressdb'/'$DB_NAME'/" /var/www/html/wp-config.php
  sudo sed -i "s/username_here/$DB_USER/; s/'wordpressuser'/'$DB_USER'/" /var/www/html/wp-config.php
  sudo sed -i "s/password_here/$DB_PASS/; s/'W3lcome123'/'$DB_PASS'/" /var/www/html/wp-config.php
  sudo sed -i "s/localhost/$DB_HOST/" /var/www/html/wp-config.php
  sudo sed -i "s/wordpress-db\.[a-zA-Z0-9.-]*\.rds\.amazonaws\.com/$DB_HOST/" /var/www/html/wp-config.php

  # Add WP_HOME and WP_SITEURL (use APP_DOMAIN for pretty URLs)
  sudo sed -i "/DB_COLLATE/a\\
\\
define('WP_HOME', 'http://$APP_DOMAIN');\\
define('WP_SITEURL', 'http://$APP_DOMAIN');" /var/www/html/wp-config.php

  # Update URLs in database to use custom domain
  mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" \
    -e "UPDATE wp_options SET option_value='http://$APP_DOMAIN' WHERE option_name IN ('siteurl','home');" || true

  # Mark as deployed
  echo "done" | sudo tee "$MARKER" >/dev/null

else
  # ================================
  # Reuse existing - just update config
  # ================================
  echo "Reusing existing deployment, updating config..."
  
  # Update database values
  sudo sed -i "s/DB_HOST',[^)]*)/DB_HOST', '$DB_HOST')/" /var/www/html/wp-config.php
  sudo sed -i "s/DB_NAME',[^)]*)/DB_NAME', '$DB_NAME')/" /var/www/html/wp-config.php
  sudo sed -i "s/DB_USER',[^)]*)/DB_USER', '$DB_USER')/" /var/www/html/wp-config.php
  sudo sed -i "s/DB_PASSWORD',[^)]*)/DB_PASSWORD', '$DB_PASS')/" /var/www/html/wp-config.php

  # Update WP_HOME/WP_SITEURL
  if grep -q "WP_HOME" /var/www/html/wp-config.php; then
    sudo sed -i "s|define('WP_HOME'.*|define('WP_HOME', 'http://$APP_DOMAIN');|" /var/www/html/wp-config.php
    sudo sed -i "s|define('WP_SITEURL'.*|define('WP_SITEURL', 'http://$APP_DOMAIN');|" /var/www/html/wp-config.php
  else
    sudo sed -i "/DB_COLLATE/a\\
\\
define('WP_HOME', 'http://$APP_DOMAIN');\\
define('WP_SITEURL', 'http://$APP_DOMAIN');" /var/www/html/wp-config.php
  fi

  # Update URLs in database to use custom domain
  mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" \
    -e "UPDATE wp_options SET option_value='http://$APP_DOMAIN' WHERE option_name IN ('siteurl','home');" || true
fi

# ================================
# Create .htaccess
# ================================
cat << 'EOF' | sudo tee /var/www/html/.htaccess
# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
# END WordPress
EOF

# ================================
# Create health.php for ALB
# ================================
echo '<?php http_response_code(200); echo "OK"; ?>' | sudo tee /var/www/html/health.php >/dev/null

# ================================
# Download wp_config_check.sh
# ================================
curl -s -o /var/www/html/wp_config_check.sh \
  https://raw.githubusercontent.com/nancytcheby/STACK_TERRAFORM/Clixx-dev/CLIXX/terraform/wp_config_check.sh
sudo chmod +x /var/www/html/wp_config_check.sh 2>/dev/null || true

# ================================
# Set permissions & SELinux
# ================================
sudo chown -R apache:apache /var/www/html
sudo find /var/www/html -type d -exec chmod 2775 {} \;
sudo find /var/www/html -type f -exec chmod 0644 {} \;
sudo chmod 640 /var/www/html/wp-config.php 2>/dev/null || true
sudo setsebool -P httpd_can_network_connect on 2>/dev/null || true
sudo setsebool -P httpd_use_nfs on 2>/dev/null || true

# ================================
# Restart services
# ================================
sudo systemctl restart httpd php-fpm

echo "Deployment complete!"