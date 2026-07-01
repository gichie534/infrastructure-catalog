# A single EC2 instance — the minimal compute building block a consumer attaches an identity,
# network, and workload to.
#
# This module owns ONLY the instance. It does not resolve the AMI, create the VPC/subnet/security
# group, or define the IAM instance profile — those are the consumer's composition concern, passed
# in as inputs. That keeps the module region- and account-agnostic and reusable across labs.
#
# Security posture baked in (not parameterised, because weakening them is rarely intentional):
#   - IMDSv2 required (http_tokens = "required") so the metadata service — and the role credentials
#     it vends — can't be reached via the legacy unauthenticated IMDSv1 path.
#   - Root EBS volume encrypted at rest.

resource "aws_instance" "this" {
  ami           = var.ami_id
  instance_type = var.instance_type

  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = length(var.vpc_security_group_ids) > 0 ? var.vpc_security_group_ids : null
  associate_public_ip_address = var.associate_public_ip_address

  iam_instance_profile = var.iam_instance_profile

  user_data = var.user_data

  # Require IMDSv2 — token-authenticated metadata access only.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = true

    tags = merge(var.tags, { Name = var.name })
  }

  tags = merge(var.tags, { Name = var.name })
}
