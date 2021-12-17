package test

import (
	"testing"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"fmt"
	"os"
)

func TestTerraformAws(t *testing.T) {
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../aws",
		Vars: map[string]interface{}{
			"vpc_id": os.Getenv("AWS_TEST_VPC_ID"),
			"ssh_keypair": os.Getenv("AWS_TEST_SSH_KEYPAIR"),
			"subnet_ids": os.Getenv("AWS_TEST_SUBNET_IDS"),
			"availability_zones": os.Getenv("AWS_TEST_AVAILABILITY_ZONES"),
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

	body, err := RunCrateDBQuery(clusterUrl, cratedbUsername, cratedbPassword)
	if assert.NoError(t, err) {
		assert.Equal(t, "[nodes]", fmt.Sprintf("%v", body["cols"]))
		assert.Equal(t, "[[2]]", fmt.Sprintf("%v", body["rows"]))
		assert.Equal(t, "1", fmt.Sprintf("%v", body["rowcount"]))
	}
}
