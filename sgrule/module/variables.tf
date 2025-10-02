variable "suga" {
  type = object({
    stack_id = string
  })
}

variable "security_group_ids" {
  type        = list(string)
  description = "List of security group IDs to which the rule will be applied"
}

variable "from_port" {
  type        = number
  description = "The starting port of the port range for the TCP and UDP protocols, or an ICMP type."
}

variable "to_port" {
  type        = number
  description = "The ending port of the port range for the TCP and UDP protocols, or an ICMP code."
}

variable "protocol" {
  type        = string
  default     = "tcp"
  description = "The protocol. Use -1 to specify all protocols."
}

variable "type" {
  type        = string
  default     = "ingress"
  description = "The type of rule, either ingress (inbound) or egress (outbound)."
}

variable "self" {
  type        = bool
  default     = null
  nullable    = true
  description = "Whether to allow traffic to/from the security group itself."
}

variable "cidr_blocks" {
  type        = list(string)
  default     = null
  nullable    = true
  description = "List of CIDR blocks to allow or deny, in CIDR notation."
}

variable "prefix_list_names" {
  type        = list(string)
  nullable    = true
  default     = null
  description = "List of AWS managed prefix list names to allow access (e.g., 'com.amazonaws.global.cloudfront.origin-facing')"
}