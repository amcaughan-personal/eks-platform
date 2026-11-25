#!/usr/bin/env bash
# A local Kubernetes cluster (kind, in Docker) running Argo CD, for working on gitops/
# without EKS. Argo CD syncs gitops/clusters/local/ from GitHub, so push the branch first.
# Run from the repo root in the dev container, with the host's Docker socket (see README).
#
#   scripts/local-cluster.sh up [branch]   (default: the current branch)
#   scripts/local-cluster.sh down
set -euo pipefail

name="eks-platform-local"

case "${1:-}" in
  up)
    branch="${2:-$(git rev-parse --abbrev-ref HEAD)}"
    kind get clusters 2>/dev/null | grep -qx "$name" || kind create cluster --name "$name" --wait 2m
    kubectl config use-context "kind-$name" >/dev/null

    helm dependency update gitops/argocd >/dev/null
    helm upgrade --install argocd gitops/argocd \
      --namespace argocd --create-namespace --wait --timeout 5m

    helm upgrade --install root gitops/root --namespace argocd \
      --set cluster=local --set revision="$branch"

    echo "Argo CD is syncing gitops/clusters/local/ from branch $branch."
    echo "UI: kubectl -n argocd port-forward svc/argocd-server 8080:80, then http://localhost:8080"
    echo "    (user admin, password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
    ;;
  down)
    kind delete cluster --name "$name"
    ;;
  *)
    echo "usage: $0 up [branch] | down" >&2
    exit 2
    ;;
esac
