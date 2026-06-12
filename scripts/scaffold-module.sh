#!/usr/bin/env bash
# Scaffold a new Terraform module following the #new-module playbook.
#
# Usage: scaffold-module.sh <provider>/<name> [modules-dir]
#   e.g. scaffold-module.sh gcp/vpc modules
#
# Creates modules/<provider>/<name>/ with main.tf, variables.tf, outputs.tf,
# versions.tf (correct provider in required_providers), README.md with
# terraform-docs markers, examples/basic/, and a Terratest skeleton under test/.
set -euo pipefail

MODULE="${1:-}"
MODULES_DIR="${2:-modules}"

if [ -z "$MODULE" ]; then
  echo "ERROR: MODULE is required, e.g. task new MODULE=gcp/vpc" >&2
  exit 1
fi

# Expect exactly <provider>/<name>.
provider="${MODULE%%/*}"
name="${MODULE#*/}"
if [ "$provider" = "$MODULE" ] || [ -z "$provider" ] || [ -z "$name" ] || [ "$name" != "${name#*/}" ]; then
  echo "ERROR: MODULE must be '<provider>/<name>' (e.g. gcp/vpc), got '$MODULE'" >&2
  exit 1
fi

# Map provider -> required_providers block details.
case "$provider" in
  aws)
    prov_local="aws"
    prov_source="hashicorp/aws"
    prov_version=">= 5.0"
    tags_var="tags"
    tags_kind="Tags"
    ;;
  gcp)
    prov_local="google"
    prov_source="hashicorp/google"
    prov_version=">= 5.0"
    tags_var="labels"
    tags_kind="Labels"
    ;;
  *)
    echo "ERROR: unsupported provider '$provider' (expected aws or gcp)" >&2
    exit 1
    ;;
esac

dest="$MODULES_DIR/$provider/$name"
if [ -e "$dest" ]; then
  echo "ERROR: target directory already exists: $dest" >&2
  exit 1
fi

mkdir -p "$dest/examples/basic" "$dest/test"

# Go test package name: sanitise the module name into an identifier.
pkg=$(printf '%s' "$name" | tr -cd 'a-z0-9' )
[ -n "$pkg" ] || pkg="module"

# --- versions.tf -----------------------------------------------------------
cat > "$dest/versions.tf" <<EOF
terraform {
  required_version = ">= 1.0"

  required_providers {
    $prov_local = {
      source  = "$prov_source"
      version = "$prov_version"
    }
  }
}
EOF

# --- variables.tf ----------------------------------------------------------
cat > "$dest/variables.tf" <<EOF
variable "name" {
  description = "Name applied to the $name resources."
  type        = string
  nullable    = false
}

variable "$tags_var" {
  description = "$tags_kind to apply to every taggable resource."
  type        = map(string)
  default     = {}
}
EOF

# --- main.tf ---------------------------------------------------------------
cat > "$dest/main.tf" <<EOF
# $provider/$name module.
#
# Implement the resources here using only the inputs declared in variables.tf.
# No provider/backend/remote_state blocks, and no hardcoded region/account.
EOF

# --- outputs.tf ------------------------------------------------------------
# Quoted heredoc: the example is literal Terraform, not shell-expanded.
cat > "$dest/outputs.tf" <<'EOF'
# Export every identifier a consumer needs to wire this module downstream.
# Example:
# output "id" {
#   description = "The ID of the created resource."
#   value       = resource_type.this.id
# }
EOF

# --- README.md (with terraform-docs markers) -------------------------------
cat > "$dest/README.md" <<EOF
# $provider/$name

One-line description of what this module provisions.

## Usage

\`\`\`hcl
module "$pkg" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/$provider/$name?ref=vX.Y.Z"

  name = "example"
}
\`\`\`

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
EOF

# --- examples/basic/main.tf ------------------------------------------------
if [ "$provider" = "gcp" ]; then
cat > "$dest/examples/basic/main.tf" <<EOF
provider "google" {
  project = var.project_id
  region  = "us-central1"
}

variable "project_id" {
  description = "GCP project to create resources in."
  type        = string
}

module "$pkg" {
  source = "../../"

  name = "example-$name"
}
EOF
else
cat > "$dest/examples/basic/main.tf" <<EOF
provider "aws" {
  region = "us-east-1"
}

module "$pkg" {
  source = "../../"

  name = "example-$name"
}
EOF
fi

# --- test/<name>_test.go ---------------------------------------------------
test_file="$dest/test/${pkg}_test.go"
cat > "$test_file" <<EOF
package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// Test${pkg}Basic applies examples/basic, asserts on outputs, and always
// destroys via defer. Fill in real assertions as the module takes shape.
func Test${pkg}Basic(t *testing.T) {
	t.Parallel()

	uniqueID := random.UniqueId()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"name": "test-" + uniqueID,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// TODO: assert on terraform.Output(t, terraformOptions, "<output>")
	assert.NotNil(t, terraformOptions)
}
EOF

echo "Scaffolded module at $dest"
echo "Next:"
echo "  1. Define the contract in variables.tf / outputs.tf, then implement main.tf."
echo "  2. Make examples/basic apply cleanly."
echo "  3. task docs   # generate README tables"
echo "  4. task check  # cost-free gate"
echo "  5. task test MODULE=$MODULE   # against a sandbox account"
