# Links each tenant's service accounts to its IAM roles through EKS Pod Identity. The roles live
# in the tenant's own repo (named <tenant>-pod-<name>, with that repo's permissions boundary);
# the service accounts come from the tenant chart (gitops/tenant).

locals {
  links = merge([
    for tenant, roles in var.tenants : {
      for sa, role in roles : "${tenant}/${sa}" => { namespace = tenant, service_account = sa, role = role }
    }
  ]...)
}

data "aws_iam_role" "pod" {
  for_each = local.links
  name     = each.value.role
}

resource "aws_eks_pod_identity_association" "this" {
  for_each = local.links

  cluster_name    = var.cluster_name
  namespace       = each.value.namespace
  service_account = each.value.service_account
  role_arn        = data.aws_iam_role.pod[each.key].arn
}
