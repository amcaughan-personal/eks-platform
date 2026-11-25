# Argo CD (gitops/argocd), and the one Application it starts from: gitops/root, which points it at
# gitops/clusters/<cluster>/. Everything else on the cluster comes from there. The same
# chart and values run on the local kind cluster (scripts/local-cluster.sh).

resource "helm_release" "argocd" {
  name              = "argocd"
  namespace         = "argocd"
  create_namespace  = true
  chart             = "${var.gitops_dir}/argocd"
  dependency_update = true
}

resource "helm_release" "root" {
  name      = "root"
  namespace = "argocd"
  chart     = "${var.gitops_dir}/root"

  set = [
    { name = "cluster", value = var.cluster_name },
    { name = "revision", value = var.revision },
  ]

  depends_on = [helm_release.argocd]
}
