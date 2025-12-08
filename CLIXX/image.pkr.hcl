variable "aws_source_ami" {
  description = "Source AMI name pattern"
  default     = "amzn2-ami-hvm-*-arm64-gp2"  # Changed to ARM64 for t4g instances
}

variable "aws_instance_type" {
  description = "Instance type for building the AMI"
  default     = "t4g.small"  # ARM-based instance
}

variable "ami_name" {
  description = "Name of the AMI to create"
  default     = "clixx-ami-1"
}

variable "component" {
  description = "Component name for tagging"
  default     = "clixx"
}

variable "aws_accounts" {
  description = "AWS account IDs to share the AMI with"
  type        = list(string)
  default = [
    "083587468058",  # Dev account
    "279271292861",  # Test account
    "818760291841",  # UAT account
    "767076727117"   # Prod account
  ]
}

variable "ami_regions" {
  description = "Regions to copy the AMI to"
  type        = list(string)
  default     = ["us-east-1"]
}

variable "aws_region" {
  description = "AWS region to build the AMI in"
  default     = "us-east-1"
}

# Get the latest Amazon Linux 2 ARM64 AMI
data "amazon-ami" "source_ami" {
  most_recent = true
  owners      = ["amazon"]

  filters = {
    name                = "amzn2-ami-hvm-*-arm64-gp2"  # ARM64 for t4g instances
    virtualization-type = "hvm"
    root-device-type    = "ebs"
    architecture        = "arm64"
  }

  region = var.aws_region
}

# ------------------------------------------------------------------------------------
# EBS Builder Configuration
# ------------------------------------------------------------------------------------

source "amazon-ebs" "clixx_ami" {
  ami_name      = "${var.ami_name}"
  ami_regions   = var.ami_regions
  ami_users     = var.aws_accounts
  snapshot_users = var.aws_accounts
  
  encrypt_boot  = false
  instance_type = var.aws_instance_type

  launch_block_device_mappings {
    delete_on_termination = true
    device_name           = "/dev/xvda"
    encrypted             = false
    volume_size           = 10
    volume_type           = "gp3"
  }

  region     = var.aws_region
  source_ami = data.amazon-ami.source_ami.id
  
  ssh_pty      = true
  ssh_timeout  = "10m"
  ssh_username = "ec2-user"

  tags = {
    Name        = "${var.ami_name}"
    Component   = "${var.component}"
    Environment = "shared"
    BuildDate   = "{{ timestamp }}"
    OS          = "Amazon Linux 2"
    Architecture = "ARM64"
  }
}

# ------------------------------------------------------------------------------------
# Build Configuration
# ------------------------------------------------------------------------------------

build {
  sources = ["source.amazon-ebs.clixx_ami"]

  # Install WordPress dependencies
  provisioner "shell" {
    inline = [
      "echo '======================================'",
      "echo 'Installing WordPress dependencies...'",
      "echo '======================================'",
      "sudo yum update -y",
      
      # Install Apache
      "sudo yum install -y httpd",
      
      # Install PHP 7.4 and extensions
      "sudo amazon-linux-extras install -y php7.4",
      "sudo yum install -y php-{mbstring,xml,xmlrpc,gd,mysqli,mysqlnd,curl,json,zip}",
      
      # Install NFS utils for EFS
      "sudo yum install -y nfs-utils",
      
      # Install AWS CLI v2
      "curl 'https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip' -o 'awscliv2.zip'",
      "unzip -q awscliv2.zip",
      "sudo ./aws/install",
      "rm -rf aws awscliv2.zip",
      
      # Enable and start Apache
      "sudo systemctl enable httpd",
      
      # Create WordPress directory structure
      "sudo mkdir -p /var/www/html",
      
      # Set proper permissions
      "sudo chown -R apache:apache /var/www/html",
      "sudo chmod -R 755 /var/www/html",
      
      # Configure PHP
      "sudo sed -i 's/upload_max_filesize = .*/upload_max_filesize = 64M/' /etc/php.ini",
      "sudo sed -i 's/post_max_size = .*/post_max_size = 64M/' /etc/php.ini",
      "sudo sed -i 's/max_execution_time = .*/max_execution_time = 300/' /etc/php.ini",
      
      "echo '======================================'",
      "echo 'Installation complete!'",
      "echo '======================================'",
    ]
  }

  # Create a health check endpoint
  provisioner "shell" {
    inline = [
      "echo '<?php echo \"OK\"; ?>' | sudo tee /var/www/html/health.php",
      "sudo chown apache:apache /var/www/html/health.php",
    ]
  }

  # Clean up
  provisioner "shell" {
    inline = [
      "echo 'Cleaning up...'",
      "sudo yum clean all",
      "sudo rm -rf /tmp/*",
      "sudo rm -rf /var/tmp/*",
    ]
  }

  # Generate manifest file
  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
  }
}
