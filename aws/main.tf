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
    prometheus    = "3.16.0"  # https://prometheus.io/download/#prometheus
    sql_exporter  = "0.24.13" # https://github.com/burningalchemist/sql_exporter/releases
    node_exporter = "1.12.1"  # https://prometheus.io/download/#node_exporter
    jmx_exporter  = "1.2.5"   # https://github.com/crate/jmx_exporter/releases
    pyroscope     = "2.9.2"   # https://github.com/grafana/pyroscope-java/releases
  }

  config = {
    project_name   = var.config.project_name
    environment    = var.config.environment
    component_name = "${var.config.project_name}-${var.config.environment}"
    crate_username = "admin"
  }
}
