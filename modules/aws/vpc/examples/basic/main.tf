provider "aws" {
  region = var.region
}

module "vpc" {
  source = "../../"

  name       = var.name
  cidr_block = "10.0.0.0/16"

  azs                  = var.azs
  public_subnet_cidrs  = ["10.0.0.0/20", "10.0.16.0/20"]
  private_subnet_cidrs = ["10.0.128.0/20", "10.0.144.0/20"]

  # Single shared NAT gateway keeps the example cheap; flip single_nat_gateway
  # to false for per-AZ HA.
  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}
