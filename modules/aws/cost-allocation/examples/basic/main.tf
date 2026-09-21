# Cost Explorer is a global service reachable only through its us-east-1 endpoint.
provider "aws" {
  region = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix for the example cost category name, so repeat runs do not collide."
  type        = string
}

variable "active_cost_allocation_tag_keys" {
  description = <<-EOT
    Tag keys to activate. Empty by default on purpose: AWS only accepts keys it has already discovered
    on a real resource (up to 24 hours after first use), so a hardcoded key would make this example
    fail on a fresh account.
  EOT
  type        = list(string)
  default     = []
}

# A cost category that maps spend to an owning team, with a named bucket for everything unmatched.
#
# The two rule shapes are both here on purpose. A tag rule is precise but only as reliable as your
# tagging discipline; a dimension rule (account, service, region) matches regardless of whether anybody
# remembered to tag. `default_value` makes the gap between them measurable instead of invisible.
module "cost_allocation" {
  source = "../../"

  active_cost_allocation_tag_keys = var.active_cost_allocation_tag_keys

  cost_categories = {
    "${var.name_prefix}-team" = {
      default_value = "unallocated"

      rules = [
        {
          value      = "platform"
          tag_key    = "team"
          tag_values = ["platform"]
        },
        {
          value      = "data"
          tag_key    = "team"
          tag_values = ["data"]
        },
        {
          # Untaggable, account-wide charges — support, tax, refunds — never carry a team tag, so match
          # them on the record type instead of leaving them to fall through.
          value            = "shared-charges"
          dimension_key    = "RECORD_TYPE"
          dimension_values = ["Tax", "Support"]
        },
      ]
    }
  }

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}

output "cost_category_names" {
  description = "Names of the created cost categories."
  value       = module.cost_allocation.cost_category_names
}

output "cost_category_arns" {
  description = "Map of cost category name to ARN."
  value       = module.cost_allocation.cost_category_arns
}

output "active_cost_allocation_tag_keys" {
  description = "Tag keys activated as cost allocation tags."
  value       = module.cost_allocation.active_cost_allocation_tag_keys
}
