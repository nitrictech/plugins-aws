variable "rds_instance_endpoint" {
  type        = string
  description = "Connection endpoint of the RDS instance in format hostname:port"
}

variable "codebuild_project_name" {
  type        = string
  description = "Name of the CodeBuild project for database operations"
}

variable "database_name" {
  type        = string
  description = "Name of the database to create"
  default     = null
}

variable "database_owner" {
  type        = string
  description = "Username for the database owner role"
  default     = null
}

variable "suga" {
  type = object({
    name        = string
    stack_id    = string
    env_var_key = string
    services = map(object({
      actions = list(string)
      identities = map(object({
        exports = map(string)
      }))
    }))
  })
}
