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
    admin = "135576900189"  # Admin account where SSM parameters are stored
    dev   = "083587468058"
    test  = "279271292861"
    uat   = "818760291841"
    prod  = "767076727117"
  }
}

variable "aws_region" {
  description = "AWS region where resources will be created (can be set via TF_VAR_aws_region env variable)"
  type        = string
  default     = "us-east-1"
}

variable "engineer_role_arn" {
  description = "IAM Role ARN in the target account that Terraform will assume (dynamically determined)"
  type        = string
  default     = ""  # Will use local.engineer_role_arn instead
}

variable "clixx_db_snapshot_identifier" {
  description = "Snapshot ID to restore the Clixx database from (provide via tfvars or environment variable)"
  type        = string
  default     = ""  # Must be provided via tfvars or env variable
}

variable "clixx_db_instance_class" {
  description = "Instance class for the restored Clixx DB"
  type        = string
  default     = "db.t3.micro"
}

variable "clixx_db_subnet_group_name" {
  description = "Existing DB subnet group name to use for the Clixx DB"
  type        = string
  default     = "rds-ec2-db-subnet-group-1"
}

# ----------------------------------------
# Database Credentials Variables
# ----------------------------------------

variable "clixx_db_username" {
  description = "Database username for the restored database (should match snapshot)"
  type        = string
  default     = "wordpressuser"  
}

variable "clixx_db_password" {
  description = "Database password for the restored database (should match snapshot)"
  type        = string
  sensitive   = true
}

# ----------------------------------------
# VPC and Subnet Variables
# ----------------------------------------

variable "clixx_vpc_id" {
  description = "VPC ID where Clixx resources are created (will be discovered via data source if not provided)"
  type        = string
  default     = ""  
}

variable "clixx_alb_subnet_ids" {
  description = "Subnet IDs for the ALB (will be discovered via data source if not provided)"
  type        = list(string)
  default     = []  # Empty means use data source discovery
}

variable "clixx_efs_subnet_ids" {
  description = "Subnet IDs where EFS mount targets will be created (will be discovered via data source if not provided)"
  type        = list(string)
  default     = []  # Empty means use data source discovery
}

# ----------------------------------------
# ALB Variables
# ----------------------------------------

variable "clixx_alb_name" {
  description = "Name of the Application Load Balancer for Clixx in Dev"
  type        = string
  default     = "clixx-alb-dev"
}

variable "clixx_alb_internal" {
  description = "Whether ALB is internal (true) or internet-facing (false)"
  type        = bool
  default     = false
}

# ----------------------------------------
# Target Group Variables
# ----------------------------------------

variable "clixx_tg_name" {
  description = "Name of the Clixx target group"
  type        = string
  default     = "clixx-tg"  
}

variable "clixx_tg_port" {
  description = "Port for target group"
  type        = number
  default     = 80
}

variable "clixx_tg_protocol" {
  description = "Protocol for target group"
  type        = string
  default     = "HTTP"
}

variable "clixx_tg_health_check_path" {
  description = "Path used by the ALB target group health check"
  type        = string
  default     = "/health.php"
}

# ----------------------------------------
# Security Group / Access Variables
# ----------------------------------------

variable "clixx_db_allowed_cidr" {
  description = "CIDR block allowed to access the Clixx DB"
  type        = string
  default     = "0.0.0.0/0"
}

# ----------------------------------------
# EFS Variables
# ----------------------------------------

variable "clixx_efs_name" {
  description = "Name of the Clixx EFS filesystem"
  type        = string
  default     = "clixx-efs-dev"
}

# ----------------------------------------
# Key Pair Variables
# ----------------------------------------

variable "clixx_key_name" {
  description = "Name of the SSH key pair for Clixx EC2 instances"
  type        = string
  default     = "clixx-key-dev"
}

# ----------------------------------------
# Auto Scaling Group (ASG) Variables
# ----------------------------------------

variable "clixx_asg_name" {
  description = "Name of the Auto Scaling Group for Clixx"
  type        = string
  default     = "clixx-asg-dev"
}

variable "clixx_asg_min_size" {
  description = "Minimum number of instances in the Clixx ASG"
  type        = number
  default     = 1
}

variable "clixx_asg_max_size" {
  description = "Maximum number of instances in the Clixx ASG"
  type        = number
  default     = 1
}

variable "clixx_asg_desired_capacity" {
  description = "Desired number of instances in the Clixx ASG"
  type        = number
  default     = 1
}

variable "clixx_asg_subnet_ids" {
  description = "Subnet IDs where the ASG will launch EC2 instances (will be discovered via data source if not provided)"
  type        = list(string)
  default     = []  # Empty means use data source discovery
}

# ----------------------------------------
# EC2 Configuration Map (All EC2 properties in one place)
# ----------------------------------------

variable "ec2_config" {
  description = "Map containing all EC2 configuration properties"
  type        = map(any)
  default = {
    ami_id                    = "ami-0dda28e5df2d25176"
    instance_type            = "t4g.micro"
    key_name                 = "clixx-key-dev"
    iam_role_name            = "EC2-Access-Role"
    
    # Auto Scaling Group settings
    asg_name            = "clixx-asg-dev"
    asg_min_size        = 1
    asg_max_size        = 1
    asg_desired_capacity = 1
    
    # Health check settings
    health_check_type         = "ELB"
    health_check_grace_period = 1200
    
    # Launch template settings
    enable_detailed_monitoring = true
    ebs_optimized             = false
  }
}

# ----------------------------------------
# Security Group Dynamic Rules Configuration
# ----------------------------------------

variable "ingress_rules" {
  description = "List of ingress rules for security group"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
  default = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "SSH access"
    },
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTP access"
    },
    {
      from_port   = 3306
      to_port     = 3306
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "MySQL access"
    },
    {
      from_port   = 2049
      to_port     = 2049
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "NFS for EFS"
    }
  ]
}

variable "admin_ssm_role_arn" {
  description = "IAM Role ARN in the Admin account used for SSM access"
  type        = string
  default     = "arn:aws:iam::135576900189:role/TerraformSSMRole"
}

# AWS credentials should be provided via AWS CLI, environment variables, or IAM roles
# Never include AWS_ACCESS_KEY or AWS_SECRET_KEY in Terraform code

variable "PARAMETER_STORE_REGION" {
  description = "AWS region where Parameter Store secrets are stored (admin account)"
  type        = string
  default     = "us-east-1"
}

# ----------------------------------------
# Route53 / DNS Variables
# ----------------------------------------

variable "clixx_env" {
  description = "Environment name used in DNS (dev, test, uat, prod)"
  type        = string
  default     = ""  
}

variable "clixx_base_domain" {
  description = "Base public DNS domain (hosted zone) for Clixx"
  type        = string
  default     = "nancy-stack.com"
}

variable "root_domain" {
  description = "Root hosted zone domain name"
  type        = string
  default     = "nancy-stack.com"
}

variable "clixx_subdomain" {
  description = "Environment subdomain for Clixx (dev/test/uat/prod)"
  type        = string
  default     = "dev.clixx"  
}

# ----------------------------------------
# Standard Tags Configuration
# ----------------------------------------

variable "owner_email" {
  description = "Email address of the resource owner"
  type        = string
  default     = "nancy@example.com"  # Update with your actual email
}

# ----------------------------------------
# Local Values for Standard Tags
# ----------------------------------------
# Note: common_tags and engineer_role_arn are defined in datasources.tf
