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

func TestTerraformAws(t *testing.T) {
	environment.RequireEnvVar(t, "AWS_TEST_REGION")
	environment.RequireEnvVar(t, "AWS_TEST_VPC_ID")
	environment.RequireEnvVar(t, "AWS_TEST_SSH_KEYPAIR")
	environment.RequireEnvVar(t, "AWS_TEST_SUBNET_IDS")
	environment.RequireEnvVar(t, "AWS_TEST_AVAILABILITY_ZONES")

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../aws",
		Vars: map[string]interface{}{
			"region": os.Getenv("AWS_TEST_REGION"),
			"vpc_id": os.Getenv("AWS_TEST_VPC_ID"),
			"ssh_keypair": os.Getenv("AWS_TEST_SSH_KEYPAIR"),
			"subnet_ids": os.Getenv("AWS_TEST_SUBNET_IDS"),
			"availability_zones": os.Getenv("AWS_TEST_AVAILABILITY_ZONES"),
			"config": fmt.Sprintf("{project_name = \"%s\", environment = \"test\", owner = \"Crate.IO\", team = \"Test Team\"}", random.UniqueId()),
			"crate": "{heap_size_gb = 2, cluster_name = \"cratedb\", cluster_size = 2, ssl_enable = true}",
		},
	})

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	clusterUrl := terraform.Output(t, terraformOptions, "cratedb_application_url")
	cratedbUsername := terraform.Output(t, terraformOptions, "cratedb_username")
	cratedbPassword := terraform.Output(t, terraformOptions, "cratedb_password")

	// we don't validate the certificate explicitly, but check that the URL includes https
	assert.Regexp(t, "https.*$", clusterUrl)

	body := RunCrateDBQuery(t, clusterUrl, cratedbUsername, cratedbPassword)

	assert.Equal(t, "[nodes]", fmt.Sprintf("%v", body["cols"]))
	assert.Equal(t, "[[2]]", fmt.Sprintf("%v", body["rows"]))
	assert.Equal(t, "1", fmt.Sprintf("%v", body["rowcount"]))
}
