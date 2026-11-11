terraform {
  required_version = "~> 1"

  required_providers {
    aws = {
      source  = "aws"
      version = "~> 6.68"
    }

    cloudinit = {
      source  = "cloudinit"
      version = "~> 2.4"
    }

    random = {
      source  = "random"
      version = "~> 3.9"
    }

    tls = {
      source  = "tls"
      version = "~> 4.4"
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
  monitoring_versions = {
    prometheus    = "3.16.0"
    sql_exporter  = "0.24.13"
    node_exporter = "1.12.1"
    jmx_exporter  = "1.2.5"
    pyroscope     = "2.9.2"
  }

  config = {
    project_name   = var.config.project_name
    environment    = var.config.environment
    component_name = "${var.config.project_name}-${var.config.environment}"
    crate_username = "admin"
  }
}
