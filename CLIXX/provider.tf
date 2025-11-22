provider "aws" {
  region = var.aws_region

  # Assume the Engineer role in the DEV account
  assume_role {
    role_arn     = var.engineer_role_arn
    session_name = "terraform-dev-session"
  }
}

# --- ADMIN / MANAGEMENT Account Provider (for Parameter Store) ---
provider "aws" {
  alias      = "admin"
  region     = var.PARAMETER_STORE_REGION
  access_key = var.AWS_ACCESS_KEY
  secret_key = var.AWS_SECRET_KEY
}
