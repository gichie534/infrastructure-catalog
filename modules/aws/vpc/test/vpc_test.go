package test

import (
	"fmt"
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestVPCBasic applies examples/basic against a sandbox account, asserts that the
// VPC, public/private subnets, and NAT gateway are created, and always destroys
// via defer.
//
// Requires AWS credentials in the environment (and optionally AWS_REGION) for a
// sandbox account.
func TestVPCBasic(t *testing.T) {
	t.Parallel()

	region := os.Getenv("AWS_REGION")
	if region == "" {
		region = "us-east-1"
	}

	name := fmt.Sprintf("test-vpc-%s", random.UniqueId())

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

	vpcID := terraform.Output(t, terraformOptions, "vpc_id")
	assert.NotEmpty(t, vpcID)

	publicSubnets := terraform.OutputList(t, terraformOptions, "public_subnet_ids")
	assert.Len(t, publicSubnets, 2, "expected one public subnet per AZ")

	privateSubnets := terraform.OutputList(t, terraformOptions, "private_subnet_ids")
	assert.Len(t, privateSubnets, 2, "expected one private subnet per AZ")

	// Single shared NAT gateway in the example.
	natGateways := terraform.OutputList(t, terraformOptions, "nat_gateway_ids")
	require.Len(t, natGateways, 1, "expected a single shared NAT gateway")
	assert.NotEmpty(t, natGateways[0])
}
