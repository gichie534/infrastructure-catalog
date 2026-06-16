locals {
  # Index-aligned subnet definitions, keyed by AZ for stable for_each addressing.
  public_subnets = {
    for idx, az in var.azs : az => {
      az         = az
      cidr_block = var.public_subnet_cidrs[idx]
    }
  }

  private_subnets = {
    for idx, az in var.azs : az => {
      az         = az
      cidr_block = var.private_subnet_cidrs[idx]
    }
  }

  # NAT gateways: none, one shared, or one per AZ.
  nat_gateway_azs = var.enable_nat_gateway ? (var.single_nat_gateway ? [var.azs[0]] : var.azs) : []

  # AZ -> NAT gateway key a private subnet routes through (the shared one, or its own AZ's).
  private_nat_az = { for az in var.azs : az => var.single_nat_gateway ? var.azs[0] : az }
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = var.name })
}

# --- Subnets ---------------------------------------------------------------
resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.value.az
  cidr_block              = each.value.cidr_block
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    var.public_subnet_tags,
    { Name = "${var.name}-public-${each.value.az}" },
  )
}

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id            = aws_vpc.this.id
  availability_zone = each.value.az
  cidr_block        = each.value.cidr_block

  tags = merge(
    var.tags,
    var.private_subnet_tags,
    { Name = "${var.name}-private-${each.value.az}" },
  )
}

# --- NAT egress ------------------------------------------------------------
resource "aws_eip" "nat" {
  for_each = toset(local.nat_gateway_azs)

  domain = "vpc"

  tags = merge(var.tags, { Name = "${var.name}-nat-${each.value}" })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  for_each = toset(local.nat_gateway_azs)

  allocation_id = aws_eip.nat[each.value].id
  subnet_id     = aws_subnet.public[each.value].id

  tags = merge(var.tags, { Name = "${var.name}-nat-${each.value}" })

  depends_on = [aws_internet_gateway.this]
}

# --- Routing ---------------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-public" })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# One private route table per AZ so each can target its own NAT gateway.
resource "aws_route_table" "private" {
  for_each = local.private_subnets

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-private-${each.value.az}" })
}

resource "aws_route" "private_nat" {
  for_each = var.enable_nat_gateway ? local.private_subnets : {}

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[local.private_nat_az[each.key]].id
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}
