data "aws_ec2_managed_prefix_list" "prefix_lists" {
  for_each = var.prefix_list_names != null ? toset(var.prefix_list_names) : []
  name     = each.key
}

# Add a security group rule that allows self ingres traffic to allow the ALB to access the health check service
resource "aws_security_group_rule" "rules" {
  count = length(var.security_group_ids)
  security_group_id = var.security_group_ids[count.index]
  from_port = var.from_port
  to_port = var.to_port
  protocol = var.protocol
  type = var.type
  self = var.self
  cidr_blocks = var.cidr_blocks
  prefix_list_ids = length(data.aws_ec2_managed_prefix_list.prefix_lists) > 0 ? [for pl in data.aws_ec2_managed_prefix_list.prefix_lists : pl.id] : null
}