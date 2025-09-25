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

variable "cidr_blocks" {
  type    = list(string)
  default = []
}

variable "prefix_list_names" {
  type        = list(string)
  default     = []
  description = "List of AWS managed prefix list names to allow access (e.g., 'com.amazonaws.global.cloudfront.origin-facing')"
}
