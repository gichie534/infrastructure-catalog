package test

import (
	"fmt"
	"os"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestEKSBasic applies examples/basic (which composes the vpc module and an EKS
// cluster with a managed node group) against a sandbox account, asserts on cluster
// outputs, and always destroys via defer.
//
// Requires AWS credentials in the environment (and optionally AWS_REGION) for a
// sandbox account.
func TestEKSBasic(t *testing.T) {
	t.Parallel()

	region := os.Getenv("AWS_REGION")
	if region == "" {
		region = "us-east-1"
	}

	name := fmt.Sprintf("test-eks-%s", strings.ToLower(random.UniqueId()))

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"region": region,
			"name":   name,
			"azs":    []string{region + "a", region + "b"},
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	clusterName := terraform.Output(t, terraformOptions, "cluster_name")
	assert.Equal(t, name, clusterName)

	endpoint := terraform.Output(t, terraformOptions, "cluster_endpoint")
	assert.Contains(t, endpoint, "https://")

	nodeGroups := terraform.OutputMap(t, terraformOptions, "node_group_names")
	require.Contains(t, nodeGroups, "default")
	assert.Equal(t, name+"-default", nodeGroups["default"])

	addons := terraform.OutputMap(t, terraformOptions, "addon_versions")
	require.Contains(t, addons, "eks-pod-identity-agent")
	assert.NotEmpty(t, addons["eks-pod-identity-agent"])
}
