# -----------------------------------------
# Launch Template for Clixx EC2 instances
# -----------------------------------------

resource "aws_launch_template" "clixx_lt" {
  name_prefix   = "clixx-lt-dev-"
  image_id      = var.clixx_ami_id
  instance_type = var.clixx_instance_type
  key_name      = var.clixx_key_name

  # Use the bootstrap user data (base64-encoded) defined in locals
  user_data = local.clixx_bootstrap_user_data_b64

  vpc_security_group_ids = [
    aws_security_group.clixx_db_sg.id
  ]

  iam_instance_profile {
    name = var.clixx_iam_instance_profile_name
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "clixx-ec2-dev"
      App  = "Clixx"
      Env  = "dev"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name = "clixx-ec2-volume-dev"
      App  = "Clixx"
      Env  = "dev"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}
