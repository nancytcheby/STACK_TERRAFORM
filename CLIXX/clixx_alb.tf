# -----------------------------------------
# Story: Create Application Load Balancer
# -----------------------------------------

# Application Load Balancer for Clixx
resource "aws_lb" "clixx_alb" {
  name               = var.clixx_alb_name
  internal           = var.clixx_alb_internal
  load_balancer_type = "application"

  security_groups = [
    aws_security_group.clixx_db_sg.id
  ]

  subnets = var.clixx_alb_subnet_ids

  tags = {
    Name = var.clixx_alb_name
  }
}

# HTTP listener on port 80 forwarding to the Clixx Target Group
resource "aws_lb_listener" "clixx_http" {
  load_balancer_arn = aws_lb.clixx_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.clixx_tg.arn
  }
}
