package test

import (
	"crypto/tls"
	"fmt"
	"io"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestCloudFrontS3Routing applies examples/basic (three private S3 buckets — site/jpg/pdf — behind a
// CloudFront distribution using OAC), then asserts the distribution routes each request path to the
// right bucket: `/` -> site, `*.jpg` -> jpg bucket, `*.pdf` -> pdf bucket. It always destroys via
// defer.
//
// Requires AWS credentials in the environment (and AWS_DEFAULT_REGION or the default us-east-1).
func TestCloudFrontS3Routing(t *testing.T) {
	t.Parallel()

	namePrefix := "cf-s3-test-" + strings.ToLower(random.UniqueId())

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"name_prefix": namePrefix,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	domain := terraform.Output(t, terraformOptions, "domain_name")
	assert.NotEmpty(t, domain)
	base := "https://" + domain

	// Default behavior -> site bucket's index.html.
	requireEventuallyBody(t, base+"/", "hello from site")
	// *.jpg -> jpg bucket.
	requireEventuallyBody(t, base+"/photo.jpg", "fake-jpeg-bytes-for-the-routing-test")
	// *.pdf -> pdf bucket.
	requireEventuallyBody(t, base+"/report.pdf", "fake-pdf-bytes-for-the-routing-test")
}

// requireEventuallyBody polls url until it returns 200 with a body containing want. A freshly
// created distribution takes several minutes to deploy to the edge, so we retry generously.
func requireEventuallyBody(t *testing.T, url, want string) {
	t.Helper()
	client := &http.Client{
		Timeout:   15 * time.Second,
		Transport: &http.Transport{TLSClientConfig: &tls.Config{InsecureSkipVerify: true}},
	}

	const maxAttempts = 60
	var lastBody string
	var lastStatus int
	for i := 0; i < maxAttempts; i++ {
		resp, err := client.Get(url)
		if err == nil {
			b, _ := io.ReadAll(resp.Body)
			resp.Body.Close()
			lastBody = string(b)
			lastStatus = resp.StatusCode
			if resp.StatusCode == 200 && strings.Contains(lastBody, want) {
				return
			}
		}
		time.Sleep(15 * time.Second)
	}

	require.Fail(t, fmt.Sprintf("did not get %q from %s after %d attempts; last status %d body %q",
		want, url, maxAttempts, lastStatus, lastBody))
}
