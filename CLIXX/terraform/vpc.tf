########################
# Create VPC
########################

resource "aws_vpc" "clixx_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = format("clixx-vpc-%s", var.env)
  })
}

########################
# Create Public Subnets
########################

resource "aws_subnet" "clixx_public_subnet" {
  for_each = var.public_subnets

  vpc_id                  = aws_vpc.clixx_vpc.id
  cidr_block              = each.value
  availability_zone       = data.aws_availability_zones.available.names[index(keys(var.public_subnets), each.key)]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = format("clixx-%s-%s", each.key, var.env)
    Type = "Public"
  })
}

########################
# Create Private Subnets
########################

resource "aws_subnet" "clixx_private_subnet" {
  for_each = var.private_subnets

  vpc_id            = aws_vpc.clixx_vpc.id
  cidr_block        = each.value
  availability_zone = data.aws_availability_zones.available.names[index(keys(var.private_subnets), each.key)]

  tags = merge(local.common_tags, {
    Name = format("clixx-%s-%s", each.key, var.env)
    Type = "Private"
  })
}

########################
# Internet Gateway
########################

resource "aws_internet_gateway" "clixx_igw" {
  vpc_id = aws_vpc.clixx_vpc.id

  tags = merge(local.common_tags, {
    Name = format("clixx-igw-%s", var.env)
  })
}

########################
# Elastic IP for NAT Gateway
########################

resource "aws_eip" "clixx_nat_eip" {
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = format("clixx-nat-eip-%s", var.env)
  })

  depends_on = [aws_internet_gateway.clixx_igw]
}

########################
# NAT Gateway
########################

resource "aws_nat_gateway" "clixx_nat" {
  allocation_id = aws_eip.clixx_nat_eip.id
  subnet_id     = aws_subnet.clixx_public_subnet["public-1"].id

  tags = merge(local.common_tags, {
    Name = format("clixx-nat-gateway-%s", var.env)
  })

  depends_on = [aws_internet_gateway.clixx_igw]
}

########################
# Public Route Table
########################

resource "aws_route_table" "clixx_public_rt" {
  vpc_id = aws_vpc.clixx_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.clixx_igw.id
  }

  tags = merge(local.common_tags, {
    Name = format("clixx-public-rt-%s", var.env)
    Type = "Public"
  })
}

resource "aws_route_table_association" "clixx_public_rta" {
  for_each = aws_subnet.clixx_public_subnet

  subnet_id      = each.value.id
  route_table_id = aws_route_table.clixx_public_rt.id
}

########################
# Private Route Table
########################

resource "aws_route_table" "clixx_private_rt" {
  vpc_id = aws_vpc.clixx_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.clixx_nat.id
  }

  tags = merge(local.common_tags, {
    Name = format("clixx-private-rt-%s", var.env)
    Type = "Private"
  })
}

resource "aws_route_table_association" "clixx_private_rta" {
  for_each = aws_subnet.clixx_private_subnet

  subnet_id      = each.value.id
  route_table_id = aws_route_table.clixx_private_rt.id
}

########################
# DB Subnet Group
########################

resource "aws_db_subnet_group" "clixx_db_subnet_group" {
  name       = format("clixx-db-subnet-group-%s", var.env)
  subnet_ids = [for subnet in aws_subnet.clixx_private_subnet : subnet.id]

  tags = merge(local.common_tags, {
    Name = format("clixx-db-subnet-group-%s", var.env)
  })
}

########################
# Network ACL
########################

resource "aws_network_acl" "clixx_public_nacl" {
  vpc_id     = aws_vpc.clixx_vpc.id
  subnet_ids = [for subnet in aws_subnet.clixx_public_subnet : subnet.id]

  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 130
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = merge(local.common_tags, {
    Name = format("clixx-public-nacl-%s", var.env)
  })
}