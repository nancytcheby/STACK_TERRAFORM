# -----------------------------------------
# Story: Create Launch Template for Clixx
# -----------------------------------------

resource "aws_launch_template" "clixx_lt" {
  name          = "clixx-launch-template-dev"
  image_id      = var.clixx_ami_id
  instance_type = var.clixx_instance_type

  iam_instance_profile {
    name = var.clixx_iam_instance_profile_name
  }

  key_name = var.clixx_key_name

  user_data = local.clixx_bootstrap_user_data_b64

  vpc_security_group_ids = [
    aws_security_group.clixx_db_sg.id
  ]

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "clixx-ec2-instance"
    }
  }
}
