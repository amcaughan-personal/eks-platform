# Argo CD, and the one Application it starts from: gitops/argocd/root, which points it at
# gitops/clusters/<cluster>/. Everything else on the cluster comes from there. The same
# chart and values run on the local kind cluster (scripts/local-cluster.sh).

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version

  values = [file("${var.gitops_dir}/argocd/values.yaml")]
}

resource "helm_release" "root" {
  name      = "root"
  namespace = "argocd"
  chart     = "${var.gitops_dir}/argocd/root"

  set = [
    { name = "cluster", value = var.cluster_name },
    { name = "revision", value = var.revision },
  ]

  depends_on = [helm_release.argocd]
}
