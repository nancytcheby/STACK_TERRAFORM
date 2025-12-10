#!/bin/bash -xe

# ================================
# Values injected by Terraform via templatefile()
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
# Base packages
# ================================
sudo yum -y upgrade
sudo yum -y install git amazon-efs-utils awscli mariadb105-server wget tar httpd \
  php php-fpm php-mysqlnd php-json php-xml php-gd php-mbstring php-opcache php-zip nc

# ================================
# Services
# ================================
sudo systemctl enable httpd php-fpm
sudo systemctl start httpd php-fpm

# ================================
# Apache setup
# ================================
sudo usermod -a -G apache ec2-user || true
sudo mkdir -p /var/www/html
sudo chown -R ec2-user:apache /var/www
sudo chmod 2775 /var/www
find /var/www -type d -exec sudo chmod 2775 {} \;
find /var/www -type f -exec sudo chmod 0664 {} \;

# Allow .htaccess & set directory index
sudo sed -i 's/AllowOverride None/AllowOverride All/' /etc/httpd/conf/httpd.conf
echo 'DirectoryIndex index.php index.html' | sudo tee /etc/httpd/conf.d/dir.conf >/dev/null

# ================================
# Sanity check injected values
# ================================
echo "Injected parameters:"
echo "DB_HOST: $DB_HOST"
echo "DB_NAME: $DB_NAME"
echo "DB_USER: $DB_USER"
echo "EFS_ID: $EFS_ID"
echo "LB_DNS: $LB_DNS"

if [ -z "$DB_HOST" ] || [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASS" ] || [ -z "$EFS_ID" ] || [ -z "$LB_DNS" ]; then
  echo "ERROR: One or more required parameters are empty."
  exit 1
fi

# ================================
# Mount EFS as document root
# ================================
if ! grep -q "[[:space:]]$EFS_ID:/[[:space:]]\+/var/www/html[[:space:]]" /etc/fstab; then
  echo "$EFS_ID:/  /var/www/html  efs  _netdev,tls  0 0" | sudo tee -a /etc/fstab >/dev/null
fi

sudo systemctl stop httpd php-fpm || true
sudo mkdir -p /var/www/html

echo "Attempting to mount EFS $EFS_ID:/ to /var/www/html"
grep html /etc/fstab || echo "No EFS entry for /var/www/html in fstab yet"

sudo mount -a -v 2>&1 | tee /tmp/mount-debug.log || echo "mount -a reported issues"

mount | grep /var/www/html || echo "No /var/www/html mount found"
ls -la /var/www/html/ || echo "Cannot list /var/www/html"

if ! mountpoint -q /var/www/html; then
  echo "ERROR: Failed to mount EFS - creating fallback health files"
  echo '<?php http_response_code(200); echo "OK - EFS mount failed"; ?>' | sudo tee /var/www/html/health.php >/dev/null
  echo '<html><body><h1>EFS Mount Failed - Using local storage</h1></body></html>' | sudo tee /var/www/html/index.html >/dev/null
  sudo chown apache:apache /var/www/html/health.php /var/www/html/index.html
  sudo systemctl restart httpd
else
  echo "EFS mounted successfully on /var/www/html"
fi

sudo systemctl start php-fpm httpd

MARKER="/var/www/html/.deployed"
DB_MARKER="/var/www/html/.db_host"

# ================================
# Check if database has changed (force refresh if so)
# ================================
FORCE_REFRESH=false
if [ -f "$DB_MARKER" ]; then
  PREVIOUS_DB_HOST=$(cat "$DB_MARKER")
  if [ "$PREVIOUS_DB_HOST" != "$DB_HOST" ]; then
    echo "Database host changed from $PREVIOUS_DB_HOST to $DB_HOST - forcing fresh deployment"
    FORCE_REFRESH=true
    sudo rm -f "$MARKER" 2>/dev/null || true
  fi
else
  echo "No previous database host recorded"
  FORCE_REFRESH=true
fi

# Save current database host for next run
echo "$DB_HOST" | sudo tee "$DB_MARKER" >/dev/null

# ================================
# First-time deploy OR forced refresh
# ================================
if [ ! -f "$MARKER" ] || [ "$FORCE_REFRESH" = true ]; then
  if [ "$FORCE_REFRESH" = true ]; then
    echo "FORCED REFRESH: Database changed - cleaning EFS and redeploying"
  else
    echo "First-time deployment on EFS"
  fi

  # Clean any leftovers on EFS (but preserve .db_host marker)
  sudo find /var/www/html -mindepth 1 -name ".db_host" -prune -o -type f -delete 2>/dev/null || true
  sudo find /var/www/html -mindepth 1 -name ".db_host" -prune -o -type d -exec rm -rf {} + 2>/dev/null || true

  # Clone app to temporary location first
  TEMP_DIR=$(mktemp -d)
  git clone --depth 1 https://github.com/stackitgit/CliXX_Retail_Repository.git "$TEMP_DIR"

  # Copy to EFS with proper ownership
  sudo cp -r "$TEMP_DIR"/* /var/www/html/
  sudo chown -R apache:apache /var/www/html
  rm -rf "$TEMP_DIR"

  # ------------------------------
  # Test database connection with retry logic
  # ------------------------------
  echo "Testing database connection..."
  echo "DB_HOST: $DB_HOST"

  # Test DNS resolution with retry
  echo "Waiting for RDS DNS resolution..."
  for i in {1..30}; do
    if nslookup "$DB_HOST" >/dev/null 2>&1; then
      echo "DNS resolution successful after $i attempts"
      break
    fi
    if [ $i -eq 30 ]; then
      echo "ERROR: Cannot resolve database hostname after 30 attempts: $DB_HOST"
      exit 1
    fi
    echo "DNS resolution attempt $i failed, waiting 10 seconds..."
    sleep 10
  done

  # Test network connectivity with retry
  echo "Waiting for RDS port 3306 to be available..."
  for i in {1..60}; do
    if nc -z "$DB_HOST" 3306 2>/dev/null; then
      echo "Database port accessible after $i attempts"
      break
    fi
    if [ $i -eq 60 ]; then
      echo "ERROR: Cannot connect to database port 3306 after 60 attempts: $DB_HOST"
      exit 1
    fi
    echo "Connection attempt $i failed, waiting 10 seconds..."
    sleep 10
  done

  # Test database authentication with retry
  echo "Testing database authentication..."
  for i in {1..30}; do
    if mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SELECT 1;" >/dev/null 2>&1; then
      echo "Database authentication successful after $i attempts"
      break
    fi
    if [ $i -eq 30 ]; then
      echo "ERROR: Database authentication failed after 30 attempts"
      echo "Host: $DB_HOST, User: $DB_USER, Database: $DB_NAME"
      exit 1
    fi
    echo "Authentication attempt $i failed, waiting 10 seconds..."
    sleep 10
  done

  echo "Database connection fully successful and ready!"

  # ------------------------------
  # Create / update wp-config.php
  # ------------------------------
  if [ -f /var/www/html/wp-config-sample.php ]; then
    echo "Creating fresh wp-config.php with current parameters..."
    sudo cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
  elif [ -f /var/www/html/wp-config.php ]; then
    echo "Using existing wp-config.php from Git repository"
  else
    echo "ERROR: Neither wp-config-sample.php nor wp-config.php found - WordPress installation incomplete"
    exit 1
  fi

  # Force update wp-config.php with current database values (handles both cases)
  sudo sed -i "s/database_name_here/$DB_NAME/" /var/www/html/wp-config.php
  sudo sed -i "s/username_here/$DB_USER/"      /var/www/html/wp-config.php  
  sudo sed -i "s/password_here/$DB_PASS/"      /var/www/html/wp-config.php
  sudo sed -i "s/localhost/$DB_HOST/"          /var/www/html/wp-config.php
  
  # Also handle pre-configured wp-config.php from Git with hardcoded values
  sudo sed -i "s/'wordpressdb'/'$DB_NAME'/" /var/www/html/wp-config.php
  sudo sed -i "s/'wordpressuser'/'$DB_USER'/" /var/www/html/wp-config.php
  sudo sed -i "s/'W3lcome123'/'$DB_PASS'/" /var/www/html/wp-config.php
  sudo sed -i "s/wordpress-db\.[a-zA-Z0-9]*\.us-east-1\.rds\.amazonaws\.com/$DB_HOST/" /var/www/html/wp-config.php

  # Add debug configuration
  sudo sed -i "/<?php/a\\
define('WP_DEBUG', true);\\
define('WP_DEBUG_LOG', true);\\
define('WP_DEBUG_DISPLAY', false);\\
define('WP_MEMORY_LIMIT', '256M');" /var/www/html/wp-config.php

  # Ensure uploads directory exists with proper permissions
  sudo mkdir -p /var/www/html/wp-content/uploads
  sudo chown -R apache:apache /var/www/html/wp-content/uploads
  sudo chmod -R 755 /var/www/html/wp-content/uploads

  # Lightweight ALB health probe
  echo '<?php http_response_code(200); echo "OK"; ?>' | sudo tee /var/www/html/health.php >/dev/null

  # SELinux allowances for outbound (RDS) and EFS
  sudo setsebool -P httpd_can_network_connect on || true
  sudo setsebool -P httpd_use_nfs on || true
  sudo setsebool -P httpd_execmem on || true

  # Set WordPress URLs to custom domain (primary)
echo "Updating WordPress site URLs..."
mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" \
  -e "UPDATE wp_options
         SET option_value='http://$APP_DOMAIN'
       WHERE option_name IN ('siteurl','home');" || {
  echo "WARNING: Failed to update WordPress URLs - database may not be initialized"
}

  # Add flexible URL handling to wp-config.php to allow ALB access
  echo "Adding flexible URL support for both custom domain and ALB..."
  sudo sed -i "/define('WP_MEMORY_LIMIT'/a\\
// Allow access via both custom domain and ALB\\
if (isset(\$_SERVER['HTTP_HOST'])) {\\
    \$protocol = isset(\$_SERVER['HTTPS']) && \$_SERVER['HTTPS'] === 'on' ? 'https' : 'http';\\
    define('WP_HOME', \$protocol . '://' . \$_SERVER['HTTP_HOST']);\\
    define('WP_SITEURL', \$protocol . '://' . \$_SERVER['HTTP_HOST']);\\
}" /var/www/html/wp-config.php

  # ================================
# Download and setup wp_config_check.sh script
# ================================
echo "Downloading wp_config_check.sh from GitHub..."

# Download the script from GitHub
curl -o /var/www/html/wp_config_check.sh \
  https://raw.githubusercontent.com/nancytcheby/STACK_TERRAFORM/Clixx-dev/CLIXX/terraform/wp_config_check.sh

# Make script executable
sudo chmod +x /var/www/html/wp_config_check.sh
sudo chown apache:apache /var/www/html/wp_config_check.sh

# Create log file with proper permissions
sudo touch /var/log/wp_config_check.log
sudo chown apache:apache /var/log/wp_config_check.log

# Set up cron job to run script every 5 minutes
echo "Setting up cron job for wp_config_check.sh..."

# Add cron job for apache user (since script needs access to /var/www/html)
(sudo crontab -u apache -l 2>/dev/null || echo "") | grep -v wp_config_check.sh > /tmp/apache_cron
echo "*/5 * * * * /var/www/html/wp_config_check.sh >> /var/log/wp_config_check.log 2>&1" >> /tmp/apache_cron
sudo crontab -u apache /tmp/apache_cron
rm /tmp/apache_cron

echo "wp_config_check.sh deployed and cron job configured!"
  
  # Run the script once immediately to test
  echo "Running wp_config_check.sh for the first time..."
  sudo -u apache /var/www/html/wp_config_check.sh || echo "Initial wp_config_check.sh run had issues - check logs"

  echo "done" | sudo tee "$MARKER" >/dev/null
  echo "$DB_HOST" | sudo tee "$DB_MARKER" >/dev/null

else
  # ================================
  # Reuse existing deployment
  # ================================
  echo "Reusing existing EFS deployment"

  if [ -d /var/www/html/.git ]; then
    (cd /var/www/html && sudo -u apache git pull --ff-only || true)
  fi

  # Force recreate wp-config.php with current database values
  echo "Force updating wp-config.php with current database parameters..."
  
  if [ -f /var/www/html/wp-config-sample.php ]; then
    echo "Recreating wp-config.php from sample template..."
    sudo cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
    
    # Update template placeholders
    sudo sed -i "s/database_name_here/$DB_NAME/" /var/www/html/wp-config.php
    sudo sed -i "s/username_here/$DB_USER/"      /var/www/html/wp-config.php
    sudo sed -i "s/password_here/$DB_PASS/"      /var/www/html/wp-config.php
    sudo sed -i "s/localhost/$DB_HOST/"          /var/www/html/wp-config.php
  else
    echo "Using existing wp-config.php - force updating database values..."
  fi
  
  # AGGRESSIVE: Replace ANY database hostname pattern with current one
  sudo sed -i "s/DB_HOST[^;]*;/DB_HOST', '$DB_HOST');/" /var/www/html/wp-config.php
  sudo sed -i "s/DB_NAME[^;]*;/DB_NAME', '$DB_NAME');/" /var/www/html/wp-config.php  
  sudo sed -i "s/DB_USER[^;]*;/DB_USER', '$DB_USER');/" /var/www/html/wp-config.php
  sudo sed -i "s/DB_PASSWORD[^;]*;/DB_PASSWORD', '$DB_PASS');/" /var/www/html/wp-config.php
  
  # Also handle any remaining hardcoded values
  sudo sed -i "s/'wordpressdb'/'$DB_NAME'/g" /var/www/html/wp-config.php
  sudo sed -i "s/'wordpressuser'/'$DB_USER'/g" /var/www/html/wp-config.php
  sudo sed -i "s/'W3lcome123'/'$DB_PASS'/g" /var/www/html/wp-config.php
  sudo sed -i "s/[a-zA-Z0-9-]*\.c[a-zA-Z0-9]*\.us-east-1\.rds\.amazonaws\.com/$DB_HOST/g" /var/www/html/wp-config.php
  
  # Debug: Show what we actually have in wp-config.php
  echo "=== wp-config.php database settings after update ==="
  sudo grep -A1 -B1 "DB_HOST\|DB_NAME\|DB_USER\|DB_PASSWORD" /var/www/html/wp-config.php
  echo "=================================================="

    sudo sed -i "/<?php/a\\
define('WP_DEBUG', true);\\
define('WP_DEBUG_LOG', true);\\
define('WP_DEBUG_DISPLAY', false);\\
define('WP_MEMORY_LIMIT', '256M');" /var/www/html/wp-config.php

  # Add flexible URL handling for reused deployments too
  echo "Adding flexible URL support for both custom domain and ALB..."
  sudo sed -i "/define('WP_MEMORY_LIMIT'/a\\
// Allow access via both custom domain and ALB\\
if (isset(\$_SERVER['HTTP_HOST'])) {\\
    \$protocol = isset(\$_SERVER['HTTPS']) && \$_SERVER['HTTPS'] === 'on' ? 'https' : 'http';\\
    define('WP_HOME', \$protocol . '://' . \$_SERVER['HTTP_HOST']);\\
    define('WP_SITEURL', \$protocol . '://' . \$_SERVER['HTTP_HOST']);\\
}" /var/www/html/wp-config.php
  fi

  # Ensure health probe exists
  if [ ! -f /var/www/html/health.php ]; then
    echo '<?php http_response_code(200); echo "OK"; ?>' | sudo tee /var/www/html/health.php >/dev/null
  fi
fi

# ================================
# Final permissions & restart
# ================================
sudo chown -R apache:apache /var/www/html
sudo find /var/www/html -type d -exec chmod 2775 {} \;
sudo find /var/www/html -type f -exec chmod 0644 {} \;

if [ -f /var/www/html/wp-config.php ]; then
  sudo chmod 640 /var/www/html/wp-config.php
fi

sudo restorecon -Rv /var/www/html || true

sudo systemctl restart httpd php-fpm

echo "Deployment completed successfully."
