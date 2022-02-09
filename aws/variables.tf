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

variable "utility_vm" {
  type = object({
    instance_type = string
    disk_size_gb  = number
    disk_type     = string
  })

  default = {
    instance_type = "t3.xlarge"
    disk_type     = "gp3"
    disk_size_gb  = 50
  }

  description = "Configuration of the utility EC2 instance"
}
