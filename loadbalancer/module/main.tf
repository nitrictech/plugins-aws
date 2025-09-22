resource "aws_lb" "lb" {
  name               = var.name
  internal           = var.internal
  load_balancer_type = var.load_balancer_type
  security_groups    = var.security_groups
  subnets            = var.subnets
}

# Get managed prefix lists by name
data "aws_ec2_managed_prefix_list" "prefix_lists" {
  for_each = toset(var.prefix_list_names)
  name     = each.key
}

locals {
  listener_port = 80
}

# Create shared HTTP listener for services
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.lb.arn
  port              = local.listener_port
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Service not found"
      status_code  = "404"
    }
  }
}

# Allow HTTP traffic from internet
resource "aws_security_group_rule" "http_ingress" {
  for_each          = var.security_groups
  security_group_id = each.value
  from_port         = local.listener_port
  to_port           = local.listener_port
  protocol          = "tcp"
  type              = "ingress"
  cidr_blocks       = var.internal ? [] : var.cidr_blocks
}

# Allow HTTP traffic from specified prefix lists
resource "aws_security_group_rule" "prefix_list_ingress" {
  for_each          = var.security_groups
  security_group_id = each.value
  from_port         = local.listener_port
  to_port           = local.listener_port
  protocol          = "tcp"
  type              = "ingress"
  prefix_list_ids   = [for pl in data.aws_ec2_managed_prefix_list.prefix_lists : pl.id]
}