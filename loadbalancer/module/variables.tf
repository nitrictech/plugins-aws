variable "load_balancer_type" {
  type    = string
  default = "application"
}

variable "name" {
  type = string
}

variable "listener_port" {
  type    = number
  default = 80
}
variable "internal" {
  type    = bool
  default = true
}

variable "security_groups" {
  type = list(string)
}

variable "subnets" {
  type = list(string)
}
