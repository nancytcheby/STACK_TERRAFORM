variable "aws_source_ami" {
  # ECS-optimized Amazon Linux 2023 AMI
  default = "al2023-ami-ecs-hvm-2023*-x86_64"
}

variable "aws_instance_type" {
  default = "t2.micro"
}

variable "ami_name" {
  default = "ecs-optimized-ami"
}

variable "component" {
  default = "clixx-ecs"
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

# Add timestamp for unique AMI names
locals {
  timestamp = formatdate("YYYYMMDD-HHmmss", timestamp())
}

data "amazon-ami" "source_ami" {
  most_recent = true
  owners      = ["amazon"]

  filters = {
    name                = var.aws_source_ami
  }
  region = var.aws_region
}
# ------------------------------------------------------------------------------------

source "amazon-ebs" "amazon_ebs" {
  # assume_role {
  #   role_arn     = "arn:aws:iam::818760291841:role/Engineer"
  # }
  ami_name                = "${var.ami_name}-${local.timestamp}"
  ami_regions             = var.ami_regions
  ami_users               = var.aws_accounts
  snapshot_users          = var.aws_accounts
  encrypt_boot            = false
  instance_type           = var.aws_instance_type

  launch_block_device_mappings {
    delete_on_termination = true
    device_name           = "/dev/xvda"
    encrypted             = false
    volume_size           = 30
    volume_type           = "gp2"
  }

  region                  = var.aws_region
  source_ami              = data.amazon-ami.source_ami.id
  ssh_pty                 = true
  ssh_timeout             = "5m"
  ssh_username            = "ec2-user"
}

build {
  sources = ["source.amazon-ebs.amazon_ebs"]

  provisioner "shell" {
    script = "../scripts/ecs_setup.sh"
  }
}

packer {
  required_plugins {
    amazon = {
      source = "github.com/hashicorp/amazon"
      version = "~> 1"
    }
  }
}
