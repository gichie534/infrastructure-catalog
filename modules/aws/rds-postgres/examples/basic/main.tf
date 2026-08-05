provider "aws" {
  region = var.region
}

# A VPC to place the instance in. Public subnets so the example can reach the instance's public
# endpoint (a lab/migration-source shape); production would use private subnets and publicly_accessible=false.
module "vpc" {
  source = "../../../vpc"

  name = "example-rds-pg"
  azs  = ["${var.region}a", "${var.region}b"]

  public_subnet_cidrs  = ["10.0.0.0/20", "10.0.16.0/20"]
  private_subnet_cidrs = ["10.0.128.0/20", "10.0.144.0/20"]

  enable_nat_gateway = false
}

module "rds" {
  source = "../../"

  name       = "example-rds-pg"
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnet_ids

  db_name         = "app"
  master_username = "postgres"
  master_password = var.master_password

  publicly_accessible = true
  allowed_cidr_blocks = var.allowed_cidr_blocks

  parameters = [
    { name = "rds.force_ssl", value = "1" },
  ]

  # Examples/tests must be destroyable and cheap.
  deletion_protection = false
  skip_final_snapshot = true
}
