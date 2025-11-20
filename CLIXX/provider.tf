provider "aws" {
  region = var.aws_region

  # Assume the Engineer role in the DEV account
  assume_role {
    role_arn     = var.engineer_role_arn
    session_name = "terraform-dev-session"
  }
}