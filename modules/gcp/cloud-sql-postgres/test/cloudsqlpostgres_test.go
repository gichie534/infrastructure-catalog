package test

import (
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestCloudSQLPostgresBasic applies examples/basic (VPC with PSA, a workload GSA, a
// private-IP PostgreSQL instance with IAM auth, and the Workload Identity wiring),
// asserts on outputs, and always destroys via defer.
//
// Requires GOOGLE_PROJECT (or GCP_PROJECT) to point at a sandbox project with
// application-default credentials available.
func TestCloudSQLPostgresBasic(t *testing.T) {
	t.Parallel()

	projectID := os.Getenv("GOOGLE_PROJECT")
	if projectID == "" {
		projectID = os.Getenv("GCP_PROJECT")
	}
	require.NotEmpty(t, projectID, "set GOOGLE_PROJECT (or GCP_PROJECT) to a sandbox project to run this test")

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"project_id": projectID,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	connName := terraform.Output(t, terraformOptions, "instance_connection_name")
	assert.Contains(t, connName, projectID)

	privateIP := terraform.Output(t, terraformOptions, "private_ip_address")
	assert.NotEmpty(t, privateIP)

	dbName := terraform.Output(t, terraformOptions, "database_name")
	assert.Equal(t, "app", dbName)

	// The workload GSA must be registered as an IAM database user.
	iamUsers := terraform.OutputMap(t, terraformOptions, "iam_user_names")
	gsaEmail := terraform.Output(t, terraformOptions, "workload_service_account_email")
	username, ok := iamUsers[gsaEmail]
	require.True(t, ok, "workload GSA should be registered as an IAM database user")
	assert.NotEmpty(t, username)
}
