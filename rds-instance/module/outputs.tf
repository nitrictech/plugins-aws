output "db_instance_id" {
  description = "Unique identifier of the RDS instance"
  value       = aws_db_instance.this.id
}

output "db_instance_arn" {
  description = "Amazon Resource Name (ARN) of the RDS instance"
  value       = aws_db_instance.this.arn
}

output "db_instance_endpoint" {
  description = "Connection endpoint in format hostname:port"
  value       = aws_db_instance.this.endpoint
}

output "db_instance_name" {
  description = "Name of the initial database created"
  value       = aws_db_instance.this.db_name
}

output "db_instance_username" {
  description = "Master username for database access"
  value       = aws_db_instance.this.username
}

output "db_instance_resource_id" {
  description = "Resource ID of the RDS instance"
  value       = aws_db_instance.this.resource_id
}

output "db_subnet_group_id" {
  description = "ID of the DB subnet group"
  value       = aws_db_subnet_group.this.id
}

output "db_security_group_id" {
  description = "ID of the security group attached to the RDS instance"
  value       = aws_security_group.this.id
}

output "db_master_password" {
  description = "Master password for the RDS instance"
  value       = random_password.master_password.result
  sensitive   = true
}

output "codebuild_project_name" {
  description = "Name of the CodeBuild project for database operations"
  value       = aws_codebuild_project.db_operations.name
}

output "codebuild_project_arn" {
  description = "ARN of the CodeBuild project for database operations"
  value       = aws_codebuild_project.db_operations.arn
}

output "bastion_security_group_id" {
  description = "Security group ID for SSM bastion instances (empty if enable_ssm_bastion_access is false)"
  value       = var.enable_ssm_bastion_access ? aws_security_group.bastion[0].id : ""
}

output "bastion_instance_profile_name" {
  description = "IAM instance profile name for SSM bastion instances (empty if enable_ssm_bastion_access is false)"
  value       = var.enable_ssm_bastion_access ? aws_iam_instance_profile.bastion[0].name : ""
}
