package test

import (
	"testing"
	"encoding/json"
	"net/http"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/hashicorp/go-retryablehttp"
	"fmt"
	"crypto/tls"
	"bytes"
	"io/ioutil"
	"time"
	"os"
)

func RunCrateDBQuery(clusterUrl string, username string, password string) (map[string]interface{}, error) {
	var requestBody = []byte(`{"stmt":"SELECT COUNT(*) AS nodes FROM sys.nodes"}`)
	req, err := retryablehttp.NewRequest("POST", fmt.Sprintf("%s/_sql", clusterUrl), bytes.NewBuffer(requestBody))
	req.SetBasicAuth(username, password)
	req.Header.Add("Content-Type", "application/json")
	req.Close = true

	client := retryablehttp.NewClient()
	client.HTTPClient.Transport = &http.Transport{
		TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
	}
	client.RetryWaitMin = 10 * time.Second
	client.RetryMax = 20

	response, err := client.Do(req)
	if err != nil {
		return nil, err
	}

	defer response.Body.Close()
	bodyJson, err := ioutil.ReadAll(response.Body)
	if err != nil {
		return nil, err
	}

	var body map[string]interface{};
	json.Unmarshal([]byte(bodyJson), &body)

	return body, nil
}

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
