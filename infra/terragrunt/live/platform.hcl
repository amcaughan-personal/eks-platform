# Values every stack shares. Each stack reads this with read_terragrunt_config.
locals {
  name = "eks-platform"

  # One folder per cluster under live/clusters/. Resources in shared/ that belong to one
  # cluster (its log groups) are created for each name here.
  clusters = ["main"]
}
