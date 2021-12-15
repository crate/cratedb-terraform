# CrateDB Terraform Configurations
This repository contains a collection of Terraform configurations to deploy a CrateDB cluster to various environments.

Supported environments are:
* [aws](aws): Deployment of EC2 instances with a public-facing load balancer
* [azure](azure): Deployment of Azure VMs with a public-facing load balancer

## Development
[TFLint](https://github.com/terraform-linters/tflint) is configured to check the code for issues.
Inside the respective subdirectories, run `tflint --init` to initialize it, and `tflint` to run it. Different `.tflint.hcl` configurations exist for each subdirectory.

Before committing, please run `terraform fmt` to apply Terraform's standard configuration style consistently.

## Testing
Integration testing is done using [Terratest](https://terratest.gruntwork.io). The tests start a new cluster and perform a few very basic checks to verify if the deployment was successful.

Since the tests need details on the cloud environment to run in, set up corresponding environment variables, e.g. in a `.env` file:

```shell
AWS_TEST_VPC_ID=vpc-123
AWS_TEST_SSH_KEYPAIR=cratedb_terraform
AWS_TEST_SUBNET_IDS="[\"subnet-123\", \"subnet-124\"]"
AWS_TEST_AVAILABILITY_ZONES="[\"eu-central-1b\", \"eu-central-1a\"]"

AZURE_TEST_SUBSCRIPTION_ID=abc
```

To run the test, load the environment variables and pass them to `go test`:
```shell
cd test
source .env
AWS_TEST_VPC_ID=$AWS_TEST_VPC_ID \
AWS_TEST_SSH_KEYPAIR=$AWS_TEST_SSH_KEYPAIR \
AWS_TEST_SUBNET_IDS=$AWS_TEST_SUBNET_IDS \
AWS_TEST_AVAILABILITY_ZONES=$AWS_TEST_AVAILABILITY_ZONES \
go test
```
