include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "cluster" {
  path   = find_in_parent_folders("cluster.hcl")
  expose = true
}

locals {
  cluster     = include.cluster.locals
  tenants_dir = "${get_repo_root()}/gitops/tenants"

  # The same files Argo CD reads: each tenant's folder name and its pod roles.
  tenants = {
    for f in fileset(local.tenants_dir, "*/values.yaml") :
    dirname(f) => try(yamldecode(file("${local.tenants_dir}/${f}")).podRoles, {})
  }
}

terraform {
  source = "${get_repo_root()}/infra/terragrunt/modules/tenant-access"
}

# Pod Identity links need the cluster.
dependencies {
  paths = ["../eks"]
}

inputs = {
  cluster_name = local.cluster.name
  tenants      = local.tenants
}
