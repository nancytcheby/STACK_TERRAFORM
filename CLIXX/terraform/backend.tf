terraform {
  backend "s3" {
    bucket       = "nancy-stack-states"  
    key          = "clixx/terraform.tfstate"     
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}