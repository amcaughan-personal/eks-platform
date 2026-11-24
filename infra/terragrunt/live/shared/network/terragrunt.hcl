include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  platform = read_terragrunt_config(find_in_parent_folders("platform.hcl")).locals
}

terraform {
  source = "tfr:///terraform-aws-modules/vpc/aws?version=6.8.0"
}

# One VPC with public subnets in three zones, shared by every cluster. There is no NAT
# gateway: nodes get public IPs, and their security groups allow no inbound traffic from
# the internet.
inputs = {
  name = local.platform.name
  cidr = "10.20.0.0/16"

  azs            = ["us-east-2a", "us-east-2b", "us-east-2c"]
  public_subnets = ["10.20.0.0/20", "10.20.16.0/20", "10.20.32.0/20"]

  map_public_ip_on_launch = true
  enable_nat_gateway      = false

  # Where the AWS Load Balancer Controller may place internet-facing load balancers.
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
}
