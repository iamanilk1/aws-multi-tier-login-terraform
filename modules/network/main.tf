resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${var.project_name}-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags = { Name = "${var.project_name}-igw" }
}

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)
  vpc_id = aws_vpc.this.id
  cidr_block = var.public_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]
  map_public_ip_on_launch = true
  tags = { Name = "${var.project_name}-public-${count.index+1}" }
}

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)
  vpc_id = aws_vpc.this.id
  cidr_block = var.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]
  map_public_ip_on_launch = false
  tags = { Name = "${var.project_name}-private-${count.index+1}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags = { Name = "${var.project_name}-public-rt" }
}

resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_assoc" {
  count = length(aws_subnet.public)
  subnet_id = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# One Elastic IP and NAT Gateway per public subnet (per-AZ) for high availability
resource "aws_eip" "nat" {
  count = length(aws_subnet.public)
  domain = "vpc"
  tags = { Name = "${var.project_name}-nat-eip-${count.index+1}" }
}

resource "aws_nat_gateway" "this" {
  count         = length(aws_subnet.public)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags          = { Name = "${var.project_name}-nat-${count.index+1}" }
  depends_on    = [aws_internet_gateway.igw]
}

# Private route tables with default route via NAT in matching AZ index
resource "aws_route_table" "private" {
  count = length(aws_subnet.private)
  vpc_id = aws_vpc.this.id
  tags = { Name = "${var.project_name}-private-rt-${count.index+1}" }
}

resource "aws_route" "private_default" {
  count                  = length(aws_route_table.private)
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[count.index].id
}

resource "aws_route_table_association" "private_assoc" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# --- VPC Interface Endpoints for SSM (no-NAT SSM/Session Manager) ---
data "aws_region" "current" {}

# Security group for VPC endpoints: allow HTTPS from private subnets only
resource "aws_security_group" "ssm_vpce" {
  name        = "${var.project_name}-ssm-vpce-sg"
  description = "Allow HTTPS from private subnets to SSM interface endpoints"
  vpc_id      = aws_vpc.this.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-ssm-vpce-sg" }
}

# Ingress 443 from each private subnet CIDR
resource "aws_security_group_rule" "ssm_vpce_https_in" {
  for_each          = toset(var.private_subnet_cidrs)
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [each.value]
  security_group_id = aws_security_group.ssm_vpce.id
}

locals {
  ssm_services = [
    "ssm",
    "ssmmessages",
    "ec2messages",
  ]
}

resource "aws_vpc_endpoint" "ssm" {
  for_each             = toset(local.ssm_services)
  vpc_id               = aws_vpc.this.id
  service_name         = "com.amazonaws.${data.aws_region.current.name}.${each.value}"
  vpc_endpoint_type    = "Interface"
  private_dns_enabled  = true
  subnet_ids           = aws_subnet.private[*].id
  security_group_ids   = [aws_security_group.ssm_vpce.id]

  tags = { Name = "${var.project_name}-${each.value}-vpce" }
}

output "vpc_id" { value = aws_vpc.this.id }
output "public_subnet_ids" { value = aws_subnet.public[*].id }
output "private_subnet_ids" { value = aws_subnet.private[*].id }

# Expose SSM endpoint IDs (map service -> endpoint id)
output "ssm_vpc_endpoint_ids" {
  value = { for k, ep in aws_vpc_endpoint.ssm : k => ep.id }
}
