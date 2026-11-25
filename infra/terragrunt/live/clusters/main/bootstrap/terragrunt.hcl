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
  source = "${get_repo_root()}/infra/terragrunt/modules/argocd-bootstrap"
}

# Argo CD applies Karpenter's node pool, so Karpenter goes first.
dependencies {
  paths = ["../karpenter"]
}

inputs = {
  cluster_name = local.cluster.name
  gitops_dir   = "${get_repo_root()}/gitops"
}
