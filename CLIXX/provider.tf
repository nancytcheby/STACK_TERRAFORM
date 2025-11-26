provider "aws" {
  region = var.aws_region

  # Assume the Engineer role in the DEV account
  assume_role {
    role_arn     = "arn:aws:iam::${lookup(var.accounts, var.env)}:role/Engineer"
    session_name = "terraform-dev-session"
  }
}

# --- ADMIN / MANAGEMENT Account Provider (for Parameter Store) ---
provider "aws" {
  alias  = "admin"
  region = var.PARAMETER_STORE_REGION
  
  # Assume role in admin account for SSM Parameter Store
  assume_role {
    role_arn     = var.admin_ssm_role_arn
    session_name = "terraform-admin-ssm-session"
  }
}
