# The IAM roles each cluster runs with. They live in shared/, not with the cluster, so
# bringing a cluster up or down never creates or deletes IAM roles: whoever does that only
# needs to pass these existing roles to EKS and EC2.

locals {
  cluster_policies = ["AmazonEKSClusterPolicy"]
  node_policies = [
    "AmazonEKSWorkerNodePolicy",
    "AmazonEKS_CNI_Policy",
    "AmazonEC2ContainerRegistryPullOnly",
  ]

  cluster_attachments = { for pair in setproduct(var.clusters, local.cluster_policies) : join("/", pair) => { cluster = pair[0], policy = pair[1] } }
  node_attachments    = { for pair in setproduct(var.clusters, local.node_policies) : join("/", pair) => { cluster = pair[0], policy = pair[1] } }
}

data "aws_iam_policy_document" "cluster_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "node_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# The control plane's role.
resource "aws_iam_role" "cluster" {
  for_each = toset(var.clusters)

  name               = "${var.name}-${each.key}-cluster"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume.json
}

resource "aws_iam_role_policy_attachment" "cluster" {
  for_each = local.cluster_attachments

  role       = aws_iam_role.cluster[each.value.cluster].name
  policy_arn = "arn:aws:iam::aws:policy/${each.value.policy}"
}

# Every node's role: join the cluster, run the pod network, pull images.
resource "aws_iam_role" "node" {
  for_each = toset(var.clusters)

  name               = "${var.name}-${each.key}-node"
  assume_role_policy = data.aws_iam_policy_document.node_assume.json
}

resource "aws_iam_role_policy_attachment" "node" {
  for_each = local.node_attachments

  role       = aws_iam_role.node[each.value.cluster].name
  policy_arn = "arn:aws:iam::aws:policy/${each.value.policy}"
}
