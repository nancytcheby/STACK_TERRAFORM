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
  key_name   = var.clixx_key_name
  public_key = tls_private_key.clixx_key.public_key_openssh

  tags = merge(local.common_tags, {
    Name = var.clixx_key_name
  })
}

# Security group is defined in clixx_sg.tf

# ========================================
# EFS File System
# ========================================

resource "aws_efs_file_system" "clixx_efs" {
  creation_token = try(format("clixx-efs-%s", var.env), var.clixx_efs_name, "clixx-efs-dev")

  performance_mode                = try("generalPurpose", "generalPurpose")
  throughput_mode                 = try("provisioned", "bursting")
  provisioned_throughput_in_mibps = try(100, null)

  encrypted = true

  tags = merge(local.common_tags, {
    Name = try(var.clixx_efs_name, "clixx-efs-${var.env}")
  })

  lifecycle {
    create_before_destroy = true
    prevent_destroy       = false
  }
}

# EFS Mount Targets
resource "aws_efs_mount_target" "clixx_efs_mt" {
  count          = length(local.efs_subnet_ids)
  file_system_id = aws_efs_file_system.clixx_efs.id
  subnet_id      = local.efs_subnet_ids[count.index]

  security_groups = [aws_security_group.clixx_db_sg.id]

  lifecycle {
    create_before_destroy = true
  }
}

# ========================================
# RDS Database
# ========================================

# Random suffix for DB identifier to avoid conflicts
resource "random_id" "db_suffix" {
  byte_length = 4
  keepers = {
    timestamp = timestamp()
    snapshot_identifier = var.clixx_db_snapshot_identifier 
  }
}

resource "aws_db_instance" "clixx_db" {
  count = var.clixx_db_snapshot_identifier != "" ? 1 : 0

  identifier           = try(format("clixx-db-%s-%s", var.env, random_id.db_suffix.hex), "clixx-db-dev-${random_id.db_suffix.hex}")
  snapshot_identifier  = try(var.clixx_db_snapshot_identifier, null)
  instance_class       = try(var.clixx_db_instance_class, "db.t3.micro")
  db_subnet_group_name = local.db_subnet_group_name

  vpc_security_group_ids = [aws_security_group.clixx_db_sg.id]

  username = try(var.clixx_db_username)
  password = try(var.clixx_db_password)

  backup_retention_period = try(7, 0)
  backup_window           = try("03:00-04:00", null)
  maintenance_window      = try("sun:04:00-sun:05:00", null)

  skip_final_snapshot       = try(var.env == "prod" ? false : true, true)
  final_snapshot_identifier = try(var.env == "prod" ? format("clixx-db-%s-final-snapshot-%s", var.env, formatdate("YYYY-MM-DD-hhmm", timestamp())) : null, null)

  deletion_protection = try(var.env == "prod" ? true : false, false)

  tags = merge(local.common_tags, {
    Name = try(format("clixx-db-%s", var.env), "clixx-db-dev")
  })

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      password,
      final_snapshot_identifier
    ]
  }

  depends_on = [aws_security_group.clixx_db_sg]
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

# Database password 
resource "aws_ssm_parameter" "clixx_db_password" {
  provider  = aws.admin
  name      = "/database/password"
  type      = "SecureString"
#   value     = var.clixx_db_password
    value     = var.clixx_db_password
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

# WordPress Configuration Content (created in dev account)
resource "aws_ssm_parameter" "clixx_wp_config" {
  name      = "/clixx/wp-config-content"
  type      = "SecureString"
  value = templatefile("${path.module}/wp-config-template.php", {
    db_name = aws_ssm_parameter.clixx_db_name.value
    db_user = var.clixx_db_username
    db_pass = var.clixx_db_password
    db_host = length(aws_db_instance.clixx_db) > 0 ? aws_db_instance.clixx_db[0].address : ""
  })
  overwrite = true
  
  tags = local.common_tags
}

# ========================================
# Bootstrap Configuration
# ========================================

locals {
  # bootstrap script - essential WordPress setup 
  clixx_bootstrap_user_data = templatefile("${path.module}/clixx_bootstrap_minimal.sh", {
    aws_region = var.aws_region
    db_host    = length(aws_db_instance.clixx_db) > 0 ? aws_db_instance.clixx_db[0].address : ""
    db_name    = aws_ssm_parameter.clixx_db_name.value
    db_user    = var.clixx_db_username
    db_pass    = var.clixx_db_password
    efs_id     = aws_efs_file_system.clixx_efs.dns_name
    lb_dns     = aws_lb.clixx_alb.dns_name
  })

  clixx_bootstrap_user_data_b64 = base64encode(local.clixx_bootstrap_user_data)
}

# ========================================
# Launch Template
# ========================================

resource "aws_launch_template" "clixx_lt" {
  name_prefix   = try(format("clixx-lt-%s-", var.env), "clixx-lt-dev-")
  # Use custom AMI if provided, otherwise use ec2_config ami_id
  image_id      = var.custom_ami_id != "" ? var.custom_ami_id : try(var.ec2_config.ami_id, "ami-0dda28e5df2d25176")
  instance_type = try(var.ec2_config.instance_type, "t4g.micro")

  key_name = aws_key_pair.clixx_key.key_name

  user_data = local.clixx_bootstrap_user_data_b64

  vpc_security_group_ids = [aws_security_group.clixx_db_sg.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_access_profile.name
  }

  monitoring {
    enabled = try(var.ec2_config.enable_detailed_monitoring, true)
  }

  ebs_optimized = try(var.ec2_config.ebs_optimized, false)

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = try(format("clixx-ec2-%s", var.env), "clixx-ec2-dev")
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(local.common_tags, {
      Name = try(format("clixx-ec2-volume-%s", var.env), "clixx-ec2-volume-dev")
    })
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_iam_instance_profile.ec2_access_profile,
    aws_security_group.clixx_db_sg
  ]
}

# ========================================
# Target Group
# ========================================

resource "aws_lb_target_group" "clixx_tg" {
  name     = try(var.clixx_tg_name, format("clixx-tg-%s", var.env))
  port     = try(var.clixx_tg_port, 80)
  protocol = try(var.clixx_tg_protocol, "HTTP")
  vpc_id   = local.vpc_id

  target_type = "instance"

  health_check {
    path                = try(var.clixx_tg_health_check_path, "/health.php")
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    protocol            = try(var.clixx_tg_protocol, "HTTP")
    port                = "traffic-port"
  }

  tags = merge(local.common_tags, {
    Name = try(var.clixx_tg_name, format("clixx-tg-%s", var.env))
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ========================================
# Application Load Balancer
# ========================================

resource "aws_lb" "clixx_alb" {
  name               = try(var.clixx_alb_name, format("clixx-alb-%s", var.env))
  internal           = try(var.clixx_alb_internal, false)
  load_balancer_type = "application"

  security_groups = [aws_security_group.clixx_db_sg.id]
  subnets = local.alb_subnet_ids

  enable_deletion_protection = try(var.env == "prod" ? true : false, false)

  tags = merge(local.common_tags, {
    Name = try(var.clixx_alb_name, format("clixx-alb-%s", var.env))
  })

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_security_group.clixx_db_sg]
}

# ALB HTTP Listener
resource "aws_lb_listener" "clixx_http" {
  load_balancer_arn = aws_lb.clixx_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.clixx_tg.arn
  }

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

# ========================================
# Auto Scaling Group
# ========================================

resource "aws_autoscaling_group" "clixx_asg" {
  name                = try(var.ec2_config.asg_name, format("clixx-asg-%s", var.env))
  min_size            = try(var.ec2_config.asg_min_size, 1)
  max_size            = try(var.ec2_config.asg_max_size, 1)
  desired_capacity    = try(var.ec2_config.asg_desired_capacity, 1)
  vpc_zone_identifier = local.asg_subnet_ids

  health_check_type         = try(var.ec2_config.health_check_type, "ELB")
  health_check_grace_period = try(var.ec2_config.health_check_grace_period, 1200)

  target_group_arns = [aws_lb_target_group.clixx_tg.arn]

  launch_template {
    id      = aws_launch_template.clixx_lt.id
    version = "$Latest"
  }

  # Dynamic tags from locals.common_tags
  dynamic "tag" {
    for_each = local.common_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_capacity]
  }

  depends_on = [
    aws_db_instance.clixx_db,
    aws_lb_target_group.clixx_tg,
    aws_launch_template.clixx_lt
  ]
}

# ========================================
# Route53 DNS Records
# ========================================

resource "aws_route53_record" "clixx_dns" {
  count = (var.clixx_subdomain != "" && var.clixx_base_domain != "") ? 1 : 0

  zone_id = try(data.aws_route53_zone.selected_zone[0].zone_id, "")
  name    = try(format("%s.%s", var.clixx_subdomain, var.clixx_base_domain), "")
  type    = "A"

  alias {
    name                   = aws_lb.clixx_alb.dns_name
    zone_id                = aws_lb.clixx_alb.zone_id
    evaluate_target_health = true
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_lb.clixx_alb]
}