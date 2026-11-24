include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "cluster" {
  path   = find_in_parent_folders("cluster.hcl")
  expose = true
}

locals {
  cluster = include.cluster.locals
}

terraform {
  source = "${get_repo_root()}/infra/terragrunt/modules/karpenter-install"
}

dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    cluster_endpoint                   = "https://mock.eks.amazonaws.com"
    cluster_certificate_authority_data = "bW9jaw=="
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "providers"]
}

dependency "karpenter_shared" {
  config_path = "../../../shared/karpenter"

  mock_outputs = {
    controller_role_arns = { main = "arn:aws:iam::000000000000:role/mock-karpenter" }
    queue_names          = { main = "mock-karpenter" }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "providers"]
}

# Helm talks to this cluster's API with a short-lived token from the AWS CLI.
generate "helm_provider" {
  path      = "helm_provider.tf"
  if_exists = "overwrite_terragrunt"

  contents = <<EOF
provider "helm" {
  kubernetes = {
    host                   = "${dependency.eks.outputs.cluster_endpoint}"
    cluster_ca_certificate = base64decode("${dependency.eks.outputs.cluster_certificate_authority_data}")
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", "${local.cluster.name}", "--region", "us-east-2"]
    }
  }
}
EOF
}

inputs = {
  cluster_name        = local.cluster.name
  controller_role_arn = dependency.karpenter_shared.outputs.controller_role_arns[local.cluster.name]
  queue_name          = dependency.karpenter_shared.outputs.queue_names[local.cluster.name]
  chart_version       = "1.15.3"
}
