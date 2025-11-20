# -----------------------------------------
# Story: Configure Bootstrap Script (user-data)
# -----------------------------------------

# Read the local bootstrap script from file
locals {
  clixx_bootstrap_user_data = file("${path.module}/clixx_bootstrap.sh")

  # Base64-encoded version for later use in Launch Template
  clixx_bootstrap_user_data_b64 = base64encode(local.clixx_bootstrap_user_data)
}