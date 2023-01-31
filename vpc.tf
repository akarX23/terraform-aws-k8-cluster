resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"

  enable_dns_hostnames = true

  tags = {
    Name = var.vpc_name
  }
}

resource "aws_subnet" "public_sn" {

  depends_on = [
    aws_vpc.vpc
  ]

  vpc_id = aws_vpc.vpc.id

  cidr_block = "10.0.1.0/24"

  availability_zone = "${var.aws_region}a"

  map_public_ip_on_launch = true

  tags = {
    Name = var.public_subnet_name
  }
}

resource "aws_subnet" "private_sn" {

  depends_on = [
    aws_vpc.vpc
  ]

  vpc_id = aws_vpc.vpc.id

  cidr_block = "10.0.2.0/24"

  availability_zone = "${var.aws_region}b"

  map_public_ip_on_launch = false

  tags = {
    Name = var.private_subnet_name
  }
}

resource "aws_internet_gateway" "IG" {
  depends_on = [
    aws_vpc.vpc,
    aws_subnet.public_sn,
    aws_subnet.private_sn
  ]

  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = var.internet_gateway_name
  }
}

resource "aws_route_table" "ig-route-table" {
  depends_on = [
    aws_vpc.vpc,
    aws_internet_gateway.IG
  ]

  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IG.id
  }

  tags = {
    Name = var.ig_route_table_name
  }
}

resource "aws_route_table_association" "IG-RT-association" {

  depends_on = [
    aws_vpc.vpc,
    aws_internet_gateway.IG,
    aws_route_table.ig-route-table,
    aws_subnet.public_sn
  ]

  subnet_id      = aws_subnet.public_sn.id
  route_table_id = aws_route_table.ig-route-table.id
}

resource "aws_eip" "NAT-Gateway-EIP" {
  vpc = true
}

resource "aws_nat_gateway" "NAT-Gateway" {
  depends_on = [
    aws_eip.NAT-Gateway-EIP,
  ]

  # Allocating the Elastic IP to the NAT Gateway!
  allocation_id = aws_eip.NAT-Gateway-EIP.id

  # Associating it in the Public Subnet!
  subnet_id = aws_subnet.public_sn.id
  tags = {
    Name = var.nat_gateway_name
  }
}

resource "aws_route_table" "NAT-Gateway-RT" {
  depends_on = [
    aws_nat_gateway.NAT-Gateway,
  ]

  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.NAT-Gateway.id
  }

  tags = {
    Name = var.nat_route_table_name
  }
}

resource "aws_route_table_association" "NAT-Gateway-RT-Association" {
  depends_on = [
    aws_route_table.NAT-Gateway-RT,
  ]

  #  Private Subnet ID for adding this route table to the DHCP server of Private subnet!
  subnet_id = aws_subnet.private_sn.id

  # Route Table ID
  route_table_id = aws_route_table.NAT-Gateway-RT.id
}

resource "aws_security_group" "security-group" {
  depends_on = [
    aws_vpc.vpc,
  ]

  description = "Common Security Group for all k8 and bastion instances"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    description      = "All Traffic"
  }

  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "TCP"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    description      = "All Traffic"
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    description      = "All Traffic"
  }

  tags = {
    "Name" = var.security_group_name
  }
}
