# -----------------------------------------
# Story: Create Auto Scaling Group for Clixx
# -----------------------------------------

resource "aws_autoscaling_group" "clixx_asg" {
  name               = var.clixx_asg_name
  min_size           = var.clixx_asg_min_size
  max_size           = var.clixx_asg_max_size
  desired_capacity   = var.clixx_asg_desired_capacity
  vpc_zone_identifier = var.clixx_asg_subnet_ids

  health_check_type         = "ELB"
  health_check_grace_period = 800

  target_group_arns = [
    aws_lb_target_group.clixx_tg.arn
  ]

  launch_template {
    id      = aws_launch_template.clixx_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "clixx-ec2-dev"
    propagate_at_launch = true
  }

  tag {
    key                 = "App"
    value               = "Clixx"
    propagate_at_launch = true
  }

  tag {
    key                 = "Env"
    value               = "dev"
    propagate_at_launch = true
  }
}