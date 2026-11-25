variable "cluster_name" {
  type = string
}

variable "gitops_dir" {
  description = "Path to the repo's gitops/ directory."
  type        = string
}

variable "argocd_chart_version" {
  type = string
}

variable "revision" {
  description = "The branch Argo CD follows."
  type        = string
  default     = "main"
}
