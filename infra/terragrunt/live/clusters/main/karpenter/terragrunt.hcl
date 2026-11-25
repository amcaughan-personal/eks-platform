include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "cluster" {
  path   = find_in_parent_folders("cluster.hcl")
  expose = true
}

include "helm" {
  path = find_in_parent_folders("helm.hcl")
}

locals {
  cluster = include.cluster.locals
}

terraform {
  source = "${get_repo_root()}/infra/terragrunt/modules/karpenter-install"
}

dependency "karpenter_shared" {
  config_path = "../../../shared/karpenter"

  mock_outputs = {
    controller_role_arns = { main = "arn:aws:iam::000000000000:role/mock-karpenter" }
    queue_names          = { main = "mock-karpenter" }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "providers", "show"]
}

inputs = {
  cluster_name        = local.cluster.name
  controller_role_arn = dependency.karpenter_shared.outputs.controller_role_arns[local.cluster.name]
  queue_name          = dependency.karpenter_shared.outputs.queue_names[local.cluster.name]
  chart_version       = "1.15.3"
}
