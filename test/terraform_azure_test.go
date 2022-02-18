package test

import (
	"testing"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/environment"
	"github.com/stretchr/testify/assert"
	"fmt"
	"os"
)

func TestTerraformAzure(t *testing.T) {
	environment.RequireEnvVar(t, "AZURE_TEST_SUBSCRIPTION_ID")

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../azure",
		Vars: map[string]interface{}{
			"subscription_id": os.Getenv("AZURE_TEST_SUBSCRIPTION_ID"),
			"crate": "{heap_size_gb = 2, cluster_name = \"cratedb\", cluster_size = 2, ssl_enable = true}",
			"config": fmt.Sprintf("{project_name = \"%s\", environment = \"test\", owner = \"Crate.IO\", team = \"Test Team\", location = \"westeurope\"}", random.UniqueId()),
		},
	})

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	clusterUrl := terraform.Output(t, terraformOptions, "cratedb_application_url")
	clusterUrlIp := terraform.Output(t, terraformOptions, "cratedb_application_url_ip")
	cratedbUsername := terraform.Output(t, terraformOptions, "cratedb_username")
	cratedbPassword := terraform.Output(t, terraformOptions, "cratedb_password")

	// we don't validate the certificate explicitly, but check that the URL includes https
	assert.Regexp(t, "https.*$", clusterUrl)
	assert.Regexp(t, "https.*$", clusterUrlIp)

	// DNS resolution takes too long to propagate, hence we use the IP here instead
	body := RunCrateDBQuery(t, clusterUrlIp, cratedbUsername, cratedbPassword)

	assert.Equal(t, "[nodes]", fmt.Sprintf("%v", body["cols"]))
	assert.Equal(t, "[[2]]", fmt.Sprintf("%v", body["rows"]))
	assert.Equal(t, "1", fmt.Sprintf("%v", body["rowcount"]))
}
