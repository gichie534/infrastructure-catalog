# A single managed PostgreSQL instance on Amazon RDS — the source-of-truth relational store a
# consumer wires its application (and, in the migration lab, a migration source) to.
#
# The module owns the instance plus the three things one instance always needs: a subnet group
# (which AZs it lives in), a security group (who may reach it), and an optional parameter group
# (engine settings such as rds.force_ssl / rds.logical_replication). It deliberately does NOT own
# the VPC, the databases-beyond-the-initial-one, roles, or schemas — those are the consumer's
# composition and application concerns.
#
# publicly_accessible is off by default (production shape: private subnets, reachable only inside
# the VPC). A lab that needs to reach the instance from outside sets it true, places the instance in
# public subnets, and narrows allowed_cidr_blocks to a single operator address with TLS enforced.

locals {
  create_parameter_group = length(var.parameters) > 0
}

resource "aws_db_subnet_group" "this" {
  name       = var.name
  subnet_ids = var.subnet_ids
  tags       = merge(var.tags, { Name = var.name })
}

resource "aws_security_group" "this" {
  name        = "${var.name}-rds"
  description = "Ingress to the ${var.name} RDS PostgreSQL instance"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-rds" })
}

# One ingress rule per allowed CIDR (best-practice single-CIDR rule resources rather than a legacy
# inline block with a list).
resource "aws_vpc_security_group_ingress_rule" "postgres" {
  for_each = toset(var.allowed_cidr_blocks)

  security_group_id = aws_security_group.this.id
  description       = "PostgreSQL from ${each.value}"
  cidr_ipv4         = each.value
  from_port         = var.port
  to_port           = var.port
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.this.id
  description       = "All egress"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Parameter group only when the consumer supplies parameters (e.g. rds.force_ssl). create_before_destroy
# so parameter changes that force replacement don't deadlock on the instance still referencing it.
resource "aws_db_parameter_group" "this" {
  count = local.create_parameter_group ? 1 : 0

  name        = "${var.name}-pg"
  family      = var.parameter_group_family
  description = "Parameters for ${var.name}"

  dynamic "parameter" {
    for_each = var.parameters
    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = parameter.value.apply_method
    }
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_instance" "this" {
  identifier     = var.name
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage == 0 ? null : var.max_allocated_storage
  storage_type          = var.storage_type
  storage_encrypted     = var.storage_encrypted

  db_name  = var.db_name
  username = var.master_username
  password = var.master_password
  port     = var.port

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  publicly_accessible    = var.publicly_accessible
  multi_az               = var.multi_az

  parameter_group_name = local.create_parameter_group ? aws_db_parameter_group.this[0].name : null

  backup_retention_period    = var.backup_retention_period
  deletion_protection        = var.deletion_protection
  skip_final_snapshot        = var.skip_final_snapshot
  final_snapshot_identifier  = var.skip_final_snapshot ? null : "${var.name}-final"
  apply_immediately          = var.apply_immediately
  auto_minor_version_upgrade = var.auto_minor_version_upgrade

  performance_insights_enabled = var.performance_insights_enabled

  tags = merge(var.tags, { Name = var.name })
}
