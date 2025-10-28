variable "identifier" {
  type        = string
  description = "Unique identifier for the RDS instance"
}

variable "engine_version" {
  type        = string
  description = "PostgreSQL engine version"
  default     = null
}

variable "instance_class" {
  type        = string
  description = "Compute and memory capacity for the RDS instance"
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  type        = number
  description = "Initial storage size in GB"
  default     = 20
}

variable "max_allocated_storage" {
  type        = number
  description = "Maximum storage autoscaling limit in GB"
  default     = null
}

variable "storage_type" {
  type        = string
  description = "Storage type (gp2, gp3, io1)"
  default     = "gp3"
}

variable "storage_encrypted" {
  type        = bool
  description = "Enable storage encryption at rest"
  default     = true
}

variable "kms_key_id" {
  type        = string
  description = "ARN of AWS KMS key for encryption"
  default     = null
}

variable "database_name" {
  type        = string
  description = "Initial database name to create"
  default     = null
}

variable "master_username" {
  type        = string
  description = "Master username for database access"
  default     = "postgres"
}

variable "port" {
  type        = number
  description = "TCP port for database connections"
  default     = null
}

variable "multi_az" {
  type        = bool
  description = "Enable multi-AZ deployment"
  default     = false
}

variable "publicly_accessible" {
  type        = bool
  description = "Allow public access to the database"
  default     = false
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where RDS will be deployed"
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs for RDS subnet group"
}

variable "allowed_security_group_ids" {
  type        = list(string)
  description = "Security group IDs allowed to connect to the database"
  default     = []
}

variable "allowed_cidr_blocks" {
  type        = list(string)
  description = "CIDR blocks allowed to connect to the database"
  default     = []
}

variable "backup_retention_period" {
  type        = number
  description = "Days to retain automated backups"
  default     = 7
}

variable "backup_window" {
  type        = string
  description = "Daily backup time window in UTC"
  default     = null
}

variable "maintenance_window" {
  type        = string
  description = "Weekly maintenance window in UTC"
  default     = null
}

variable "skip_final_snapshot" {
  type        = bool
  description = "Skip final snapshot before deletion"
  default     = false
}

variable "final_snapshot_identifier" {
  type        = string
  description = "Name for final snapshot when database is deleted"
  default     = null
}

variable "deletion_protection" {
  type        = bool
  description = "Prevent accidental deletion"
  default     = false
}

variable "enabled_cloudwatch_logs_exports" {
  type        = list(string)
  description = "PostgreSQL log types to export to CloudWatch"
  default     = []
}

variable "monitoring_interval" {
  type        = number
  description = "Enhanced monitoring interval in seconds"
  default     = 0
}

variable "monitoring_role_arn" {
  type        = string
  description = "IAM role ARN for enhanced monitoring"
  default     = null
}

variable "performance_insights_enabled" {
  type        = bool
  description = "Enable performance insights"
  default     = false
}

variable "performance_insights_retention_period" {
  type        = number
  description = "Days to retain performance insights data"
  default     = 7
}

variable "auto_minor_version_upgrade" {
  type        = bool
  description = "Automatically apply minor engine upgrades"
  default     = true
}

variable "apply_immediately" {
  type        = bool
  description = "Apply changes immediately instead of during maintenance window"
  default     = false
}

variable "parameter_group_name" {
  type        = string
  description = "Custom DB parameter group name"
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default     = {}
}

variable "enable_ssm_bastion_access" {
  type        = bool
  description = "Enable creation of security group and IAM instance profile for SSM bastion access"
  default     = false
}
