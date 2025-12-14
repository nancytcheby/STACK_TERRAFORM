variable "aws_source_ami" {
  default = "al2023-ami-2023*-x86_64"
}

variable "aws_instance_type" {
  default = "t2.micro"
}

variable "ami_name" {
  default = "ami-stack-14"
}

variable "component" {
  default = "clixx"
}

variable "aws_accounts" {
  type = list(string)
  default= ["818760291841","083587468058"]
}

variable "ami_regions" {
  type = list(string)
  default = ["us-east-1"]
}

variable "aws_region" {
  default = "us-east-1"
}

data "amazon-ami" "source_ami" {
  most_recent = true
  owners      = ["amazon"]

  filters = {
    name                = var.aws_source_ami
  }
  most_recent
  region = var.aws_region
}
# ------------------------------------------------------------------------------------

source "amazon-ebs" "amazon_ebs" {
  # assume_role {
  #   role_arn     = "arn:aws:iam::560089993749:role/Engineer"
  # }
  ami_name                = "${var.ami_name}"
  ami_regions             = "${var.ami_regions}"
  ami_users               = "${var.aws_accounts}"
  snapshot_users          = "${var.aws_accounts}"
  encrypt_boot            = false
  instance_type           = "${var.aws_instance_type}"

  launch_block_device_mappings {
    delete_on_termination = true
    device_name           = "/dev/xvda"
    encrypted             = false
    volume_size           = 10
    volume_type           = "gp2"
  }

  region                  = "${var.aws_region}"
  source_ami              = "${data.amazon-ami.source_ami.id}"
  ssh_pty                 = true
  ssh_timeout             = "5m"
  ssh_username            = "ec2-user"
}

build {
  sources = ["source.amazon-ebs.amazon_ebs"]

  provisioner "shell" {
    script = "../scripts/setup.sh"
  }
}

