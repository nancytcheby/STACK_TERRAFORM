# terraform {
#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       version = "~> 3.26.0"
#     }
#   }
#   required_version = "~> 0.14.5"
# }

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.74.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# resource "aws_vpc" "vpc" {
#   cidr_block           = var.cidr_vpc
#   enable_dns_support   = true
#   enable_dns_hostnames = true
# }

# resource "aws_internet_gateway" "igw" {
#   vpc_id = aws_vpc.vpc.id
# }

# resource "aws_subnet" "subnet_public" {
#   vpc_id     = aws_vpc.vpc.id
#   cidr_block = var.cidr_subnet
# }

# resource "aws_route_table" "rtb_public" {
#   vpc_id = aws_vpc.vpc.id

#   route {
#     cidr_block = "0.0.0.0/0"
#     gateway_id = aws_internet_gateway.igw.id
#   }
# }

# resource "aws_route_table_association" "rta_subnet_public" {
#   subnet_id      = aws_subnet.subnet_public.id
#   route_table_id = aws_route_table.rtb_public.id
# }

# Automatically get the default VPC
data "aws_vpc" "default" {
  default = true
}

# Automatically get all default subnets in the VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# SSH key pair
resource "aws_key_pair" "Stack_KP" {
  key_name   = "stackkp"
  public_key = file(var.PATH_TO_PUBLIC_KEY)
}

# Security Group
resource "aws_security_group" "sg_22_80" {
  name   = "sg_22"
  vpc_id = data.aws_vpc.default.id   

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Always use newest AMI created by Jenkins/Packer
data "aws_ami" "stack" {
  owners      = ["self"]
  most_recent = true

  filter {
    name   = "name"
    values = ["ami-stack-14"]
  }
}

# Application EC2 instance
resource "aws_instance" "application_server" {
  ami                         = data.aws_ami.stack.id
  instance_type               = "t2.micro"
  subnet_id                   = data.aws_subnets.default.ids[0]   
  vpc_security_group_ids      = [aws_security_group.sg_22_80.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.Stack_KP.key_name

  tags = {
    Name = "Test_Instance"
  }
}

# Output public IP
output "public_ip" {
  value = aws_instance.application_server.public_ip
}

output "instance_id" {
  value = aws_instance.application_server.id
}

