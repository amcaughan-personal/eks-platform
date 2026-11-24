output "controller_role_arns" {
  value = { for cluster, k in module.karpenter : cluster => k.iam_role_arn }
}

output "queue_names" {
  value = { for cluster, k in module.karpenter : cluster => k.queue_name }
}
