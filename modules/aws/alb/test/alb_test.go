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

// TestALBRouting applies examples/basic (an internet-facing ALB in front of two web-server instances
// with path- and host-based rules), then asserts the ALB routes each request to the right backend.
// It always destroys via defer.
//
// Requires AWS credentials in the environment (and AWS_DEFAULT_REGION or the default us-east-1), and
// a default VPC in that region.
func TestALBRouting(t *testing.T) {
	t.Parallel()

	name := "alb-test-" + strings.ToLower(random.UniqueId())

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"name": name,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	dnsName := terraform.Output(t, terraformOptions, "alb_dns_name")
	assert.NotEmpty(t, dnsName)
	base := "http://" + dnsName

	// Path-based routing: /a/* -> app-a, /b/* -> app-b.
	requireEventuallyServedBy(t, base+"/a/", nil, "hello from app-a")
	requireEventuallyServedBy(t, base+"/b/", nil, "hello from app-b")

	// Host-based routing: Host: a.example.com -> app-a, Host: b.example.com -> app-b.
	requireEventuallyServedBy(t, base+"/", map[string]string{"Host": "a.example.com"}, "hello from app-a")
	requireEventuallyServedBy(t, base+"/", map[string]string{"Host": "b.example.com"}, "hello from app-b")

	// A request matching no rule gets the listener's fixed 404.
	requireEventuallyStatus(t, base+"/nowhere", 404)
}

// TestALBLambdaTarget applies examples/lambda (an internet-facing ALB whose default action forwards
// to a Lambda target), then asserts the ALB invokes the function and returns its response. It
// exercises the module's target_type = "lambda" path (lambda target group + invoke permission +
// registration). It always destroys via defer.
//
// Requires AWS credentials in the environment (and AWS_DEFAULT_REGION or the default us-east-1), and
// a default VPC in that region.
func TestALBLambdaTarget(t *testing.T) {
	t.Parallel()

	name := "alb-lambda-" + strings.ToLower(random.UniqueId())

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/lambda",
		Vars: map[string]interface{}{
			"name": name,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	dnsName := terraform.Output(t, terraformOptions, "alb_dns_name")
	assert.NotEmpty(t, dnsName)

	// The ALB forwards every request to the Lambda; expect its greeting once it's serving.
	requireEventuallyServedBy(t, "http://"+dnsName+"/", nil, "hello from lambda")
}

// requireEventuallyServedBy polls url until the response body contains want (targets need time to
// pass health checks and register), then asserts the serving backend.
func requireEventuallyServedBy(t *testing.T, url string, headers map[string]string, want string) {
	t.Helper()
	body := pollUntil(t, url, headers, func(status int, body string) bool {
		return status == 200 && strings.Contains(body, want)
	})
	assert.Contains(t, body, want, "unexpected backend for %s", url)
}

func requireEventuallyStatus(t *testing.T, url string, wantStatus int) {
	t.Helper()
	pollUntil(t, url, nil, func(status int, _ string) bool {
		return status == wantStatus
	})
}

func pollUntil(t *testing.T, url string, headers map[string]string, done func(status int, body string) bool) string {
	t.Helper()
	client := &http.Client{
		Timeout:   10 * time.Second,
		Transport: &http.Transport{TLSClientConfig: &tls.Config{InsecureSkipVerify: true}},
	}

	const maxAttempts = 40
	var lastBody string
	for i := 0; i < maxAttempts; i++ {
		req, err := http.NewRequest(http.MethodGet, url, nil)
		require.NoError(t, err)
		for k, v := range headers {
			if strings.EqualFold(k, "Host") {
				req.Host = v
				continue
			}
			req.Header.Set(k, v)
		}

		resp, err := client.Do(req)
		if err == nil {
			b, _ := io.ReadAll(resp.Body)
			resp.Body.Close()
			lastBody = string(b)
			if done(resp.StatusCode, lastBody) {
				return lastBody
			}
		}
		time.Sleep(15 * time.Second)
	}

	require.Fail(t, fmt.Sprintf("condition not met for %s after %d attempts; last body: %q", url, maxAttempts, lastBody))
	return lastBody
}
