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
  description = "AWS region where resources will be created (can be set via TF_VAR_aws_region env variable)"
  type        = string
  default     = "us-east-1"
}

variable "engineer_role_arn" {
  description = "IAM Role ARN in the target account that Terraform will assume (dynamically determined)"
  type        = string
  default     = ""  
}

# ----------------------------------------
# VPC Configuration (NEW)
# ----------------------------------------

variable "create_custom_vpc" {
  description = "Whether to create custom VPC (true) or use default VPC (false)"
  type        = bool
  default     = true  # Set to false to use default VPC
}

variable "vpc_cidr" {
  description = "CIDR block for the custom VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (2 subnets for HA)"
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (2 subnets for HA)"
  type        = list(string)
  default     = ["10.0.2.0/24", "10.0.3.0/24"]
}

# ----------------------------------------
# Database Configuration
# ----------------------------------------

variable "clixx_db_snapshot_identifier" {
  description = "Snapshot ID to restore the Clixx database from (provide via tfvars or environment variable)"
  type        = string
  default     = "arn:aws:rds:us-east-1:577701061234:snapshot:wordpressdbclixx-ecs-snapshot"  
}

variable "clixx_db_instance_class" {
  description = "Instance class for the restored Clixx DB"
  type        = string
  default     = "db.t3.micro"
}

variable "clixx_db_subnet_group_name" {
  description = "Existing DB subnet group name to use for the Clixx DB (only used if create_custom_vpc = false)"
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
# VPC and Subnet Variables (Legacy - for default VPC mode)
# ----------------------------------------

variable "clixx_vpc_id" {
  description = "VPC ID where Clixx resources are created (only used if create_custom_vpc = false)"
  type        = string
  default     = "vpc-03933c67bfb9249b8" 
}

variable "clixx_alb_subnet_ids" {
  description = "Subnet IDs for the ALB (only used if create_custom_vpc = false)"
  type        = list(string)
  default     = [
    "subnet-0c37fbad8b3a6bc36", # us-east-1c
    "subnet-0664e01d9700d97ec", # us-east-1b
    "subnet-0c5c62a0c20a0c08d"  # us-east-1e
  ]
}

variable "clixx_efs_subnet_ids" {
  description = "Subnet IDs where EFS mount targets will be created (only used if create_custom_vpc = false)"
  type        = list(string)
  default     = [
    "subnet-0c37fbad8b3a6bc36", # us-east-1c
    "subnet-0664e01d9700d97ec"  # us-east-1b
  ]
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
  description = "Subnet IDs where ASG instances launch (only used if create_custom_vpc = false)"
  type        = list(string)
  default = [
    "subnet-0c37fbad8b3a6bc36",
    "subnet-0664e01d9700d97ec"  
  ]
}


# ----------------------------------------
# EC2 Configuration Map 
# ----------------------------------------

variable "custom_ami_id" {
  description = "Custom AMI ID from Packer build (overrides ec2_config.ami_id if provided)"
  type        = string
  default     = ""
}

variable "ec2_config" {
  description = "Map containing all EC2 configuration properties"
  type        = map(any)
  default = {
    ami_id                    = "ami-0dda28e5df2d25176"  # Fallback AMI (ARM64 Amazon Linux 2)
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
    health_check_grace_period = 3600 
    
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
  default     = "nancy@example.com" 
}


variable "database_config" {
  description = "Map of DB settings for Clixx"
  type        = map(string)
  default = {
    snapshot_identifier = "arn:aws:rds:us-east-1:577701061234:snapshot:wordpressdbclixx-ecs-snapshot"
    instance_class      = "db.t3.micro"
    username            = "wordpressuser"
  }
}

variable "clixx_db_name" {
  description = "Database name for CliXX"
  type        = string
  default     = "clixx_db"
}

variable "domain_name" {
  description = "Domain name for CliXX application"
  type        = string
  default     = "nancy-stack.com"
}