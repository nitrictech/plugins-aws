# Get the current AWS region
data "aws_region" "current" {
}

# Local variables
locals {
  database_name  = var.database_name != null ? var.database_name : replace("${var.suga.stack_id}_${var.suga.name}", "-", "_")
  database_owner = var.database_owner != null ? var.database_owner : replace("${var.suga.stack_id}_${var.suga.name}_user", "-", "_")

  # Build PostgreSQL connection string
  connection_string = "postgresql://${local.database_owner}:${random_password.db_password.result}@${var.rds_instance_endpoint}/${local.database_name}?sslmode=require"

  # Output service export map
  service_outputs = {
    for name, service in var.suga.services : name => {
      env = {
        (var.suga.env_var_key) = local.connection_string
      }
    }
  }
}

# Generate a random password for the database owner role
resource "random_password" "db_password" {
  length  = 32
  special = false
}

# Trigger CodeBuild to create the database and role
resource "null_resource" "create_database" {
  triggers = {
    database_name     = local.database_name
    database_owner    = local.database_owner
    rds_endpoint      = var.rds_instance_endpoint
    codebuild_project = var.codebuild_project_name
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command = <<EOF
      BUILD_ID=$(aws codebuild start-build \
        --region ${data.aws_region.current.id} \
        --project-name ${var.codebuild_project_name} \
        --environment-variables-override '${jsonencode([
    {
      name  = "DB_NAME"
      value = local.database_name
    },
    {
      name  = "DB_ROLE"
      value = local.database_owner
    },
    {
      name  = "DB_ROLE_PASSWORD"
      value = random_password.db_password.result
    }
])}' \
        --query 'build.id' --output text)
      STATUS="IN_PROGRESS"
      while [[ $STATUS == "IN_PROGRESS" ]]; do
        sleep 5
        STATUS=$(aws codebuild batch-get-builds --region ${data.aws_region.current.id} --ids $BUILD_ID --query 'builds[0].buildStatus' --output text)
      done
      if [[ $STATUS != "SUCCEEDED" ]]; then
        echo "Build failed with status $STATUS"
        exit 1
      fi
    EOF
}
}
