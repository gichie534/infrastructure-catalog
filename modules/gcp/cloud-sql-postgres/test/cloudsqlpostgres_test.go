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

	// The availability / replica inputs are opt-in: a consumer that sets none of them must still get
	// the cheap single-zone shape. This guards the defaults, which is the part of the HA contract that
	// can regress silently — turning them on in a test would provision a synchronous standby and a
	// second-region instance on every run.
	assert.Equal(t, "ZONAL", terraform.Output(t, terraformOptions, "availability_type"),
		"availability_type must default to ZONAL so existing consumers are unaffected")
	assert.Empty(t, terraform.OutputMap(t, terraformOptions, "replica_instance_names"),
		"no read replicas should exist unless read_replicas is set")
}

// TestCloudSQLPostgresHAValidation asserts the input validation on the durability inputs. It runs
// `terraform plan`, not `apply`: variable validation is evaluated at plan time (`terraform validate`
// skips it entirely) and is reported before the provider is configured, so these cases create no
// resources and need no credentials.
//
// The HA/replica behaviour itself would need a REGIONAL instance plus a second-region replica —
// ~30 minutes and three database instances per run — so it is verified by hand, not here. What this
// test protects is the part that regresses silently: a typo'd availability_type or an out-of-range
// retention window reaching a production plan.
func TestCloudSQLPostgresHAValidation(t *testing.T) {
	// Deliberately NOT parallel with itself: every case plans in the same module directory, and
	// concurrent plans there contend on the local state lock.
	cases := []struct {
		name        string
		vars        map[string]interface{}
		wantErrPart string
	}{
		{
			name:        "rejects an unknown availability_type",
			vars:        map[string]interface{}{"availability_type": "MULTI_REGION"},
			wantErrPart: "availability_type must be either ZONAL or REGIONAL",
		},
		{
			name:        "rejects a disk smaller than the Cloud SQL minimum",
			vars:        map[string]interface{}{"disk_size": 5},
			wantErrPart: "disk_size must be at least 10 GB",
		},
		{
			name: "rejects a non-UTC-HH:MM backup start_time",
			vars: map[string]interface{}{
				"backup_configuration": map[string]interface{}{"start_time": "2am"},
			},
			wantErrPart: "start_time must be a UTC time in HH:MM",
		},
		{
			name: "rejects transaction log retention outside 1-35 days",
			vars: map[string]interface{}{
				"backup_configuration": map[string]interface{}{"transaction_log_retention_days": 60},
			},
			wantErrPart: "transaction_log_retention_days must be between 1 and 35",
		},
		{
			name: "rejects a maintenance_window day outside 1-7",
			vars: map[string]interface{}{
				"maintenance_window": map[string]interface{}{"day": 8, "hour": 3},
			},
			wantErrPart: "maintenance_window.day must be between 1 (Monday) and 7 (Sunday)",
		},
		{
			name: "rejects a replica key that would build an invalid instance name",
			vars: map[string]interface{}{
				"read_replicas": map[string]interface{}{
					"DR-": map[string]interface{}{"region": "europe-west1"},
				},
			},
			wantErrPart: "read_replicas key must be lowercase",
		},
	}

	for _, tc := range cases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			vars := map[string]interface{}{
				"name":       "validation-pg",
				"project_id": "example-project",
				"region":     "europe-west9",
				"network":    "projects/example-project/global/networks/example",
			}
			for k, v := range tc.vars {
				vars[k] = v
			}

			_, err := terraform.InitAndPlanE(t, &terraform.Options{
				TerraformDir: "../",
				Vars:         vars,
				NoColor:      true,
			})
			require.Error(t, err, "expected the variable validation to reject this input")
			assert.Contains(t, err.Error(), tc.wantErrPart)
		})
	}
}
