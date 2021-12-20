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
	"errors"
	"context"
)

func RunCrateDBQuery(clusterUrl string, username string, password string) (map[string]interface{}, error) {
	client := retryablehttp.NewClient()
	client.HTTPClient.Transport = &http.Transport{
		TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
	}
	client.RetryWaitMin = 5 * time.Minute
	client.RetryMax = 40
	client.CheckRetry = func(ctx context.Context, resp *http.Response, err error) (bool, error) {
		ok, e := retryablehttp.DefaultRetryPolicy(ctx, resp, err)
		// During bootstrapping, there is a point in time when the cluster is up but the admin user not created yet.
		// Therefore, retry on timeout and unauthorized access
		if !ok && (resp.StatusCode == http.StatusRequestTimeout || resp.StatusCode == http.StatusUnauthorized) {
				return true, nil
		}
		return ok, e
	}

	var requestBody = []byte(`{"stmt":"SELECT COUNT(*) AS nodes FROM sys.nodes"}`)
	req, err := retryablehttp.NewRequest("POST", fmt.Sprintf("%s/_sql", clusterUrl), bytes.NewBuffer(requestBody))
	if err != nil {
		return nil, err
	}
	req.SetBasicAuth(username, password)
	req.Header.Add("Content-Type", "application/json")
	req.Close = true

	response, err := client.Do(req)
	defer response.Body.Close()

	if err != nil {
		return nil, err
	}

	if response.StatusCode != http.StatusOK {
		return nil, errors.New(fmt.Sprintf("Received HTTP status code %v", response.StatusCode))
	}

	bodyJson, err := ioutil.ReadAll(response.Body)
	if err != nil {
		return nil, err
	}

	var body map[string]interface{};
	json.Unmarshal([]byte(bodyJson), &body)

	return body, nil
}
