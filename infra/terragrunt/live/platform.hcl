# Values every stack shares. Each stack reads this with read_terragrunt_config.
locals {
  name = "eks-platform"

  # Every folder under clusters/ with a cluster.hcl is a cluster, named after its folder.
  # shared/ creates each one's own pieces (IAM roles, log groups, Karpenter's queue).
  clusters = sort([
    for f in fileset("${dirname(find_in_parent_folders("root.hcl"))}/live/clusters", "*/cluster.hcl") : dirname(f)
  ])
}
