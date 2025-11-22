locals {
  # Render the bootstrap script from template with values from SSM (admin account)
  clixx_bootstrap_user_data = templatefile("${path.module}/clixx_bootstrap.sh", {
    aws_region = var.aws_region

    db_host = data.aws_ssm_parameter.clixx_db_host.value
    db_name = data.aws_ssm_parameter.clixx_db_name.value
    db_user = data.aws_ssm_parameter.clixx_db_user.value
    db_pass = data.aws_ssm_parameter.clixx_db_password.value

    efs_id = data.aws_ssm_parameter.clixx_efs_id.value
    lb_dns = data.aws_ssm_parameter.clixx_lb_dns.value
  })

  clixx_bootstrap_user_data_b64 = base64encode(local.clixx_bootstrap_user_data)
}


