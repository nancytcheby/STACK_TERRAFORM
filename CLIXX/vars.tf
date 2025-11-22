variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "engineer_role_arn" {
  description = "IAM Role ARN in the DEV account that Terraform will assume"
  type        = string
}

variable "clixx_db_snapshot_identifier" {
  description = "Snapshot ID to restore the Clixx database from"
  type        = string
}

variable "clixx_db_instance_class" {
  description = "Instance class for the restored Clixx DB"
  type        = string
  default     = "db.t3.micro"
}

variable "clixx_db_subnet_group_name" {
  description = "Existing DB subnet group name to use for the Clixx DB"
  type        = string
}

# ----------------------------------------
# Database Credentials Variables
# ----------------------------------------

variable "clixx_db_username" {
  description = "Database username for the restored database (should match snapshot)"
  type        = string
  default     = "admin"  # Common default, but should match your snapshot
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
  description = "VPC ID where Clixx resources are created"
  type        = string
}

variable "clixx_alb_subnet_ids" {
  description = "Subnet IDs for the ALB (should be at least two public subnets in different AZs)"
  type        = list(string)
}

variable "clixx_efs_subnet_ids" {
  description = "Subnet IDs where EFS mount targets will be created"
  type        = list(string)
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
<<<<<<< HEAD
  description = "Whether ALB is internal (true) or internet-facing (false)"
=======
  description = "Whether the ALB is internal (true) or internet-facing (false)"
>>>>>>> dev
  type        = bool
  default     = false
}

# ----------------------------------------
# Target Group Variables
# ----------------------------------------

variable "clixx_tg_name" {
  description = "Name of the Clixx target group"
  type        = string
}

variable "clixx_tg_port" {
  description = "Port for target group"
  type        = number
}

variable "clixx_tg_protocol" {
  description = "Protocol for target group"
  type        = string
}

variable "clixx_tg_health_check_path" {
  description = "Path used by the ALB target group health check"
  type        = string
<<<<<<< HEAD
  default     = "/health.php"
=======
  default     = "/"
>>>>>>> dev
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
<<<<<<< HEAD
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
  description = "Subnet IDs where the ASG will launch EC2 instances"
  type        = list(string)
}

# ----------------------------------------
# EC2 / Launch Template Variables
# ----------------------------------------

variable "clixx_ami_id" {
  description = "AMI ID to use for Clixx EC2 instances"
  type        = string
}

variable "clixx_instance_type" {
  description = "Instance type for Clixx EC2 instances"
  type        = string
  default     = "t4g.micro"
}

variable "clixx_iam_instance_profile_name" {
  description = "Name of the IAM instance profile for EC2 instances"
  type        = string
}

variable "clixx_iam_role_name" {
  description = "Name of the IAM role for EC2 instances"
  type        = string
  default     = "EC2WordPressRole"  
}

variable "admin_ssm_role_arn" {
  description = "IAM Role ARN in the Admin account used for SSM access"
  type        = string
}

variable "AWS_ACCESS_KEY" {
  description = "Access key for the admin/management account (for SSM Parameter Store)"
  type        = string
}

variable "AWS_SECRET_KEY" {
  description = "Secret key for the admin/management account (for SSM Parameter Store)"
  type        = string
  sensitive   = true
}

variable "PARAMETER_STORE_REGION" {
  description = "AWS region where Parameter Store secrets are stored (admin account)"
  type        = string
  default     = "us-east-1"
=======
# Security / EFS extras
# ----------------------------------------

variable "clixx_db_allowed_cidr" {
  description = "CIDR block allowed to access the Clixx DB"
  type        = string
  default     = "0.0.0.0/0"
}

variable "clixx_efs_name" {
  description = "Name of the Clixx EFS filesystem"
  type        = string
  default     = "clixx-efs-dev"
>>>>>>> dev
}
