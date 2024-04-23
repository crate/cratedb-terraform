terraform {
  required_version = "~> 1"

  required_providers {
    aws = {
      source  = "aws"
      version = "~> 5.46"
    }

    cloudinit = {
      source  = "cloudinit"
      version = "~> 2.3"
    }

    random = {
      source  = "random"
      version = "~> 3.6"
    }

    tls = {
      source  = "tls"
      version = "~> 4.0"
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
