locals {
  clixx_bootstrap_user_data_b64 = base64encode(
    file("${path.module}/clixx_bootstrap.sh")
  )
}