output "cratedb_application_url" {
  value       = "http${var.crate.ssl_enable ? "s" : ""}://${aws_lb.loadbalancer.dns_name}:4200"
  description = "The publicly accessible URL of the CrateDB cluster"
}

output "cratedb_username" {
  value       = local.config.crate_username
  description = "The username to authenticate against CrateDB"
}

output "cratedb_password" {
  value       = local.cratedb_password
  sensitive   = true
  description = "The password to authenticate against CrateDB"
}

output "utility_vm_host" {
  value       = aws_lb.loadbalancer.dns_name
  description = "If enabled, the utility VM can be reached using this hostname"
}

output "utility_vm_port" {
  value       = local.ssh_alternative_port
  description = "If enabled, the utility VM can be reached using this port"
}

output "utility_vm_prometheus_password" {
  value       = local.prometheus_password
  sensitive   = true
  description = "If the utility VM is enabled, this is the password to access Prometheus with CrateDB performance metrics"
}
