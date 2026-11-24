variable "cluster_name" {
  type = string
}

variable "controller_role_arn" {
  description = "Karpenter's controller role (shared/karpenter)."
  type        = string
}

variable "queue_name" {
  description = "Karpenter's interruption queue (shared/karpenter)."
  type        = string
}

variable "chart_version" {
  type = string
}
