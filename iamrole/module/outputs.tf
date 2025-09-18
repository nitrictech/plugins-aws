output "suga" {
  value = {
    exports = {
      "aws_iam_role"  = aws_iam_role.role.arn
      "aws_iam_role:id" = aws_iam_role.role.id
      "aws_iam_role:arn" = aws_iam_role.role.arn
      "aws_iam_role:name" = aws_iam_role.role.name
    }
  }
}
