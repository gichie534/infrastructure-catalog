provider "aws" {
  region = var.region
}

# Fixture dependencies. Plain resources rather than sibling modules so the example stays independent
# of other modules' versions — it is a test fixture, not a reference composition.
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "this" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = var.name
    Environment = "example"
  }
}

# Redshift Serverless requires at least three subnets spanning three Availability Zones.
resource "aws_subnet" "private" {
  count = 3

  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(aws_vpc.this.cidr_block, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name        = "${var.name}-private-${count.index}"
    Environment = "example"
  }
}

# Egress-only: nothing needs to reach the workgroup over the network because queries arrive via the
# Redshift Data API, which is a regional AWS endpoint authenticated with IAM.
resource "aws_security_group" "this" {
  name        = "${var.name}-workgroup"
  description = "Egress-only group for the ${var.name} Redshift Serverless workgroup"
  vpc_id      = aws_vpc.this.id

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.name}-workgroup"
    Environment = "example"
  }
}

resource "aws_s3_bucket" "source" {
  bucket        = var.bucket_name
  force_destroy = true

  tags = {
    Environment = "example"
  }
}

# A minimum-capacity private warehouse that can COPY from the fixture bucket.
module "redshift" {
  source = "../../"

  name          = var.name
  database_name = "labdb"

  subnet_ids         = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.this.id]

  base_capacity = 8
  max_capacity  = 8

  s3_read_bucket_arns = [aws_s3_bucket.source.arn]

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}
