#!/bin/bash

if [ "$1" != "aws" ] && [ "$1" != "azure" ]
then
  echo "Usage: $0 <aws|azure>"
  exit
fi

if [[ "$1" = "aws" ]]; then
  test_class="TestTerraformAws"
else
  test_class="TestTerraformAzure"
fi

source .env

AWS_TEST_REGION=$AWS_TEST_REGION \
AWS_TEST_VPC_ID=$AWS_TEST_VPC_ID \
AWS_TEST_SSH_KEYPAIR=$AWS_TEST_SSH_KEYPAIR \
AWS_TEST_SUBNET_IDS=$AWS_TEST_SUBNET_IDS \
AWS_TEST_AVAILABILITY_ZONES=$AWS_TEST_AVAILABILITY_ZONES \
AZURE_TEST_SUBSCRIPTION_ID=$AZURE_TEST_SUBSCRIPTION_ID \
go test -timeout 30m -run "${test_class}"
