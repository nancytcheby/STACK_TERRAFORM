# ========================================
# Data Sources for Clixx Infrastructure
# ========================================

# Get latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["083587468058", "818760291841"]

  filter {
    name   = "name"
    values = [var.custom_ami_name]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# Get availability zones for the region
data "aws_availability_zones" "available" {
  state = "available"
}

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
    Environment = var.env
    Project     = "clixx"
  }

  vpc_id               = aws_vpc.clixx_vpc.id
  public_subnet_ids    = [for subnet in aws_subnet.clixx_public_subnet : subnet.id]
  private_subnet_ids   = [for subnet in aws_subnet.clixx_private_subnet : subnet.id]
  db_subnet_group_name = aws_db_subnet_group.clixx_db_subnet_group.name

  efs_subnet_ids = local.private_subnet_ids
  asg_subnet_ids = local.private_subnet_ids
  alb_subnet_ids = local.public_subnet_ids
}

