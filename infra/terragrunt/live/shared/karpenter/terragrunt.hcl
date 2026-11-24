include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  platform = read_terragrunt_config(find_in_parent_folders("platform.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/infra/terragrunt/modules/karpenter-shared"
}

dependency "iam" {
  config_path = "../iam"

  mock_outputs = {
    node_role_arns = { main = "arn:aws:iam::000000000000:role/mock-node" }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  name           = local.platform.name
  node_role_arns = dependency.iam.outputs.node_role_arns
}
