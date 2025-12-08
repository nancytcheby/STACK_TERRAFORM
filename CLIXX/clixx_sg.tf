# Security Group for Clixx Application with Dynamic Rules
resource "aws_security_group" "clixx_db_sg" {
  name_prefix = "clixx-sg-${var.env}-"
  description = "Security group for Clixx application and database in ${try(var.env, "dev")}"
  vpc_id      = local.vpc_id

  # Dynamic ingress rules - HTTP, SSH, MySQL/Aurora, NFS
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "MySQL access"
  }

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "NFS for EFS"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    try(local.common_tags, {}),
    {
      Name = try("clixx-sg-${var.env}", "clixx-sg-dev")
    }
  )

}


