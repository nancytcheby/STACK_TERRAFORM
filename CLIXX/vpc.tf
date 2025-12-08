########################
# Create  VPC
########################

resource "aws_vpc" "clixx_vpc" {
  count = var.create_custom_vpc ? 1 : 0

  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = format("clixx-vpc-%s", var.env)
  })
}

########################
# Create Public Subnets (2)
########################

resource "aws_subnet" "clixx_public_subnet" {
  count = var.create_custom_vpc ? 2 : 0

  vpc_id                  = aws_vpc.clixx_vpc[0].id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = format("clixx-public-subnet-%d-%s", count.index + 1, var.env)
    Type = "Public"
  })
}

########################
# Create Private Subnets (2)
########################

resource "aws_subnet" "clixx_private_subnet" {
  count = var.create_custom_vpc ? 2 : 0

  vpc_id            = aws_vpc.clixx_vpc[0].id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(local.common_tags, {
    Name = format("clixx-private-subnet-%d-%s", count.index + 1, var.env)
    Type = "Private"
  })
}

########################
# Internet Gateway
########################

resource "aws_internet_gateway" "clixx_igw" {
  count = var.create_custom_vpc ? 1 : 0

  vpc_id = aws_vpc.clixx_vpc[0].id

  tags = merge(local.common_tags, {
    Name = format("clixx-igw-%s", var.env)
  })
}

########################
# Elastic IP for NAT Gateway
########################

resource "aws_eip" "clixx_nat_eip" {
  count = var.create_custom_vpc ? 1 : 0

  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = format("clixx-nat-eip-%s", var.env)
  })

  depends_on = [aws_internet_gateway.clixx_igw]
}

########################
# NAT Gateway (in first public subnet)
########################

resource "aws_nat_gateway" "clixx_nat" {
  count = var.create_custom_vpc ? 1 : 0

  allocation_id = aws_eip.clixx_nat_eip[0].id
  subnet_id     = aws_subnet.clixx_public_subnet[0].id

  tags = merge(local.common_tags, {
    Name = format("clixx-nat-gateway-%s", var.env)
  })

  depends_on = [aws_internet_gateway.clixx_igw]
}

########################
# Public Route Table
########################

resource "aws_route_table" "clixx_public_rt" {
  count = var.create_custom_vpc ? 1 : 0

  vpc_id = aws_vpc.clixx_vpc[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.clixx_igw[0].id
  }

  tags = merge(local.common_tags, {
    Name = format("clixx-public-rt-%s", var.env)
    Type = "Public"
  })
}

# Associate public subnets with public route table
resource "aws_route_table_association" "clixx_public_rta" {
  count = var.create_custom_vpc ? 2 : 0

  subnet_id      = aws_subnet.clixx_public_subnet[count.index].id
  route_table_id = aws_route_table.clixx_public_rt[0].id
}

########################
# Private Route Table
########################

resource "aws_route_table" "clixx_private_rt" {
  count = var.create_custom_vpc ? 1 : 0

  vpc_id = aws_vpc.clixx_vpc[0].id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.clixx_nat[0].id
  }

  tags = merge(local.common_tags, {
    Name = format("clixx-private-rt-%s", var.env)
    Type = "Private"
  })
}

# Associate private subnets with private route table
resource "aws_route_table_association" "clixx_private_rta" {
  count = var.create_custom_vpc ? 2 : 0

  subnet_id      = aws_subnet.clixx_private_subnet[count.index].id
  route_table_id = aws_route_table.clixx_private_rt[0].id
}

########################
# DB Subnet Group for RDS
########################

resource "aws_db_subnet_group" "clixx_db_subnet_group" {
  count = var.create_custom_vpc ? 1 : 0

  name       = format("clixx-db-subnet-group-%s", var.env)
  subnet_ids = aws_subnet.clixx_private_subnet[*].id

  tags = merge(local.common_tags, {
    Name = format("clixx-db-subnet-group-%s", var.env)
  })
}

########################
# Network ACL
########################

resource "aws_network_acl" "clixx_public_nacl" {
  count = var.create_custom_vpc ? 1 : 0

  vpc_id     = aws_vpc.clixx_vpc[0].id
  subnet_ids = aws_subnet.clixx_public_subnet[*].id

  # Allow HTTP inbound
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  # Allow HTTPS inbound
  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # Allow ephemeral ports inbound (for return traffic)
  ingress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Allow SSH from anywhere (consider restricting this in production)
  ingress {
    protocol   = "tcp"
    rule_no    = 130
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

  # Allow all outbound traffic
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