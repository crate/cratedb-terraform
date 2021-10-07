output "cratedb_application_url" {
  value       = "http${var.crate.ssl_enable ? "s" : ""}://${aws_lb.loadbalancer.dns_name}:4200"
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
