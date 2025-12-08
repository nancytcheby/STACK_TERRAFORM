# ========================================
# Data Sources for Clixx Infrastructure
# ========================================

# ----------------------------------------
# Data Sources - Dynamic Resource Discovery
# ----------------------------------------

# Get default VPC (only used if create_custom_vpc = false)
data "aws_vpc" "clixx_vpc" {
  count   = var.create_custom_vpc ? 0 : 1
  default = true
}

# Get all public subnets in the default VPC (only used if create_custom_vpc = false)
data "aws_subnets" "clixx_public_subnets" {
  count = var.create_custom_vpc ? 0 : 1

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.clixx_vpc[0].id]
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
    values = [local.vpc_id]
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

# Get existing DB subnet group (only used if create_custom_vpc = false)
data "aws_db_subnet_group" "clixx_db_subnet_group" {
  count = var.create_custom_vpc ? 0 : 1
  name  = var.clixx_db_subnet_group_name
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
  count        = var.root_domain != "" ? 1 : 0
  name         = var.root_domain
  private_zone = false
}

# Get instances in the ASG (for Inspector scanning)
data "aws_instances" "clixx_asg_instances" {
  filter {
    name   = "tag:aws:autoscaling:groupName"
    values = [aws_autoscaling_group.clixx_asg.name]
  }
  
  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
  
  depends_on = [aws_autoscaling_group.clixx_asg]
}

# ========================================
# Local Values for Resource Configuration
# ========================================

locals {
  common_tags = {
    stackTeam   = "stackcloud14"
    OwnerEmail  = "nancytcheby@hotmail.com"
    Environment = try(var.env, "dev")
    Project     = "clixx"
    CostCenter  = "cc1234"
    Application = "clixx"
  }

  # VPC ID - Use custom VPC if created, otherwise use default VPC
  vpc_id = var.create_custom_vpc ? aws_vpc.clixx_vpc[0].id : var.clixx_vpc_id

  public_subnet_ids  = var.create_custom_vpc ? aws_subnet.clixx_public_subnet[*].id : var.clixx_alb_subnet_ids
  private_subnet_ids = var.create_custom_vpc ? aws_subnet.clixx_private_subnet[*].id : var.clixx_efs_subnet_ids

  db_subnet_group_name = var.create_custom_vpc ? aws_db_subnet_group.clixx_db_subnet_group[0].name : var.clixx_db_subnet_group_name

  efs_subnet_ids = local.private_subnet_ids
  asg_subnet_ids = local.private_subnet_ids
  alb_subnet_ids = local.public_subnet_ids
}

