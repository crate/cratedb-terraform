# crate-terraform
This repository contains a collection of Terraform configurations to deploy a CrateDB cluster to various environments.

Supported environments are:
* [aws](aws): Deployment of EC2 instances with a public-facing load balancer
* [azure](azure): Deployment of Azure VMs with a public-facing load balancer

## Development
[TFLint](https://github.com/terraform-linters/tflint) is configured to check the code for issues.
Inside the respective subdirectories, run `tflint --init` to initialize it, and `tflint` to run it. Different `.tflint.hcl` configurations exist for each subdirectory.

Before committing, please run `terraform tmf` to apply Terraform's standard configuration style consistently.
