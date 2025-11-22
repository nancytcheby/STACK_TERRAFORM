<<<<<<< HEAD
locals {
  clixx_bootstrap_user_data_b64 = base64encode(
    templatefile("${path.module}/clixx_bootstrap.sh", {
      aws_region = var.aws_region

      db_host = data.aws_ssm_parameter.clixx_db_host.value
      db_name = data.aws_ssm_parameter.clixx_db_name.value
      db_user = data.aws_ssm_parameter.clixx_db_user.value
      db_pass = data.aws_ssm_parameter.clixx_db_password.value

      efs_id = aws_efs_file_system.clixx_efs.id
      lb_dns = aws_lb.clixx_alb.dns_name
    })
  )
}
=======
# -----------------------------------------
# Story: Configure Bootstrap Script (user-data)
# -----------------------------------------

# Read the local bootstrap script from file
locals {
  clixx_bootstrap_user_data = file("${path.module}/clixx_bootstrap.sh")

  # Base64-encoded version for later use in Launch Template
  clixx_bootstrap_user_data_b64 = base64encode(local.clixx_bootstrap_user_data)
}
>>>>>>> dev
