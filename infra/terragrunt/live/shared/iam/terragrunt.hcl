include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  platform = read_terragrunt_config(find_in_parent_folders("platform.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/infra/terragrunt/modules/cluster-iam"
}

inputs = {
  name     = local.platform.name
  clusters = local.platform.clusters
}
