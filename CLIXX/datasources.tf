# ========================================
# Data Sources for Clixx Infrastructure
# ========================================

# ----------------------------------------
# Data Sources - Dynamic Resource Discovery
# ----------------------------------------

# Get default VPC (most common approach)
data "aws_vpc" "clixx_vpc" {
  default = true
}

# Get all public subnets in the VPC
data "aws_subnets" "clixx_public_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.clixx_vpc.id]
  }
  
  filter {
    name   = "map-public-ip-on-launch"
    values = ["true"]
  }
}

# Get existing security groups
data "aws_security_groups" "existing_sgs" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.clixx_vpc.id]
  }
}

# Get latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# Use the created key pair resource instead of data source
# data "aws_key_pair" "clixx_key" {
#   key_name           = var.clixx_key_name
#   include_public_key = true
# }

# IAM role and instance profile are now created as resources in iam.tf

# Get existing DB subnet group
data "aws_db_subnet_group" "clixx_db_subnet_group" {
  name = var.clixx_db_subnet_group_name
}

# Get availability zones for the region
data "aws_availability_zones" "available" {
  state = "available"
}

# Get current AWS caller identity
data "aws_caller_identity" "current" {}

# Get current AWS region
data "aws_region" "current" {}

# Get Route53 hosted zone for DNS
data "aws_route53_zone" "selected_zone" {
  count = var.root_domain != "" ? 1 : 0
  name  = var.root_domain
  private_zone = false
}

# ========================================
# Local Values for Resource Configuration
# ========================================

locals {
  # Standard tags that meet professor requirements
  common_tags = {
    stackTeam   = "stackcloud14"
    OwnerEmail  = "nancytcheby@hotmail.com"
    Environment = try(var.env, "dev")
    Project     = "clixx"
    CostCenter  = "cc1234"
    Application = "clixx"
  }

  # Subnet IDs - dynamically discovered from public subnets
  alb_subnet_ids = data.aws_subnets.clixx_public_subnets.ids

  efs_subnet_ids = length(var.clixx_efs_subnet_ids) > 0 ? var.clixx_efs_subnet_ids : local.alb_subnet_ids

  asg_subnet_ids = length(var.clixx_asg_subnet_ids) > 0 ? var.clixx_asg_subnet_ids : local.alb_subnet_ids
}

