# ----------------------------------------
# Environment and Account Configuration
# ----------------------------------------

variable "env" {
  description = "Environment name (dev, test, uat, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "test", "uat", "prod"], var.env)
    error_message = "Environment must be one of: dev, test, uat, prod."
  }
}

variable "accounts" {
  description = "Map of environment to AWS account IDs"
  type        = map(string)
  default = {
    admin = "135576900189" 
    dev   = "083587468058"
    test  = "279271292861"
    uat   = "818760291841"
    prod  = "767076727117"
  }
}

variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"
}

# ----------------------------------------
# VPC Configuration
# ----------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for the custom VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# Public Subnets - ALB & Bastion (450 hosts each)
variable "public_subnets" {
  description = "Map of public subnet names to CIDR blocks"
  type        = map(string)
  default = {
    "public-1" = "10.0.0.0/23"
    "public-2" = "10.0.2.0/23"
  }
}

# Private Subnets - Web/Application Servers (250 hosts each)
variable "private_web_subnets" {
  description = "Map of private web server subnet names to CIDR blocks"
  type        = map(string)
  default = {
    "private-web-1" = "10.0.4.0/24"
    "private-web-2" = "10.0.5.0/24"
  }
}

# Private Subnets - RDS MySQL Database (680 hosts each)
variable "private_rds_subnets" {
  description = "Map of private RDS subnet names to CIDR blocks"
  type        = map(string)
  default = {
    "private-rds-1" = "10.0.8.0/22"
    "private-rds-2" = "10.0.12.0/22"
  }
}

# Private Subnets - Oracle Database (254 hosts each)
variable "private_oracle_subnets" {
  description = "Map of private Oracle DB subnet names to CIDR blocks"
  type        = map(string)
  default = {
    "private-oracle-1" = "10.0.16.0/24"
    "private-oracle-2" = "10.0.17.0/24"
  }
}

# Private Subnets - Java Database (50 hosts each)
variable "private_java_db_subnets" {
  description = "Map of private Java DB subnet names to CIDR blocks"
  type        = map(string)
  default = {
    "private-java-db-1" = "10.0.18.0/26"
    "private-java-db-2" = "10.0.18.64/26"
  }
}

# Private Subnets - Java Application Servers (50 hosts each)
variable "private_java_app_subnets" {
  description = "Map of private Java app server subnet names to CIDR blocks"
  type        = map(string)
  default = {
    "private-java-app-1" = "10.0.18.128/26"
    "private-java-app-2" = "10.0.18.192/26"
  }
}



# ----------------------------------------
# Database Configuration
# ----------------------------------------

variable "database_config" {
  description = "Map of DB settings for Clixx"
  type        = map(string)
  default = {
    snapshot_identifier = "arn:aws:rds:us-east-1:577701061234:snapshot:wordpressdbclixx-ecs-snapshot"
    instance_class      = "db.t3.micro"
    username            = "wordpressuser"
    db_name             = "wordpressdb"
  }
}

# ----------------------------------------
# EC2 Configuration
# ----------------------------------------

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "custom_ami_name" {
  description = "Name pattern of the custom AMI created by Packer"
  type        = string
  default     = "ami-stack-14"
}

# ----------------------------------------
# ALB Configuration
# ----------------------------------------

variable "alb_config" {
  description = "ALB configuration settings"
  type        = map(string)
  default = {
    name     = "clixx-alb"
    internal = "false"
  }
}

# ----------------------------------------
# Target Group Configuration
# ----------------------------------------

variable "tg_config" {
  description = "Target group configuration settings"
  type        = map(string)
  default = {
    name              = "clixx-tg"
    port              = "80"
    protocol          = "HTTP"
    health_check_path = "/health.php"
  }
}

# ----------------------------------------
# Auto Scaling Configuration
# ----------------------------------------

variable "asg_config" {
  description = "Auto Scaling Group configuration"
  type        = map(number)
  default = {
    min_size                  = 1
    max_size                  = 1
    desired_capacity          = 1
    health_check_grace_period = 1200
  }
}

# ----------------------------------------
# IAM Configuration
# ----------------------------------------

variable "admin_ssm_role_arn" {
  description = "IAM Role ARN in the Admin account used for SSM access"
  type        = string
  default     = "arn:aws:iam::135576900189:role/TerraformSSMRole"
}

# ----------------------------------------
# Route53 / DNS Configuration
# ----------------------------------------

variable "root_domain" {
  description = "Root hosted zone domain name"
  type        = string
  default     = "nancy-stack.com"
}

variable "subdomain" {
  description = "Subdomain for the application"
  type        = string
  default     = "dev.clixx"
}