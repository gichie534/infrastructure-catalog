package test

import (
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestCostDataExportBasic applies examples/basic (a dedicated lifecycle-managed bucket plus an hourly
// CUR 2.0 export), asserts on the outputs, and always destroys via defer.
//
// The export itself is free; the bucket costs S3 rates for whatever is delivered, and nothing is
// delivered within a test run (the first delivery takes roughly 24 hours). The real assertion here is
// that AWS ACCEPTED the export, which it only does when the delivery bucket policy is correct — the one
// thing this module exists to get right.
//
// Requires AWS credentials in the environment. The Data Exports control plane is us-east-1 only and the
// example pins that region itself.
func TestCostDataExportBasic(t *testing.T) {
	t.Parallel()

	unique := strings.ToLower(random.UniqueId())
	exportName := "cur2-test-" + unique
	bucketName := "cost-export-test-" + unique

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"export_name": exportName,
			"bucket_name": bucketName,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	arn := terraform.Output(t, terraformOptions, "export_arn")
	assert.True(t, strings.HasPrefix(arn, "arn:aws:bcm-data-exports:"),
		"expected a Data Exports ARN, got %q", arn)

	assert.Equal(t, "s3://"+bucketName+"/cur2", terraform.Output(t, terraformOptions, "s3_uri"))

	// Reaching this point at all is the assertion that matters for BILLING_VIEW_ARN: if the module failed
	// to send it, the apply above would have died on "Provider produced inconsistent result after apply".
	billingViewArn := terraform.Output(t, terraformOptions, "billing_view_arn")
	assert.Contains(t, billingViewArn, ":billingview/",
		"expected a resolved billing view ARN, got %q", billingViewArn)

	// The module builds the SQL from its curated column list when the consumer supplies none. A wrong
	// table name or an empty column list would produce a valid-looking export with the wrong schema.
	query := terraform.Output(t, terraformOptions, "query_statement")
	assert.True(t, strings.HasPrefix(query, "SELECT "), "expected a SELECT statement, got %q", query)
	assert.Contains(t, query, "FROM COST_AND_USAGE_REPORT")
	assert.Contains(t, query, "line_item_resource_id")
}
