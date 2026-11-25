# Included by every stack under this cluster that installs Helm charts (karpenter,
# bootstrap): a Helm provider that reaches the cluster's API with a short-lived token from
# the AWS CLI.
locals {
  cluster = read_terragrunt_config(find_in_parent_folders("cluster.hcl")).locals
}

dependency "eks" {
  config_path = "${get_terragrunt_dir()}/../eks"

  mock_outputs = {
    cluster_endpoint                   = "https://mock.eks.amazonaws.com"
    cluster_certificate_authority_data = "bW9jaw=="
  }
  # Destroy too: once the cluster is gone (e.g. a teardown that stopped halfway), these
  # stacks have nothing left to destroy, but still need a provider configuration.
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "providers", "show", "destroy"]
}

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

