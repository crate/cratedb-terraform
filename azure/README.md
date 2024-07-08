# CrateDB cluster on Azure VM using Terraform

This Terraform configuration will launch a CrateDB cluster on Azure. It consists of a public-facing load lancer with and a set of Virtual Machines.

![Azure architecture](azure_architecture.png)

The provided configuration is meant as an easy way to get started. It is not necessarily production-ready in all aspects, such as backups, high availability, and security. Please clone and extend the configuration to fit your individual needs, if needed.

## Setup

The Terraform configuration generates by default an individual self-signed SSL certificate. If `crate.ssl_enable` is set to false, SSL will be disabled.

The main setup consists of the following steps:

1. Create a new directory that will contain the Terraform configuration as well as all state information: `mkdir cratedb-terraform-example && cd cratedb-terraform-example`
2. Crate a new `main.tf` Terraform configuration in that directory, referencing the CrateDB module from this repository:

    ```hcl
    module "cratedb-cluster" {
      source = "github.com/crate/cratedb-terraform.git/azure"

      # Your Azure Subscription ID
      subscription_id = "your-Azure-subscription-id"

      # Global configuration items
      config = {
        # Used for naming/tagging Azure resources
        project_name = "example-project"
        environment  = "test"
        owner        = "Crate.IO"
        team         = "Customer Engineering"

        # Run "az account list-locations" for a full list
        location = "westeurope"
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

      # Azure VM specific configuration
      vm = {
        # The size of the disk storing CrateDB's data directory
        disk_size_gb         = 512
        storage_account_type = "Premium_LRS"
        size                 = "Standard_DS12_v2"

        # Enabling SSH access
        ssh_access = true
        # Username to connect via SSH to the nodes
        user = "cratedb-vmadmin"
      }
    }

    output "cratedb" {
      value     = module.cratedb-cluster
      sensitive = true
    }
    ```

3. Run `terraform init` to download and install all needed providers.
4. Provide AWS credentials. There are several options [available](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs#authenticating-to-azure). The easiest option is to install the [AZ CLI](https://learn.microsoft.com/en-us/cli/azure/) and log in using the `az login` command.

## Execution

To run the Terraform configuration:

1. Run `terraform plan` to validate the planned resource creation
2. Run `terraform apply` to execute the plan
3. Run `terraform output -json` to view the cleartext output, such as the CrateDB URL and login credentials

## Accessing CrateDB

The above last-mentioned step will output all needed information to connect to CrateDB. This includes the publicly accessible URL of the load balancer, as well as login credentials. On opening this URL in a browser, an HTTP Basic Auth appears.

Please note that it might take a couple of minutes before VMs are fully provisioned and CrateDB becomes accessible.

## Accessing Azure VMs

Azure VMs are not directly accessible as they have private IP addresses. To connect to them, use a [bastion host](https://docs.microsoft.com/en-us/azure/bastion/quickstart-host-portal). Please see `terraform output -json` for the user name and private key which are valid for all VMs.
In the default configuration, SSH access is enabled in the network security group. It can be disabled if needed via the `vm.ssh_access` variable.
