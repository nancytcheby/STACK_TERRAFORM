########################
# Create VPC
########################

resource "aws_vpc" "clixx_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "clixx-vpc-${var.env}"
  })
}

########################
# Public Subnets (ALB & Bastion) - 450 hosts
########################

resource "aws_subnet" "public_subnet" {
  for_each = var.public_subnets

  vpc_id                  = aws_vpc.clixx_vpc.id
  cidr_block              = each.value
  availability_zone       = data.aws_availability_zones.available.names[index(keys(var.public_subnets), each.key)]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "clixx-${each.key}-${var.env}"
    Type = "Public"
  })
}

########################
# Private Subnets - Web/Application Servers (250 hosts)
########################

resource "aws_subnet" "private_web_subnet" {
  for_each = var.private_web_subnets

  vpc_id            = aws_vpc.clixx_vpc.id
  cidr_block        = each.value
  availability_zone = data.aws_availability_zones.available.names[index(keys(var.private_web_subnets), each.key)]

  tags = merge(local.common_tags, {
    Name = "clixx-${each.key}-${var.env}"
    Type = "Private-Web"
  })
}

########################
# Private Subnets - RDS MySQL Database (680 hosts)
########################

resource "aws_subnet" "private_rds_subnet" {
  for_each = var.private_rds_subnets

  vpc_id            = aws_vpc.clixx_vpc.id
  cidr_block        = each.value
  availability_zone = data.aws_availability_zones.available.names[index(keys(var.private_rds_subnets), each.key)]

  tags = merge(local.common_tags, {
    Name = "clixx-${each.key}-${var.env}"
    Type = "Private-RDS"
  })
}

########################
# Private Subnets - Oracle Database (254 hosts)
########################

resource "aws_subnet" "private_oracle_subnet" {
  for_each = var.private_oracle_subnets

  vpc_id            = aws_vpc.clixx_vpc.id
  cidr_block        = each.value
  availability_zone = data.aws_availability_zones.available.names[index(keys(var.private_oracle_subnets), each.key)]

  tags = merge(local.common_tags, {
    Name = "clixx-${each.key}-${var.env}"
    Type = "Private-Oracle"
  })
}

########################
# Private Subnets - Java Database (50 hosts)
########################

resource "aws_subnet" "private_java_db_subnet" {
  for_each = var.private_java_db_subnets

  vpc_id            = aws_vpc.clixx_vpc.id
  cidr_block        = each.value
  availability_zone = data.aws_availability_zones.available.names[index(keys(var.private_java_db_subnets), each.key)]

  tags = merge(local.common_tags, {
    Name = "clixx-${each.key}-${var.env}"
    Type = "Private-Java-DB"
  })
}

########################
# Private Subnets - Java Application Servers (50 hosts)
########################

resource "aws_subnet" "private_java_app_subnet" {
  for_each = var.private_java_app_subnets

  vpc_id            = aws_vpc.clixx_vpc.id
  cidr_block        = each.value
  availability_zone = data.aws_availability_zones.available.names[index(keys(var.private_java_app_subnets), each.key)]

  tags = merge(local.common_tags, {
    Name = "clixx-${each.key}-${var.env}"
    Type = "Private-Java-App"
  })
}

########################
# Internet Gateway
########################

resource "aws_internet_gateway" "clixx_igw" {
  vpc_id = aws_vpc.clixx_vpc.id

  tags = merge(local.common_tags, {
    Name = "clixx-igw-${var.env}"
  })
}

########################
# Elastic IP for NAT Gateway
########################

resource "aws_eip" "clixx_nat_eip" {
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "clixx-nat-eip-${var.env}"
  })

  depends_on = [aws_internet_gateway.clixx_igw]
}

########################
# NAT Gateway
########################

resource "aws_nat_gateway" "clixx_nat" {
  allocation_id = aws_eip.clixx_nat_eip.id
  subnet_id     = aws_subnet.public_subnet["public-1"].id

  tags = merge(local.common_tags, {
    Name = "clixx-nat-gateway-${var.env}"
  })

  depends_on = [aws_internet_gateway.clixx_igw]
}

########################
# Public Route Table
########################

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.clixx_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.clixx_igw.id
  }

  tags = merge(local.common_tags, {
    Name = "clixx-public-rt-${var.env}"
    Type = "Public"
  })
}

resource "aws_route_table_association" "public_rta" {
  for_each = aws_subnet.public_subnet

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public_rt.id
}

########################
# Private Route Table
########################

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.clixx_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.clixx_nat.id
  }

  tags = merge(local.common_tags, {
    Name = "clixx-private-rt-${var.env}"
    Type = "Private"
  })
}

# Associate all private subnets with private route table
resource "aws_route_table_association" "private_web_rta" {
  for_each = aws_subnet.private_web_subnet

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_rds_rta" {
  for_each = aws_subnet.private_rds_subnet

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_oracle_rta" {
  for_each = aws_subnet.private_oracle_subnet

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_java_db_rta" {
  for_each = aws_subnet.private_java_db_subnet

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_java_app_rta" {
  for_each = aws_subnet.private_java_app_subnet

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_rt.id
}

########################
# DB Subnet Groups
########################

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "clixx-rds-subnet-group-${var.env}"
  subnet_ids = [for subnet in aws_subnet.private_rds_subnet : subnet.id]

  tags = merge(local.common_tags, {
    Name = "clixx-rds-subnet-group-${var.env}"
  })
}

resource "aws_db_subnet_group" "oracle_subnet_group" {
  name       = "clixx-oracle-subnet-group-${var.env}"
  subnet_ids = [for subnet in aws_subnet.private_oracle_subnet : subnet.id]

  tags = merge(local.common_tags, {
    Name = "clixx-oracle-subnet-group-${var.env}"
  })
}

resource "aws_db_subnet_group" "java_db_subnet_group" {
  name       = "clixx-java-db-subnet-group-${var.env}"
  subnet_ids = [for subnet in aws_subnet.private_java_db_subnet : subnet.id]

  tags = merge(local.common_tags, {
    Name = "clixx-java-db-subnet-group-${var.env}"
  })
}

########################
# Network ACL
########################

resource "aws_network_acl" "clixx_public_nacl" {
  vpc_id     = aws_vpc.clixx_vpc.id
  subnet_ids = [for subnet in aws_subnet.public_subnet : subnet.id]

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