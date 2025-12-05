variable "aws_source_ami" {
  default = "amzn2-ami-hvm-2.0.20210326.0-x86_64-gp2"
}

variable "aws_instance_type" {
  default = "t2.small"
}

variable "ami_name" {
  default = "ami-stack-51"
}

variable "component" {
  default = "clixx"
}

variable "aws_accounts" {
  type = list(string)
  # default= ["577701061234","560089993749"]
  default= ["577701061234"]
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
    name                = "amzn2-ami-hvm-*-x86_64-gp2"
    virtualization-type = "hvm"
    root-device-type    = "ebs"
  }

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

