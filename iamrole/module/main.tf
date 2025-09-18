resource "aws_iam_role" "role" {
  name = "${var.suga.stack_id}-${var.suga.name}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = var.trusted_services
        }
        Action = var.trusted_actions
      }
    ]
  })
}
