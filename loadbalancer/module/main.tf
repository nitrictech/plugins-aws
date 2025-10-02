resource "aws_lb" "lb" {
  name               = "${var.suga.stack_id}-${var.name}"
  internal           = var.internal
  load_balancer_type = var.load_balancer_type
  security_groups    = var.security_groups
  subnets            = var.subnets

  drop_invalid_header_fields = true
}

# Get managed prefix lists by name
data "aws_ec2_managed_prefix_list" "prefix_lists" {
  for_each = toset(var.prefix_list_names)
  name     = each.key
}

# Create shared HTTP listener for services
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.lb.arn
  port              = var.listener_port
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

data "aws_security_group" "groups" {
  count = length(var.security_groups)
  id    = var.security_groups[count.index]
}
