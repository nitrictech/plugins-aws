output "suga" {
  value = {
    id          = aws_ecs_service.service.id
    domain_name = data.aws_lb.alb.dns_name
    exports = {
      resources = {
        "aws_lb" = var.alb_arn
        # The security group that the for this service is attached to
        "aws_lb:security_group" = var.alb_security_group
        # The path to reach this service on the load balancer
        "aws_lb:path" = "/${var.suga.name}"
      }
    }
  }
}

