package test

import (
	"crypto/tls"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/testing"
	"github.com/stretchr/testify/assert"
	"time"
)

func RunCrateDBQuery(t testing.TestingT, clusterUrl string, username string, password string) map[string]interface{} {
	credentials := fmt.Sprintf("%s:%s", username, password)

	requestHeaders := map[string]string{
		"Content-Type":  "application/json",
		"Authorization": fmt.Sprintf("Basic %s", base64.StdEncoding.EncodeToString([]byte(credentials))),
	}

	bodyJson := http_helper.HTTPDoWithRetry(
		t,
		"POST",
		fmt.Sprintf("%s/_sql", clusterUrl),
		[]byte(`{"stmt":"SELECT COUNT(*) AS nodes FROM sys.nodes"}`),
		requestHeaders,
		200,           // expected status code
		20,            // retries
		time.Second*5, // sleep between retries
		&tls.Config{InsecureSkipVerify: true},
	)

	var body map[string]interface{}
	err := json.Unmarshal([]byte(bodyJson), &body)
	assert.Nil(t, err)

	return body
}
