package test

import (
	"fmt"
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/environment"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestTerraformAzure(t *testing.T) {
	t.Parallel()

	environment.RequireEnvVar(t, "AZURE_TEST_SUBSCRIPTION_ID")

	// UniqueId() can return an ID starting with a digit, but Azure requires a
	// letter as the first character, so we always prepend one.
	projectName := fmt.Sprintf("a%s", random.UniqueID())

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../azure",
		Vars: map[string]any{
			"subscription_id": os.Getenv("AZURE_TEST_SUBSCRIPTION_ID"),
			"crate":           "{heap_size_gb = 2, cluster_name = \"cratedb\", cluster_size = 2, ssl_enable = true}",
			"config":          fmt.Sprintf("{project_name = \"%s\", environment = \"test\", owner = \"Crate.IO\", team = \"Test Team\", location = \"westeurope\", zone = 1}", projectName),
		},
	})

	// Clean up resources with "terraform destroy" at the end of the test.
	defer terraform.DestroyContext(t, t.Context(), terraformOptions)

	terraform.InitAndApplyContext(t, t.Context(), terraformOptions)

	clusterUrl := terraform.OutputContext(t, t.Context(), terraformOptions, "cratedb_application_url")
	clusterUrlIp := terraform.OutputContext(t, t.Context(), terraformOptions, "cratedb_application_url_ip")
	cratedbUsername := terraform.OutputContext(t, t.Context(), terraformOptions, "cratedb_username")
	cratedbPassword := terraform.OutputContext(t, t.Context(), terraformOptions, "cratedb_password")

	// we don't validate the certificate explicitly, but check that the URL includes https
	assert.Regexp(t, "https.*$", clusterUrl)
	assert.Regexp(t, "https.*$", clusterUrlIp)

	// DNS resolution takes too long to propagate, hence we use the IP here instead
	body := RunCrateDBQuery(t, clusterUrlIp, cratedbUsername, cratedbPassword)

	assert.Equal(t, "[nodes]", fmt.Sprintf("%v", body["cols"]))
	assert.Equal(t, "[[2]]", fmt.Sprintf("%v", body["rows"]))
	assert.Equal(t, "1", fmt.Sprintf("%v", body["rowcount"]))
}
