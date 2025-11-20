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
  description = "Whether the ALB is internal (true) or internet-facing (false)"
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
  default     = "/"
}

# ----------------------------------------
# Key Pair Variable (Story: Key Pair)
# ----------------------------------------

variable "clixx_key_name" {
  description = "Name of the SSH key pair for Clixx EC2 instances"
  type        = string
  default     = "clixx-key-dev"
}

# ----------------------------------------
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
}
