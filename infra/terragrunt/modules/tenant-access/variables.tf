variable "cluster_name" {
  type = string
}

variable "tenants" {
  description = "Each tenant's pod roles (service account -> IAM role name), from gitops/tenants/<name>/values.yaml."
  type        = map(map(string))

  validation {
    condition = alltrue(flatten([
      for tenant, roles in var.tenants : [for role in values(roles) : startswith(role, "${tenant}-pod-")]
    ]))
    error_message = "A tenant's pod roles must be named <tenant>-pod-<name>, so a tenant can only get its own repo's roles."
  }
}
