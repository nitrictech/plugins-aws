output "database_name" {
  description = "Name of the created database"
  value       = local.database_name
}

output "database_owner" {
  description = "Username of the database owner"
  value       = local.database_owner
}

output "database_password" {
  description = "Password for the database owner"
  value       = random_password.db_password.result
  sensitive   = true
}

output "connection_string" {
  description = "PostgreSQL connection string for the database"
  value       = local.connection_string
  sensitive   = true
}

output "suga" {
  value = {
    id = local.database_name
    exports = {
      # Export known service outputs
      services  = local.service_outputs
      resources = {}
    }
  }
}
