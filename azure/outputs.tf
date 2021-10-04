output "cratedb_application_url" {
  value       = "http://${azurerm_public_ip.main.fqdn}:4200"
  description = "The publicly accessible URL of the CrateDB cluster"
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

output "azurevm_private_key" {
  value       = tls_private_key.ssh_key.private_key_pem
  sensitive   = true
  description = "Private key to connect via SSH to the Azure VMs"
}
