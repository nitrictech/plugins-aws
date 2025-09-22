variable "load_balancer_type" {
  type    = string
  default = "application"
}

variable "name" {
  type    = string
}
variable "internal" {
  type    = bool
  default = false
}

variable "security_groups" {
  type    = set(string)
}

variable "subnets" {
  type    = list(string)
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
