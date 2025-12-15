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

variable "public_subnets" {
  description = "Map of public subnet names to CIDR blocks"
  type        = map(string)
  default = {
    "public-1" = "10.0.0.0/24"
    "public-2" = "10.0.1.0/24"
  }
}

variable "private_subnets" {
  description = "Map of private subnet names to CIDR blocks"
  type        = map(string)
  default = {
    "private-1" = "10.0.2.0/24"
    "private-2" = "10.0.3.0/24"
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