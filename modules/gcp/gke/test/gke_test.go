package test

import (
	"fmt"
	"os"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/shell"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestGKEBasic applies examples/basic (which composes the vpc module and a regional
// Autopilot cluster) against a sandbox project, asserts on cluster outputs, and always
// destroys via defer.
//
// Requires GOOGLE_PROJECT (or GCP_PROJECT) to point at a sandbox project with
// application-default credentials available.
func TestGKEBasic(t *testing.T) {
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

	clusterName := terraform.Output(t, terraformOptions, "cluster_name")
	assert.Equal(t, "example-autopilot", clusterName)

	clusterID := terraform.Output(t, terraformOptions, "cluster_id")
	assert.NotEmpty(t, clusterID)

	endpoint := terraform.Output(t, terraformOptions, "endpoint")
	assert.NotEmpty(t, endpoint)

	networkSelfLink := terraform.Output(t, terraformOptions, "network_self_link")
	assert.Contains(t, networkSelfLink, "example-gke")

	assertNodeServiceAccount(t, terraformOptions, projectID, clusterName)
}

// assertNodeServiceAccount checks the part of the contract that, when wrong, produces a cluster that
// reports RUNNING with zero nodes and every pod Pending: the nodes must run as a service account
// that holds roles/container.defaultNodeServiceAccount on the project.
//
// Node count is deliberately NOT asserted. Autopilot scales to zero when nothing is scheduled, so a
// freshly applied cluster with no workloads legitimately has no nodes and the assertion would be
// flaky. The role grant is the condition GKE documents as the requirement, so that is what is
// asserted.
func assertNodeServiceAccount(t *testing.T, opts *terraform.Options, projectID, clusterName string) {
	email := terraform.Output(t, opts, "node_service_account_email")
	require.Equal(t,
		fmt.Sprintf("%s-nodes@%s.iam.gserviceaccount.com", clusterName, projectID),
		email,
		"the module should derive the node service account id from the cluster name")

	region := opts.Vars["region"]
	if region == nil || region == "" {
		region = "us-central1"
	}

	// The cluster must actually be configured to use it. On Autopilot this lives under the
	// autoprovisioning defaults, not under a node pool.
	configured := gcloud(t, "container", "clusters", "describe", clusterName,
		"--project", projectID,
		"--region", fmt.Sprintf("%v", region),
		"--format", "value(autoscaling.autoprovisioningNodePoolDefaults.serviceAccount)")
	assert.Equal(t, email, configured, "cluster nodes should run as the dedicated service account")

	// And it must hold the role, or nodes boot and fail to register.
	policy := gcloud(t, "projects", "get-iam-policy", projectID,
		"--flatten", "bindings[].members",
		"--filter", fmt.Sprintf("bindings.members:serviceAccount:%s", email),
		"--format", "value(bindings.role)")
	assert.Contains(t, strings.Split(policy, "\n"), "roles/container.defaultNodeServiceAccount",
		"the node service account must hold roles/container.defaultNodeServiceAccount, otherwise the "+
			"control plane deletes every node it creates and all pods stay Pending")
}

// gcloud runs a gcloud command and returns its trimmed stdout. These tests already require
// application-default credentials, so shelling out adds no new prerequisite and avoids pulling the
// Google API client libraries in for a couple of assertions.
func gcloud(t *testing.T, args ...string) string {
	out := shell.RunCommandAndGetStdOut(t, shell.Command{
		Command: "gcloud",
		Args:    args,
	})
	return strings.TrimSpace(out)
}
