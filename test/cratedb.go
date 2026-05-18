package test

import (
	"crypto/tls"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"testing"
	"time"

	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/stretchr/testify/assert"
)

func RunCrateDBQuery(t *testing.T, clusterUrl string, username string, password string) map[string]any {
	credentials := fmt.Sprintf("%s:%s", username, password)

	requestHeaders := map[string]string{
		"Content-Type":  "application/json",
		"Authorization": fmt.Sprintf("Basic %s", base64.StdEncoding.EncodeToString([]byte(credentials))),
	}

	bodyJson := http_helper.HTTPDoWithRetryContext(
		t,
		t.Context(),
		"POST",
		fmt.Sprintf("%s/_sql", clusterUrl),
		[]byte(`{"stmt":"SELECT COUNT(*) AS nodes FROM sys.nodes"}`),
		requestHeaders,
		200,           // expected status code
		30,            // retries
		time.Second*5, // sleep between retries
		&tls.Config{InsecureSkipVerify: true},
	)

	var body map[string]any
	err := json.Unmarshal([]byte(bodyJson), &body)
	assert.Nil(t, err)

	return body
}
