package test

import (
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestRDSPostgresBasic applies examples/basic (a VPC plus a publicly accessible PostgreSQL instance
// with SSL enforced), asserts on the endpoint outputs, and always destroys via defer.
//
// Requires AWS credentials in the environment (and AWS_DEFAULT_REGION or the default us-east-1).
// Creating an RDS instance is slow (several minutes); run against a sandbox account.
func TestRDSPostgresBasic(t *testing.T) {
	t.Parallel()

	// A strong, unique password satisfying RDS complexity rules.
	password := "Tf" + random.UniqueId() + "Pg9!"

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"master_password":     password,
			"allowed_cidr_blocks": []string{"203.0.113.10/32"},
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	address := terraform.Output(t, terraformOptions, "address")
	assert.Contains(t, address, ".rds.amazonaws.com")

	endpoint := terraform.Output(t, terraformOptions, "endpoint")
	assert.True(t, strings.HasSuffix(endpoint, ":5432"))

	dbName := terraform.Output(t, terraformOptions, "db_name")
	assert.Equal(t, "app", dbName)

	sgID := terraform.Output(t, terraformOptions, "security_group_id")
	assert.True(t, strings.HasPrefix(sgID, "sg-"))
}
