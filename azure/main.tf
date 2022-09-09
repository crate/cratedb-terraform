terraform {
  required_version = "~> 1"

  required_providers {
    azurerm = {
      source  = "azurerm"
      version = "~> 3"
    }

    random = {
      source  = "random"
      version = "~> 3.4"
    }

    cloudinit = {
      source  = "cloudinit"
      version = "~> 2.2"
    }

    tls = {
      source  = "tls"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
}

locals {
  config = {
    project_name       = var.config.project_name
    environment        = var.config.environment
    component_name     = "${var.config.project_name}-${var.config.environment}"
    crate_username     = "admin"
    cratedb_ip_network = "192.168.100.0/24"
    cratedb_ip_mask    = "192.168.100.16/29"
  }
}

resource "azurerm_resource_group" "rg" {
  name     = "RG-${local.config.component_name}"
  location = var.config.location

  tags = {
    Team         = var.config.team
    Project      = var.config.project_name
    Projectowner = var.config.owner
  }
}
