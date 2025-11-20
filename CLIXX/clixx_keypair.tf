# Story: Create Key Pair for Clixx in Dev

# Generate a new private key locally
resource "tls_private_key" "clixx_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create an AWS EC2 key pair using the public key
resource "aws_key_pair" "clixx_key" {
  key_name   = var.clixx_key_name
  public_key = tls_private_key.clixx_key.public_key_openssh

  tags = {
    Name = var.clixx_key_name
  }
}

