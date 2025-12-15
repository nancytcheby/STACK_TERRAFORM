provider "aws" {
  region = var.aws_region

  assume_role {
    role_arn     = "arn:aws:iam::${lookup(var.accounts, var.env)}:role/Engineer"
    session_name = "terraform-dev-session"
  }
}

provider "aws" {
  alias  = "admin"
  region = var.aws_region
  
  assume_role {
    role_arn     = var.admin_ssm_role_arn
    session_name = "terraform-admin-ssm-session"
  }
}
