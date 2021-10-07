terraform {
  required_version = "~> 1"

  required_providers {
    aws = {
      source  = "aws"
      version = "~> 3.0"
    }

    template = {
      source  = "template"
      version = "~> 2.2"
    }

    random = {
      source  = "random"
      version = "~> 3.1"
    }

    tls = {
      source  = "tls"
      version = "~> 3.1"
    }
  }
}

provider "aws" {
  region = var.region
}

locals {
  config = {
    project_name   = var.config.project_name
    environment    = var.config.environment
    component_name = "${var.config.project_name}-${var.config.environment}"
    crate_username = "admin"
  }
}
