output "security_group_rule_ids" {
  description = "The IDs of the created security group rules"
  value       = aws_security_group_rule.rules[*].id
}