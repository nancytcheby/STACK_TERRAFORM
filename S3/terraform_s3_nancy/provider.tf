# --- SOURCE account (us-east-1) ---
provider "aws" {
  region = var.region
}

# --- DESTINATION account (us-west-2) via AssumeRole into role "engineer" ---
provider "aws" {
  alias  = "replica"
  region = var.dest_region

  assume_role {
    role_arn     = "arn:aws:iam::083587468058:role/Engineer"
    session_name = "tf-replication-session"
  }
}