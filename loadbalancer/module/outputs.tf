output "arn" {
  value = aws_lb.lb.arn
}

output "listener_arn" {
  value = aws_lb_listener.http.arn
}