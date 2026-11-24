# This cluster's name and version. Every stack under clusters/main includes this file, so
# everything the cluster creates is tagged Cluster = main: that tag is how its resources
# are found (and cleaned up) after the cluster is gone.
locals {
  name               = "main"
  kubernetes_version = "1.37"
}

inputs = {
  extra_default_tags = {
    Cluster = local.name
  }
}
