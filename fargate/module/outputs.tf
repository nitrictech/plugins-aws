output "suga" {
  value = {
    id          = aws_ecs_service.service.id
    domain_name = data.aws_lb.alb.dns_name
    exports = {
      resources = {
        "aws_lb" = var.alb_arn
        # The security group that the for this service is attached to
        "aws_lb:security_group" = var.alb_security_group
        # Target group ARN for CloudFront to create listener rules
        "aws_lb_target_group" = aws_lb_target_group.service.arn
        # Path pattern for routing to this target group
        "aws_lb_target_group:path" = "/${var.suga.name}"
      }
    }
  }
}

