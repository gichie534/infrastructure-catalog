# A single ECR repository to store an application's container images — the AWS analogue of a
# gcp/artifact-registry repo. Hardened-by-default: images are encrypted at rest (AES256) and scanned
# on push. The module owns only the repository and an optional lifecycle policy; who may push/pull is
# an IAM concern left to the consumer (e.g. a CI role from the oidc-federation module).

resource "aws_ecr_repository" "this" {
  name                 = var.name
  image_tag_mutability = var.image_tag_mutability
  force_delete         = var.force_delete

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = var.tags
}

# Optional: expire untagged images after a retention window so orphaned layers don't accumulate.
resource "aws_ecr_lifecycle_policy" "this" {
  count = var.untagged_image_expiry_days != null ? 1 : 0

  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images older than ${var.untagged_image_expiry_days} days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.untagged_image_expiry_days
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
