output "cratedb_application_url" {
  value       = "http${var.crate.ssl_enable ? "s" : ""}://${azurerm_public_ip.main.fqdn}:4200"
  description = "The publicly accessible domain name of the CrateDB cluster"
}

output "cratedb_application_url_ip" {
  value       = "http${var.crate.ssl_enable ? "s" : ""}://${azurerm_public_ip.main.ip_address}:4200"
  description = "The publicly accessible IP of the CrateDB cluster"
}

output "cratedb_username" {
  value       = local.config.crate_username
  description = "The username to authenticate against CrateDB"
}

output "cratedb_password" {
  value       = random_password.cratedb_password.result
  sensitive   = true
  description = "The password to authenticate against CrateDB"
}

output "azurevm_username" {
  value       = var.vm.user
  description = "User name to connect via SSH to the Azure VMs"
}
