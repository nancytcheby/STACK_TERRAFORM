#!/bin/bash
set -e

echo "Installing Dependencies"
echo "======================================================================"
sudo dnf upgrade -y
sudo dnf install -y mariadb105-server httpd wget php-mysqlnd php-fpm php-mysqli php-json php php-devel
sudo dnf install -y nfs-utils git amazon-efs-utils

echo "Starting Services"
sudo systemctl start httpd php-fpm
sudo systemctl enable httpd php-fpm

echo "======================================================================"
echo "Enabling SELinux for NFS/EFS"
sudo setsebool -P httpd_use_nfs 1

echo "======================================================================"
echo "Setting Permissions"
sudo usermod -a -G apache ec2-user   
sudo chown -R ec2-user:apache /var/www     
sudo chmod 2775 /var/www && find /var/www -type d -exec sudo chmod 2775 {} \;   
find /var/www -type f -exec sudo chmod 0664 {} \;

echo "======================================================================"
echo "Setup complete!"