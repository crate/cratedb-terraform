terraform {
  required_version = "~> 1"

  required_providers {
    aws = {
      source  = "aws"
      version = "~> 4.0"
    }

    cloudinit = {
      source  = "cloudinit"
      version = "~> 2.2"
    }

    random = {
      source  = "random"
      version = "~> 3.1"
    }

    tls = {
      source  = "tls"
      version = "~> 3.4"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Environment = local.config.environment
      Owner       = var.config.owner
      Team        = var.config.team
    }
  }
}

locals {
  config = {
    project_name   = var.config.project_name
    environment    = var.config.environment
    component_name = "${var.config.project_name}-${var.config.environment}"
    crate_username = "admin"
  }
}
