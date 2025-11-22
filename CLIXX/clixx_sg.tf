# Security Group for Clixx Application 
resource "aws_security_group" "clixx_db_sg" {
  name        = "clixx-db-sg-dev"
  description = "Security group for Clixx application and database in Dev"
  vpc_id      = var.clixx_vpc_id

  tags = {
    Name = "clixx-db-sg-dev"
  }
}

# -------------------------
# Ingress Rules
# -------------------------

# Allow SSH (22)
resource "aws_vpc_security_group_ingress_rule" "clixx_ssh" {
  security_group_id = aws_security_group.clixx_db_sg.id

  cidr_ipv4   = var.clixx_db_allowed_cidr
  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"
}

# Allow HTTP (80)
resource "aws_vpc_security_group_ingress_rule" "clixx_http" {
  security_group_id = aws_security_group.clixx_db_sg.id

  cidr_ipv4   = var.clixx_db_allowed_cidr
  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
}

# Allow MySQL (3306)
resource "aws_vpc_security_group_ingress_rule" "clixx_mysql" {
  security_group_id = aws_security_group.clixx_db_sg.id

  cidr_ipv4   = var.clixx_db_allowed_cidr
  from_port   = 3306
  to_port     = 3306
  ip_protocol = "tcp"
}

# Allow NFS (2049) — required for EFS
resource "aws_vpc_security_group_ingress_rule" "clixx_nfs" {
  security_group_id = aws_security_group.clixx_db_sg.id

  cidr_ipv4   = var.clixx_db_allowed_cidr
  from_port   = 2049
  to_port     = 2049
  ip_protocol = "tcp"
}

# Allow all outbound IPv4 traffic
resource "aws_vpc_security_group_egress_rule" "clixx_all_egress" {
  security_group_id = aws_security_group.clixx_db_sg.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}


