# variable "cidr_vpc" {
#   description = "CIDR block for the VPC"
#   default     = "10.1.0.0/16"
# }
# variable "cidr_subnet" {
#   description = "CIDR block for the subnet"
#   default     = "10.1.0.0/24"
# }

variable "environment_tag" {
  default = "Learn"
}

variable "region" {
  default = "us-east-1"
}

variable "PATH_TO_PUBLIC_KEY" {
  default = "ses_key.pub"
}

variable "ami_name" {
  default = "ami-stack-14"
}
