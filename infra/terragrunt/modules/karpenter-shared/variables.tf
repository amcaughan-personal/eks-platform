variable "name" {
  description = "Name prefix for the roles and queues."
  type        = string
}

variable "node_role_arns" {
  description = "Each cluster's node role ARN (from shared/iam), keyed by cluster name."
  type        = map(string)
}
