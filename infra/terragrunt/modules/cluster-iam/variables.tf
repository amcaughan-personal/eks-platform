variable "name" {
  description = "Name prefix for the roles."
  type        = string
}

variable "clusters" {
  description = "Cluster names; each gets its own roles."
  type        = list(string)
}
