provider "aws" {
  region = var.region
}

# A public hosted zone with a couple of records. force_destroy so the test tears down cleanly.
module "route53" {
  source = "../../"

  name          = var.zone_name
  visibility    = "public"
  comment       = "route53 module basic example"
  force_destroy = true

  records = {
    "api" = { type = "A", records = ["203.0.113.10"] }
    "www" = { type = "CNAME", ttl = 600, records = ["api.${var.zone_name}"] }
  }

  tags = {
    Example = "basic"
  }
}
