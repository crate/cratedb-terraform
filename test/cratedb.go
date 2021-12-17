package test

import (
	"encoding/json"
	"net/http"
	"github.com/hashicorp/go-retryablehttp"
	"fmt"
	"crypto/tls"
	"bytes"
	"io/ioutil"
	"time"
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
