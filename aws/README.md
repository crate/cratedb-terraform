# CrateDB cluster on EC2 instances using Terraform

This Terraform configuration will launch a CrateDB cluster on AWS. It consists of a public-facing load lancer with and a set of EC2 instances.

![AWS architecture](aws_architecture.png)

The provided configuration is meant as an easy way to get started. It is not necessarily production-ready in all aspects, such as backups, high availability, and security. Please clone and extend the configuration to fit your individual needs, if needed.

## Setup

The Terraform configuration generates by default an individual self-signed SSL certificate. If `crate.ssl_enable` is set to false, SSL will be disabled.
For a full list of available variables (including disk configuration), please see [variables.tf](variables.tf).

The main setup consists of the following steps:

1. Create a new directory that will contain the Terraform configuration as well as all state information: `mkdir cratedb-terraform-example && cd cratedb-terraform-example`
2. Crate a new `main.tf` Terraform configuration in that directory, referencing the CrateDB module from this repository:

    ```hcl
    module "cratedb-cluster" {
      source = "github.com/crate/cratedb-terraform.git/aws"

      # Global configuration items for naming/tagging resources
      config = {
        project_name = "example-project"
        environment  = "test"
        owner        = "Crate.IO"
        team         = "Customer Engineering"
      }

      # CrateDB-specific configuration
      crate = {
        # Java Heap size in GB available to CrateDB
        heap_size_gb = 2

        cluster_name = "crate-cluster"

        # The number of nodes the cluster will consist of
        cluster_size = 2

        # Enables a self-signed SSL certificate
        ssl_enable = true
      }

      # The disk size in GB to use for CrateDB's data directory
      disk_size_gb = 512

      # The AWS region
      region = "eu-central-1"

      # The VPC to deploy to
      vpc_id = "vpc-1234567"

      # Applicable subnets of the VPC
      subnet_ids = ["subnet-123456", "subnet-123457"]

      # The corresponding availability zones of above subnets
      availability_zones = ["eu-central-1b", "eu-central-1a"]

      # The SSH key pair for EC2 instances
      ssh_keypair = "cratedb-cluster"

      # Enable SSH access to EC2 instances
      ssh_access = true
    }

    output "cratedb" {
      value     = module.cratedb-cluster
      sensitive = true
    }
    ```

3. Run `terraform init` to download and install all needed providers.
4. Provide AWS credentials. There are several options [available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#authentication-and-configuration). The easiest option is to store credentials in your home directory by creating the file `~/.aws/credentials` with the below content:

    ```yaml
    [default]
    aws_access_key_id = <Access Key ID>
    aws_secret_access_key = <Secret Access Key>
    ```

## Execution

To run the Terraform configuration:

1. Run `terraform plan` to validate the planned resource creation
2. Run `terraform apply` to execute the plan
3. Run `terraform output -json` to view the cleartext output, such as the CrateDB URL and login credentials

## Accessing CrateDB

The above last-mentioned step will output all needed information to connect to CrateDB. This includes the publicly accessible URL of the load balancer, as well as login credentials. On opening this URL in a browser, an HTTP Basic Auth appears.

Please note that it might take a couple of minutes before instances are fully provisioned and CrateDB becomes accessible.

## Accessing EC2 instances

Your EC2 instances will only have a public IP address if the corresponding VPC subnet is configured to [auto-assign](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-ip-addressing.html) public IP addresses.

Connecting via SSH can be done using the `ec2-user` account and the configured key pair. In the default configuration, SSH access is enabled in the security group. It can be disabled if needed via the `ssh_access` variable.

## Utility EC2 instance

Optionally, you can provision an additional EC2 instance that will not run CrateDB. Instead, it can be used to run benchmarks or other client applications. It is located in the same VPC and subnet as the CrateDB nodes for optimal network latency.

Connect to the EC2 instance using the `ec2-user` account and the configured key pair. The host and port for SSH connections is available via the output variables `utility_vm_host` and `utility_vm_port`.

## Crate JMX Exporter

The [Crate JMX Exporter](https://github.com/crate/jmx_exporter) exposes monitoring metrics in the Prometheus format. It is available through the load balancer on port 8080. Independent of the `crate.ssl_enable` setting, the endpoint is always accessible through `http`.

## Prometheus

[Prometheus](https://prometheus.io) is capturing the export of the Crate JMX Exporter. It is available through the load balancer on port 9090 through `https` with a self-signed certificate. Basic authentication is in place with the user `admin` and the password provided in the output variable `utility_vm_prometheus_password`.

Specify `prometheus_ssl = false` if you prefer Prometheus not to use SSL.
