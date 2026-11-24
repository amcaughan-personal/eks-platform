# Karpenter itself, on the system nodes. It signs in to AWS as its controller role through
# EKS Pod Identity. Its node pools and node classes are Kubernetes objects, kept in
# gitops/clusters/<name>/karpenter/.

resource "aws_eks_pod_identity_association" "karpenter" {
  cluster_name    = var.cluster_name
  namespace       = "kube-system"
  service_account = "karpenter"
  role_arn        = var.controller_role_arn
}

resource "helm_release" "karpenter" {
  name       = "karpenter"
  namespace  = "kube-system"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = var.chart_version

  values = [yamlencode({
    settings = {
      clusterName       = var.cluster_name
      interruptionQueue = var.queue_name
    }
    # One replica fits the single system node; Karpenter keeps working nodes running
    # while it restarts.
    replicas = 1
    controller = {
      resources = {
        requests = { cpu = "250m", memory = "512Mi" }
        limits   = { memory = "512Mi" }
      }
    }
  })]

  depends_on = [aws_eks_pod_identity_association.karpenter]
}
