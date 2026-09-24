package test

import (
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestRedshiftServerlessBasic applies examples/basic (a minimum-capacity private workgroup with a
// COPY role scoped to one bucket), asserts the namespace, workgroup, and owned COPY role are created
// and wired together, then always destroys via defer.
//
// This creates a real Redshift Serverless workgroup, which bills per RPU-second while queries run and
// takes several minutes to create and delete. Run it against a sandbox account.
//
// Requires AWS credentials in the environment (and AWS_DEFAULT_REGION or the default us-east-1).
func TestRedshiftServerlessBasic(t *testing.T) {
	t.Parallel()

	// Unique suffix so repeated/parallel runs don't collide. Redshift Serverless names are lowercase
	// letters, numbers, and hyphens only.
	unique := strings.ToLower(random.UniqueId())
	name := "redshift-test-" + unique

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"name":        name,
			"bucket_name": name + "-source",
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Namespace and workgroup both derive from the single `name` input.
	assert.Equal(t, name, terraform.Output(t, terraformOptions, "namespace_name"))
	assert.Equal(t, name, terraform.Output(t, terraformOptions, "workgroup_name"))
	assert.Equal(t, "labdb", terraform.Output(t, terraformOptions, "database_name"))

	workgroupARN := terraform.Output(t, terraformOptions, "workgroup_arn")
	assert.True(t, strings.HasPrefix(workgroupARN, "arn:aws:redshift-serverless:"))

	// The module owns its COPY role — a consumer should never have to supply one.
	copyRoleARN := terraform.Output(t, terraformOptions, "copy_role_arn")
	assert.True(t, strings.HasPrefix(copyRoleARN, "arn:aws:iam::"))
	assert.Contains(t, copyRoleARN, name+"-redshift-copy")

	// With no password supplied, Redshift manages the admin credentials in Secrets Manager.
	secretARN := terraform.Output(t, terraformOptions, "admin_password_secret_arn")
	assert.True(t, strings.HasPrefix(secretARN, "arn:aws:secretsmanager:"),
		"expected Redshift-managed admin credentials secret, got %q", secretARN)

	// The workgroup is in the VPC, so it has a private endpoint address.
	assert.NotEmpty(t, terraform.Output(t, terraformOptions, "endpoint_address"))
}
