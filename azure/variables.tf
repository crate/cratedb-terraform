variable "config" {
  type = object({
    environment  = string
    location     = string
    project_name = string
    owner        = string
    team         = string
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

  description = "Configuration of the CrateDB application"
}

variable "vm" {
  type = object({
    user                 = string
    disk_size_gb         = number
    storage_account_type = string
    size                 = string
    ssh_access           = bool
  })

  default = {
    user                 = "cratedb-vmadmin"
    disk_size_gb         = 500
    storage_account_type = "Premium_LRS"
    size                 = "Standard_DS12_v2"
    ssh_access           = true
  }

  description = "Configuration of the Azure VMs"
}

variable "subscription_id" {
  type        = string
  description = "The Azure subscription ID"
}
