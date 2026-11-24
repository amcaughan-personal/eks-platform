variable "name" {
  description = "Name prefix for the bucket and log groups."
  type        = string
}

variable "clusters" {
  description = "Cluster names; each gets its own log groups."
  type        = list(string)
}

variable "retention_days" {
  description = "How long task logs and log group entries are kept."
  type        = number
}
