terraform {
  required_version = "~> 1"

  required_providers {
    aws = {
      source  = "aws"
      version = "~> 5.97"
    }

    cloudinit = {
      source  = "cloudinit"
      version = "~> 2.3"
    }

    random = {
      source  = "random"
      version = "~> 3.7"
    }

    tls = {
      source  = "tls"
      version = "~> 4.1"
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
