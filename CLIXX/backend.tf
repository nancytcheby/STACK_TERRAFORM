terraform {
  backend "s3" {
    bucket       = "nancy-stack-states"
    key          = "terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}