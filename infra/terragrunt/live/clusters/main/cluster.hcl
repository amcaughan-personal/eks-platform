# This cluster's settings. Its name is its folder's name. Every stack under the folder
# includes this file, so everything the cluster creates is tagged Cluster = <name>: that tag
# is how its resources are found (and cleaned up) after the cluster is gone.
locals {
  name               = basename(dirname(get_original_terragrunt_dir())) # clusters/<name>/<stack>
  kubernetes_version = "1.37"

  # IAM roles (path and name) with admin access to the cluster: CI's cluster-lifecycle role
  # (personal-infra), and the AWS SSO administrator role used locally.
  admins = [
    "github-ci-cluster-lifecycle-eks-platform",
    "aws-reserved/sso.amazonaws.com/us-east-2/AWSReservedSSO_AdministratorAccess_a4488d02a1cba7ef",
  ]
}

inputs = {
  extra_default_tags = {
    Cluster = local.name
  }
}
