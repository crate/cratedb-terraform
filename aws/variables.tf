variable "config" {
  type = object({
    environment  = string
    project_name = string
    owner        = string
    team         = string
  })

  default = {
    project_name = "example-project"
    environment  = "test"
    owner        = "Crate.IO"
    team         = "Customer Engineering"
  }

  description = "Global configuration items"
}

variable "crate" {
  type = object({
    heap_size_gb = number
    cluster_name = string
    cluster_size = number
    ssl_enable   = bool
  })

  default = {
    heap_size_gb = 2
    cluster_name = "CrateDB-Cluster"
    cluster_size = 3
    ssl_enable   = true
  }

  description = "CrateDB application configuration"
}

variable "cratedb_password" {
  type        = string
  default     = null
  sensitive   = true
  description = "The password to use for the CrateDB database user. If null, a random password will be assigned."
}

variable "cratedb_tar_download_url" {
  type        = string
  description = "If specified, a tar.gz archive will be retrieve from the specified download URL instead of using the RPM package to install CrateDB"
  default     = null
  validation {
    condition     = var.cratedb_tar_download_url == null || can(regex("^https://cdn.crate.io/.*\\.tar\\.gz$", var.cratedb_tar_download_url))
    error_message = "The CrateDB tar.gz download URL must point to a https://cdn.crate.io address."
  }
}

variable "disk_size_gb" {
  type        = number
  description = "The disk size in GB to use for CrateDB's data directory"
  default     = 500
}

variable "disk_type" {
  type        = string
  description = "The disk type to use for CrateDB's data directory"
  default     = "gp3"
}

variable "disk_iops" {
  type        = number
  description = "Number of provisioned IOPS of the disk to use for CrateDB's data directory"
  default     = null
}

variable "disk_throughput" {
  type        = number
  description = "Amount of provisioned throughput of the disk to use for CrateDB's data directory (gp3 only)"
  default     = null
}

variable "region" {
  type        = string
  description = "The AWS region to deploy to"
  default     = "eu-central-1"
}

variable "vpc_id" {
  type        = string
  description = "The ID of an existing VPC to deploy to"
}

variable "instance_type" {
  type        = string
  default     = "t3.xlarge"
  description = "The EC2 instance type to use for nodes"
}

variable "instance_architecture" {
  type        = string
  default     = "x86_64"
  description = "The hardware architecture of the EC2 instance, e.g. x86_64 or arm64. Must match with the selected instance_type."
  validation {
    condition     = contains(["x86_64", "arm64"], var.instance_architecture)
    error_message = "Unsupported architecture. Must be x86_64 or arm64."
  }
}

variable "instance_profile" {
  type        = string
  default     = null
  description = "An optional EC2 instance profile to assign to CrateDB nodes"
}

variable "ssh_keypair" {
  type        = string
  description = "The name of an existing EC2 key pair"
}

variable "availability_zones" {
  type        = list(string)
  description = "A list of availability zones to deploy EC2 instances to. The corresponding subnet ID must be at the same index in the subnet_ids variable."
}

variable "subnet_ids" {
  type        = list(string)
  description = "A list of subnet IDs deploy EC2 instances in. The corresponding availability zone must be at the same index in the availability_zones variable."
}

variable "ssh_access" {
  type        = bool
  default     = true
  description = "Set to true, if inbound SSH access to EC2 instances should be allowed. Otherwise, set to false."
}

variable "enable_utility_vm" {
  type        = bool
  default     = false
  description = "If true, an additional EC2 instance will be created for running utilities, such as benchmarks or other scripts"
}

variable "load_balancer_internal" {
  type        = bool
  default     = false
  description = "If true, the load balancer's URL will resolve to a private IP address, only reachable from within the VPC"
}

variable "utility_vm" {
  type = object({
    instance_type         = string
    instance_architecture = string
    disk_size_gb          = number
    disk_iops             = number
    disk_throughput       = number
  })

  default = {
    instance_type         = "t3.xlarge"
    instance_architecture = "x86_64"
    disk_size_gb          = 50
    disk_iops             = null
    disk_throughput       = null
  }

  description = "Configuration of the utility EC2 instance"
}

variable "prometheus_password" {
  type        = string
  default     = null
  sensitive   = true
  description = "Optional password for the Prometheus admin user. If null, a random password will be assigned."
}
