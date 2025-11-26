# --------------------
# SSM Parameters (in ADMIN account)
# --------------------

data "aws_ssm_parameter" "clixx_db_host" {
  provider = aws.admin
  name     = "/database/host"
}

data "aws_ssm_parameter" "clixx_db_name" {
  provider = aws.admin
  name     = "/database/name"
}

data "aws_ssm_parameter" "clixx_db_user" {
  provider = aws.admin
  name     = "/database/user"
}

data "aws_ssm_parameter" "clixx_db_password" {
  provider        = aws.admin
  name            = "/database/password"
}

data "aws_ssm_parameter" "clixx_efs_id" {
  provider = aws.admin
  name     = "/efs_id"
}

data "aws_ssm_parameter" "clixx_lb_dns" {
  provider = aws.admin
  name     = "/Clixx_dns"
}
