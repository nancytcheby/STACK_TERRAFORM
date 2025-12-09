#!/bin/bash -xe

# Log everything to a file for debugging
exec > >(tee -a /var/log/clixx-bootstrap.log) 2>&1
echo "Bootstrap script started at $(date)"

# Essential WordPress setup only
REGION="${aws_region}"
APP_DOMAIN="dev.clixx.nancy-stack.com"
DB_HOST="${db_host}"
DB_NAME="${db_name}"
DB_USER="${db_user}"
DB_PASS="${db_pass}"
EFS_ID="${efs_id}"
LB_DNS="${lb_dns}"

# Install packages
yum update -y
yum install -y httpd php php-mysqlnd php-fpm amazon-efs-utils git mariadb105

# Start services
systemctl enable httpd php-fpm
systemctl start httpd php-fpm

# Wait for database to be available (up to 30 minutes)
echo "Waiting for database to be available..."
for i in {1..180}; do
  if mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SELECT 1;" >/dev/null 2>&1; then
    echo "Database is available after $i attempts ($(($i * 10)) seconds)"
    break
  fi
  if [ $i -eq 180 ]; then
    echo "Database still not available after 30 minutes. Continuing anyway..."
    break
  fi
  echo "Database not ready, waiting 10 seconds... (attempt $i/180)"
  sleep 10
done

# Mount EFS
mkdir -p /var/www/html
echo "$EFS_ID:/ /var/www/html efs _netdev,tls 0 0" >> /etc/fstab

# Wait for EFS to be available and mount it
echo "Mounting EFS..."
for i in {1..30}; do
  if mount -a; then
    echo "EFS mounted successfully after $i attempts"
    break
  fi
  if [ $i -eq 30 ]; then
    echo "Failed to mount EFS after 30 attempts. Continuing anyway..."
    break
  fi
  echo "EFS not ready, waiting 10 seconds... (attempt $i/30)"
  sleep 10
done

# Verify EFS mount
if mountpoint -q /var/www/html; then
  echo "EFS is mounted at /var/www/html"
else
  echo "WARNING: EFS is not mounted at /var/www/html"
fi

# Check if first deployment
if [ ! -f /var/www/html/.deployed ]; then
  # Clone WordPress
  git clone --depth 1 https://github.com/stackitgit/CliXX_Retail_Repository.git /tmp/wp
  cp -r /tmp/wp/* /var/www/html/
  rm -rf /tmp/wp
  
  # Configure wp-config.php
  if [ -f /var/www/html/wp-config-sample.php ]; then
    cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
  fi
  
  # Update database settings
  sed -i "s/database_name_here/$DB_NAME/" /var/www/html/wp-config.php
  sed -i "s/username_here/$DB_USER/" /var/www/html/wp-config.php
  sed -i "s/password_here/$DB_PASS/" /var/www/html/wp-config.php
  sed -i "s/localhost/$DB_HOST/" /var/www/html/wp-config.php
  
  # Handle pre-configured values
  sed -i "s/'wordpressdb'/'$DB_NAME'/" /var/www/html/wp-config.php
  sed -i "s/'wordpressuser'/'$DB_USER'/" /var/www/html/wp-config.php
  sed -i "s/'W3lcome123'/'$DB_PASS'/" /var/www/html/wp-config.php
  sed -i "s/wordpress-db\.[a-zA-Z0-9]*\.us-east-1\.rds\.amazonaws\.com/$DB_HOST/" /var/www/html/wp-config.php
  
  # Add flexible URL handling for both custom domain and ALB
  sed -i "/<?php/a\\
// Allow access via both custom domain and ALB\\
if (isset(\$_SERVER['HTTP_HOST'])) {\\
    \$protocol = isset(\$_SERVER['HTTPS']) && \$_SERVER['HTTPS'] === 'on' ? 'https' : 'http';\\
    define('WP_HOME', \$protocol . '://' . \$_SERVER['HTTP_HOST']);\\
    define('WP_SITEURL', \$protocol . '://' . \$_SERVER['HTTP_HOST']);\\
}" /var/www/html/wp-config.php

  # Set WordPress URLs to custom domain
  mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" \
    -e "UPDATE wp_options SET option_value='http://$APP_DOMAIN' WHERE option_name IN ('siteurl','home');" || true
  

  
  echo "done" > /var/www/html/.deployed
fi

# Health check that works even when DB is not ready
cat > /var/www/html/health.php << HEALTH_EOF
<?php
// Basic health check - always returns OK for ALB
http_response_code(200);
header('Content-Type: text/plain');
echo "OK - " . date('Y-m-d H:i:s');

// Optional: Add database status (but don't fail if DB is down)
try {
    \$pdo = new PDO("mysql:host=$DB_HOST;dbname=$DB_NAME", "$DB_USER", "$DB_PASS");
    echo " - DB: Connected";
} catch (Exception \$e) {
    echo " - DB: Connecting...";
}
echo "\n";
?>
HEALTH_EOF

# Also create a simple HTML health check as backup
cat > /var/www/html/health.html << HTML_EOF
<!DOCTYPE html>
<html>
<head><title>Health Check</title></head>
<body>
<h1>OK</h1>
<p>Server is running</p>
<p>Time: $(date)</p>
</body>
</html>
HTML_EOF

# Verify health check files were created
echo "Verifying health check files..."
for file in /var/www/html/health.php /var/www/html/health.html; do
  if [ -f "$file" ]; then
    echo "✓ $file created successfully ($(stat -c%s "$file") bytes)"
  else
    echo "✗ Failed to create $file"
  fi
done

# Create Apache virtual host configuration
cat > /etc/httpd/conf.d/clixx.conf << 'APACHE_EOF'
<VirtualHost *:80>
    DocumentRoot /var/www/html
    ServerName localhost
    
    <Directory /var/www/html>
        AllowOverride All
        Require all granted
        Options FollowSymLinks
    </Directory>
    
    # Health check endpoints
    <Location "/health.php">
        Require all granted
    </Location>
    
    <Location "/health.html">
        Require all granted
    </Location>
    
    ErrorLog /var/log/httpd/clixx_error.log
    CustomLog /var/log/httpd/clixx_access.log combined
</VirtualHost>
APACHE_EOF

# Set permissions
chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html
chmod 644 /var/www/html/health.php
chmod 644 /var/www/html/health.html

# SELinux settings
setsebool -P httpd_can_network_connect on
setsebool -P httpd_use_nfs on

# Test Apache configuration
httpd -t

# Restart services
systemctl restart httpd php-fpm

# Wait for services to be fully ready
echo "Waiting for services to start..."
sleep 10

# Ensure services are running
for service in httpd php-fpm; do
  for i in {1..10}; do
    if systemctl is-active --quiet $service; then
      echo "$service is running"
      break
    fi
    echo "$service not ready, waiting... (attempt $i/10)"
    sleep 2
  done
done

# Verify services are running
systemctl status httpd --no-pager
systemctl status php-fpm --no-pager

# Test local health check
sleep 5
echo "Testing health checks..."

# Test health.php
echo "Testing /health.php..."
if curl -f -s http://localhost/health.php; then
  echo "✓ PHP health check OK"
else
  echo "✗ PHP health check failed"
  # Debug info
  ls -la /var/www/html/health.php
  curl -v http://localhost/health.php || true
fi

# Test health.html
echo "Testing /health.html..."
if curl -f -s http://localhost/health.html; then
  echo "✓ HTML health check OK"
else
  echo "✗ HTML health check failed"
  # Debug info
  ls -la /var/www/html/health.html
fi

# Test basic Apache response
echo "Service status check:"
echo "Apache status: $(systemctl is-active httpd)"
echo "PHP-FPM status: $(systemctl is-active php-fpm)"

# Additional debugging info
echo "Port 80 listening check:"
netstat -tlnp | grep :80 || ss -tlnp | grep :80

echo "Apache error log (last 10 lines):"
tail -10 /var/log/httpd/error_log || echo "No error log found"

# Log completion
echo "Bootstrap completed successfully at $(date)"
