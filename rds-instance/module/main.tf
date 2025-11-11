# Generate a random password for the master user
resource "random_password" "master_password" {
  length  = 32
  special = false
}

# DB Subnet Group
resource "aws_db_subnet_group" "this" {
  name       = "${var.identifier}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(
    var.tags,
    {
      Name = "${var.identifier}-subnet-group"
    }
  )
}

# Security Group for RDS
resource "aws_security_group" "this" {
  name        = "${var.identifier}-sg"
  description = "Security group for RDS PostgreSQL instance ${var.identifier}"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.identifier}-sg"
    }
  )
}

# Allow ingress from specified security groups
resource "aws_security_group_rule" "from_security_groups" {
  count = length(var.allowed_security_group_ids)

  type                     = "ingress"
  from_port                = local.db_port
  to_port                  = local.db_port
  protocol                 = "tcp"
  source_security_group_id = var.allowed_security_group_ids[count.index]
  security_group_id        = aws_security_group.this.id
  description              = "Allow PostgreSQL access from security group ${var.allowed_security_group_ids[count.index]}"
}

# Allow ingress from specified CIDR blocks
resource "aws_security_group_rule" "from_cidr_blocks" {
  count = length(var.allowed_cidr_blocks) > 0 ? 1 : 0

  type              = "ingress"
  from_port         = local.db_port
  to_port           = local.db_port
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  security_group_id = aws_security_group.this.id
  description       = "Allow PostgreSQL access from specified CIDR blocks"
}

# Self-referential rule (allows resources in the same SG to communicate)
resource "aws_security_group_rule" "self" {
  type              = "ingress"
  from_port         = local.db_port
  to_port           = local.db_port
  protocol          = "tcp"
  self              = true
  security_group_id = aws_security_group.this.id
  description       = "Allow PostgreSQL access within security group"
}

# Security Group for SSM Bastion instances (optional)
resource "aws_security_group" "bastion" {
  count = var.enable_ssm_bastion_access ? 1 : 0

  name        = "${var.identifier}-bastion-sg"
  description = "Security group for SSM bastion instances to access RDS ${var.identifier}"
  vpc_id      = var.vpc_id

  # Allow all outbound traffic (needed for SSM Session Manager)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic for SSM"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.identifier}-bastion-sg"
    }
  )
}

# Allow ingress from bastion security group to RDS
resource "aws_security_group_rule" "from_bastion" {
  count = var.enable_ssm_bastion_access ? 1 : 0

  type                     = "ingress"
  from_port                = local.db_port
  to_port                  = local.db_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion[0].id
  security_group_id        = aws_security_group.this.id
  description              = "Allow PostgreSQL access from SSM bastion instances"
}

# Local variables
locals {
  db_port = var.port != null ? var.port : 5432
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "this" {
  identifier = var.identifier

  # Engine configuration
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  # Storage configuration
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type
  storage_encrypted     = var.storage_encrypted
  kms_key_id            = var.kms_key_id

  # Database configuration
  db_name  = var.database_name
  username = var.master_username
  password = random_password.master_password.result
  port     = local.db_port

  # Network configuration
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  publicly_accessible    = var.publicly_accessible
  multi_az               = var.multi_az

  # Backup configuration
  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window
  skip_final_snapshot     = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot == false ? (
    var.final_snapshot_identifier != null ? var.final_snapshot_identifier : "${var.identifier}-final-snapshot"
  ) : null

  # Deletion protection
  deletion_protection = var.deletion_protection

  # Monitoring and logging
  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports
  monitoring_interval             = var.monitoring_interval
  monitoring_role_arn             = var.monitoring_role_arn

  # Performance Insights
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null

  # Maintenance and upgrades
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  apply_immediately          = var.apply_immediately

  # Parameter group
  parameter_group_name = var.parameter_group_name

  # Tags
  tags = merge(
    var.tags,
    {
      Name = var.identifier
    }
  )

}

# IAM Role for CodeBuild
resource "aws_iam_role" "codebuild" {
  name = "${var.identifier}-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM Policy for CodeBuild
resource "aws_iam_role_policy" "codebuild" {
  role = aws_iam_role.codebuild.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeDhcpOptions",
          "ec2:DescribeVpcs",
          "ec2:CreateNetworkInterfacePermission"
        ]
        Resource = "*"
      }
    ]
  })
}

# CodeBuild Project for Database Operations
resource "aws_codebuild_project" "db_operations" {
  name          = "${var.identifier}-db-operations"
  description   = "CodeBuild project for creating databases and roles on RDS instance"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 10

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "postgres:16-alpine"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "DB_HOST"
      value = aws_db_instance.this.address
    }

    environment_variable {
      name  = "DB_PORT"
      value = tostring(aws_db_instance.this.port)
    }

    environment_variable {
      name  = "DB_MASTER_USER"
      value = var.master_username
    }

    environment_variable {
      name  = "DB_PASSWORD"
      value = random_password.master_password.result
    }
  }

  vpc_config {
    vpc_id             = var.vpc_id
    subnets            = var.subnet_ids
    security_group_ids = [aws_security_group.this.id]
  }

  source {
    type      = "NO_SOURCE"
    buildspec = <<-EOT
      version: 0.2
      phases:
        build:
          commands:
            - echo "Running database operations..."
            - |
              export PGPASSWORD="$DB_PASSWORD"

              # Create role if it doesn't exist
              if ! psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_MASTER_USER" -d postgres -tc \
                "SELECT 1 FROM pg_roles WHERE rolname='$DB_ROLE'" | grep -q 1; then
                psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_MASTER_USER" -d postgres -c \
                  "CREATE ROLE \"$DB_ROLE\" WITH LOGIN PASSWORD '$DB_ROLE_PASSWORD';"
                psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_MASTER_USER" -d postgres -c \
                  "GRANT \"$DB_ROLE\" TO \"$DB_MASTER_USER\";"
              fi

              # Create database if it doesn't exist
              psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_MASTER_USER" -d postgres -tc \
                "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1 || \
                psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_MASTER_USER" -d postgres -c \
                "CREATE DATABASE \"$DB_NAME\" OWNER \"$DB_ROLE\";"

              echo "Database operations completed successfully"
    EOT
  }

  tags = var.tags
}

# IAM Role for SSM Bastion instances (optional)
resource "aws_iam_role" "bastion" {
  count = var.enable_ssm_bastion_access ? 1 : 0

  name = "${var.identifier}-bastion-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.identifier}-bastion-role"
    }
  )
}

# Attach AWS managed policy for SSM
resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  count = var.enable_ssm_bastion_access ? 1 : 0

  role       = aws_iam_role.bastion[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# IAM Instance Profile for SSM Bastion instances
resource "aws_iam_instance_profile" "bastion" {
  count = var.enable_ssm_bastion_access ? 1 : 0

  name = "${var.identifier}-bastion-profile"
  role = aws_iam_role.bastion[0].name

  tags = merge(
    var.tags,
    {
      Name = "${var.identifier}-bastion-profile"
    }
  )
}
