variable "config" {
  type = object({
    environment = string
    project_name = string
    owner = string
    team = string
  })

  description = "Global configuration items"
}

variable "crate" {
  type = object({
    heap_size_gb = number
    cluster_name = string
    cluster_size = number
  })

  default = {
    heap_size_gb = 2
    cluster_name = "CrateDB-Cluster"
    cluster_size = 3
  }

  description = "CrateDB application configuration"
}

variable "disk_size_gb" {
  type = number
  description = "The disk size in GB to use for CrateDB's data directory"
  default = 500
}

variable "region" {
  type = string
  description = "The AWS region to deploy to"
  default = "eu-central-1"
}

variable "vpc_id" {
  type = string
  description = "The ID of an existing VPC to deploy to"
}

variable "ssh_keypair" {
  type = string
  description = "The name of an existing EC2 key pair"
}

variable "availability_zones" {
  type = list(string)
  description = "A list of availability zones to deploy EC2 instances to. The corresponding subnet ID be at the same index in the subnet_ids variable."
}

variable "subnet_ids" {
  type = list(string)
  description = "A list of subnet IDs deploy EC2 instances in. The corresponding availability zone must be at the same index in the availability_zones variable."
}