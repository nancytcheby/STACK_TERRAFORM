# Story 3: Create Target Group for Clixx

resource "aws_lb_target_group" "clixx_tg" {
  name     = var.clixx_tg_name
  port     = var.clixx_tg_port
  protocol = var.clixx_tg_protocol
  vpc_id   = var.clixx_vpc_id


  target_type = "instance"

  health_check {
    enabled             = true
    path                = var.clixx_tg_health_check_path
    port                = "traffic-port"
    protocol            = var.clixx_tg_protocol
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }

  tags = {
    Name = var.clixx_tg_name
  }
}
