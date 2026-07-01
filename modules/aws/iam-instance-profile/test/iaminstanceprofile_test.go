package test

import (
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestIAMInstanceProfileBasic applies examples/basic (an EC2 role + instance profile with the SSM
// managed policy and an inline s3:ListAllMyBuckets grant), asserts on the outputs, and always
// destroys via defer.
//
// Requires AWS credentials in the environment (and AWS_DEFAULT_REGION or the default us-east-1).
func TestIAMInstanceProfileBasic(t *testing.T) {
	t.Parallel()

	unique := strings.ToLower(random.UniqueId())
	name := "iam-prof-test-" + unique

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"name": name,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	profileName := terraform.Output(t, terraformOptions, "instance_profile_name")
	assert.Equal(t, name, profileName)

	roleArn := terraform.Output(t, terraformOptions, "role_arn")
	assert.True(t, strings.HasPrefix(roleArn, "arn:aws:iam::"))
	assert.Contains(t, roleArn, ":role/"+name)
}
