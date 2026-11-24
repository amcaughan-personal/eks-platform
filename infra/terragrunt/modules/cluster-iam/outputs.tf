output "cluster_role_arns" {
  value = { for cluster, role in aws_iam_role.cluster : cluster => role.arn }
}

output "node_role_arns" {
  value = { for cluster, role in aws_iam_role.node : cluster => role.arn }
}
