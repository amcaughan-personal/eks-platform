include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "cluster" {
  path   = find_in_parent_folders("cluster.hcl")
  expose = true
}

locals {
  platform = read_terragrunt_config(find_in_parent_folders("platform.hcl")).locals
  cluster  = include.cluster.locals
}

terraform {
  source = "tfr:///terraform-aws-modules/eks/aws?version=21.30.2"
}

dependency "network" {
  config_path = "../../../shared/network"

  mock_outputs = {
    vpc_id         = "vpc-00000000"
    public_subnets = ["subnet-00000000", "subnet-11111111", "subnet-22222222"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "providers", "show"]
}

dependency "iam" {
  config_path = "../../../shared/iam"

  mock_outputs = {
    cluster_role_arns = { main = "arn:aws:iam::000000000000:role/mock-cluster" }
    node_role_arns    = { main = "arn:aws:iam::000000000000:role/mock-node" }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "providers", "show"]
}

# The control-plane log group already exists (shared/logs creates it).
dependencies {
  paths = ["../../../shared/logs"]
}

# The control plane, one small system node group and the core add-ons. Karpenter adds
# nodes for everything else.
inputs = {
  name               = local.cluster.name
  kubernetes_version = local.cluster.kubernetes_version

  vpc_id     = dependency.network.outputs.vpc_id
  subnet_ids = dependency.network.outputs.public_subnets

  # CI runners and laptops reach the API over the internet; nodes reach it privately.
  endpoint_public_access  = true
  endpoint_private_access = true

  authentication_mode                      = "API"
  enable_cluster_creator_admin_permissions = true

  # Pods get AWS access through EKS Pod Identity, so no IAM OIDC provider (IRSA).
  enable_irsa = false

  create_iam_role = false
  iam_role_arn    = dependency.iam.outputs.cluster_role_arns[local.cluster.name]

  create_cloudwatch_log_group = false
  enabled_log_types           = ["audit", "authenticator"]

  # Secrets are encrypted with the AWS-managed key: a customer key costs money each time a
  # cluster is created and takes at least a week to delete.
  create_kms_key    = false
  encryption_config = null

  addons = {
    vpc-cni = {
      before_compute = true
    }
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {}
    coredns    = {}
  }

  # How Karpenter finds the security group for the nodes it launches.
  node_security_group_tags = {
    "karpenter.sh/discovery" = local.cluster.name
  }

  eks_managed_node_groups = {
    system = {
      ami_type       = "AL2023_ARM_64_STANDARD"
      instance_types = ["t4g.medium"]

      min_size     = 1
      max_size     = 2
      desired_size = 1

      create_iam_role = false
      iam_role_arn    = dependency.iam.outputs.node_role_arns[local.cluster.name]

      labels = {
        "node-role" = "system"
      }
    }
  }
}
