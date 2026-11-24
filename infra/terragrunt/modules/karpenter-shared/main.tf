# What Karpenter needs that doesn't depend on a running cluster, per cluster: its
# controller's IAM role and the queue that hears about spot interruptions and instance
# health events. Both live in shared/, so bringing a cluster up or down never creates or
# deletes IAM roles. Karpenter's nodes use the cluster's node role (shared/iam), which
# EKS already lets join the cluster.

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "21.30.2"

  for_each = var.node_role_arns

  cluster_name = each.key

  iam_role_name            = "${var.name}-${each.key}-karpenter"
  iam_role_use_name_prefix = false

  queue_name       = "${var.name}-${each.key}-karpenter"
  rule_name_prefix = "${var.name}-${each.key}-"

  # Created with the cluster (clusters/<name>/karpenter); they need a running cluster.
  create_pod_identity_association = false
  create_access_entry             = false

  create_node_iam_role    = false
  node_iam_role_arn       = each.value
  create_instance_profile = false
}
