# ========================================
# Main Terraform Configuration for Clixx
# ========================================

# ========================================
# IAM Resources
# ========================================

# IAM Policy for cross-account SSM access
resource "aws_iam_policy" "clixx_cross_account_ssm_policy" {
  name        = try(format("ClixxCrossAccountSSMPolicy-%s", var.env), "ClixxCrossAccountSSMPolicy")
  description = "Allow EC2 instances to read SSM parameters in Admin account"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ],
        Resource = [
          "arn:aws:ssm:${var.aws_region}:${lookup(var.accounts, "admin")}:parameter/database/*",
          "arn:aws:ssm:${var.aws_region}:${lookup(var.accounts, "admin")}:parameter/efs_id",
          "arn:aws:ssm:${var.aws_region}:${lookup(var.accounts, "admin")}:parameter/Clixx_dns",
          "arn:aws:ssm:${var.aws_region}:${lookup(var.accounts, "admin")}:parameter/clixx/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "sts:AssumeRole"
        ],
        Resource = [
          var.admin_ssm_role_arn
        ]
      }
    ]
  })

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

# ========================================
# SSH Key Pair - Creating new key pair
# ========================================

# Generate a new RSA private key
resource "tls_private_key" "clixx_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create AWS key pair using the generated public key
resource "aws_key_pair" "clixx_key" {
  key_name   = "clixx-key-${var.env}"
  public_key = tls_private_key.clixx_key.public_key_openssh

  tags = merge(local.common_tags, {
    Name = "clixx-key-${var.env}"
  })
}

# Security group is defined in clixx_sg.tf

# ========================================
# EFS File System
# ========================================

resource "aws_efs_file_system" "clixx_efs" {
  creation_token   = "clixx-efs-${var.env}"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  encrypted        = true

  tags = merge(local.common_tags, {
    Name = "clixx-efs-${var.env}"
  })
}

resource "aws_efs_mount_target" "clixx_efs_mt" {
  count           = length(local.efs_subnet_ids)
  file_system_id  = aws_efs_file_system.clixx_efs.id
  subnet_id       = local.efs_subnet_ids[count.index]
  security_groups = [aws_security_group.clixx_db_sg.id]
}

# ========================================
# RDS Database
# ========================================

resource "random_id" "db_suffix" {
  byte_length = 4
  keepers = {
    snapshot_identifier = var.database_config["snapshot_identifier"]
  }
}

resource "aws_db_instance" "clixx_db" {
  count = var.database_config["snapshot_identifier"] != "" ? 1 : 0

  identifier           = "clixx-db-${var.env}-${random_id.db_suffix.hex}"
  snapshot_identifier  = var.database_config["snapshot_identifier"]
  instance_class       = var.database_config["instance_class"]
  db_subnet_group_name = local.db_subnet_group_name
  vpc_security_group_ids = [aws_security_group.clixx_db_sg.id]
  username             = var.database_config["username"]

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  skip_final_snapshot       = var.env == "prod" ? false : true
  final_snapshot_identifier = var.env == "prod" ? "clixx-db-${var.env}-final-snapshot" : null
  deletion_protection       = var.env == "prod" ? true : false

  tags = merge(local.common_tags, {
    Name = "clixx-db-${var.env}"
  })

  lifecycle {
    ignore_changes = [password, final_snapshot_identifier]
  }
}


# ========================================
# SSM Parameters (Admin Account)
# ========================================

# ALB DNS
resource "aws_ssm_parameter" "clixx_lb_dns" {
  provider  = aws.admin
  name      = "/Clixx_dns"
  type      = "String"
  value     = aws_lb.clixx_alb.dns_name
  overwrite = true
  
  tags = local.common_tags
}

# Database host (RDS endpoint)
resource "aws_ssm_parameter" "clixx_db_host" {
  provider  = aws.admin
  name      = "/database/host"
  type      = "String"
  value     = length(aws_db_instance.clixx_db) > 0 ? aws_db_instance.clixx_db[0].address : "placeholder"
  overwrite = true
  
  tags = local.common_tags
}

# Database name
resource "aws_ssm_parameter" "clixx_db_name" {
  provider  = aws.admin
  name      = "/database/name"
  type      = "String"
  value     = "wordpressdb"
  overwrite = true
  
  tags = local.common_tags
}

# Database username
resource "aws_ssm_parameter" "clixx_db_user" {
  provider  = aws.admin
  name      = "/database/user"
  type      = "String"
  value     = var.database_config["username"]
  overwrite = true
  
  tags = local.common_tags
}

# EFS File System ID
resource "aws_ssm_parameter" "clixx_efs_id" {
  provider  = aws.admin
  name      = "/efs_id"
  type      = "String"
  value     = aws_efs_file_system.clixx_efs.id
  overwrite = true
  
  tags = local.common_tags
}

# ========================================
# Bootstrap Configuration
# ========================================

locals {
  clixx_bootstrap_user_data = templatefile("${path.module}/../images/scripts/clixx_bootstrap.sh", {
    efs_id      = aws_efs_file_system.clixx_efs.id
    db_host     = aws_db_instance.clixx_db[0].address
    db_name     = var.database_config["db_name"]
    db_user     = var.database_config["username"]
    aws_region  = var.aws_region
    domain_name = var.root_domain
    env         = var.env
    lb_dns      = aws_lb.clixx_alb.dns_name
  })
  
  clixx_bootstrap_user_data_b64 = base64encode(local.clixx_bootstrap_user_data)
}


# ========================================
# Launch Template
# ========================================

resource "aws_launch_template" "clixx_lt" {
  name_prefix   = "clixx-lt-${var.env}-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  key_name               = aws_key_pair.clixx_key.key_name
  user_data              = local.clixx_bootstrap_user_data_b64
  vpc_security_group_ids = [aws_security_group.clixx_db_sg.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_access_profile.name
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = "clixx-ec2-${var.env}"
    })
  }
}

# ========================================
# Target Group
# ========================================

resource "aws_lb_target_group" "clixx_tg" {
  name        = "${var.tg_config["name"]}-${var.env}"
  port        = var.tg_config["port"]
  protocol    = var.tg_config["protocol"]
  vpc_id      = local.vpc_id
  target_type = "instance"

  health_check {
    path                = var.tg_config["health_check_path"]
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    protocol            = var.tg_config["protocol"]
    port                = "traffic-port"
  }

  tags = merge(local.common_tags, {
    Name = "${var.tg_config["name"]}-${var.env}"
  })
}

# ========================================
# Application Load Balancer
# ========================================

resource "aws_lb" "clixx_alb" {
  name               = "${var.alb_config["name"]}-${var.env}"
  internal           = var.alb_config["internal"] == "true" ? true : false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.clixx_db_sg.id]
  subnets            = local.alb_subnet_ids

  enable_deletion_protection = var.env == "prod" ? true : false

  tags = merge(local.common_tags, {
    Name = "${var.alb_config["name"]}-${var.env}"
  })
}

#Apply listener to ALB
resource "aws_lb_listener" "clixx_http" {
  load_balancer_arn = aws_lb.clixx_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.clixx_tg.arn
  }

  tags = local.common_tags
}

# ========================================
# Auto Scaling Group
# ========================================

resource "aws_autoscaling_group" "clixx_asg" {
  name                      = "clixx-asg-${var.env}"
  min_size                  = var.asg_config["min_size"]
  max_size                  = var.asg_config["max_size"]
  desired_capacity          = var.asg_config["desired_capacity"]
  vpc_zone_identifier       = local.asg_subnet_ids
  health_check_type         = "ELB"
  health_check_grace_period = var.asg_config["health_check_grace_period"]
  target_group_arns         = [aws_lb_target_group.clixx_tg.arn]

  launch_template {
    id      = aws_launch_template.clixx_lt.id
    version = "$Latest"
  }

  dynamic "tag" {
    for_each = local.common_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}
# ========================================
# Route53 DNS Records
# ========================================

resource "aws_route53_record" "clixx_dns" {
  zone_id = data.aws_route53_zone.selected_zone[0].zone_id
  name    = "${var.subdomain}.${var.root_domain}"
  type    = "A"

  alias {
    name                   = aws_lb.clixx_alb.dns_name
    zone_id                = aws_lb.clixx_alb.zone_id
    evaluate_target_health = true
  }
}