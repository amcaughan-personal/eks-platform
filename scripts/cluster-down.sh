#!/usr/bin/env bash
# Takes a cluster down and checks nothing is left behind. Run from the repo root in the dev
# container. Safe to rerun.
#
#   scripts/cluster-down.sh [cluster]    (default: main)
#
# 1. Deletes Karpenter's node pools and node classes, and waits for its nodes to go.
#    Terraform never knew about those EC2 instances, so it can't remove them.
# 2. Destroys the cluster's Terraform stacks.
# 3. Sweeps for anything still tagged as this cluster's, and fails if it finds any.
set -euo pipefail

cluster="${1:-main}"
region="us-east-2"
live="infra/terragrunt/live"
export AWS_REGION="$region"

if aws eks describe-cluster --name "$cluster" >/dev/null 2>&1; then
  export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"
  aws eks update-kubeconfig --name "$cluster" --region "$region" >/dev/null
  if kubectl get crd nodepools.karpenter.sh >/dev/null 2>&1; then
    echo "Removing Karpenter's nodes..."
    kubectl delete nodepools --all --wait=true --timeout=10m
    kubectl delete ec2nodeclasses --all --wait=true --timeout=10m
  fi
fi

terragrunt run --all --non-interactive --working-dir "$live/clusters/$cluster" -- destroy -auto-approve

echo "Checking for leftovers..."
leftovers=0
check() {
  local what="$1" count="$2"
  if [ "$count" != "0" ]; then
    echo "  LEFT BEHIND: $count $what"
    leftovers=1
  fi
}
check "EKS cluster" "$(aws eks list-clusters --query "length(clusters[?@=='$cluster'])")"
check "EC2 instances" "$(aws ec2 describe-instances --filters "Name=tag:Cluster,Values=$cluster" "Name=instance-state-name,Values=pending,running,stopping,stopped" --query 'length(Reservations[].Instances[])')"
check "EC2 instances (EKS-tagged)" "$(aws ec2 describe-instances --filters "Name=tag:eks:cluster-name,Values=$cluster" "Name=instance-state-name,Values=pending,running,stopping,stopped" --query 'length(Reservations[].Instances[])')"
check "EBS volumes" "$(aws ec2 describe-volumes --filters "Name=tag:Cluster,Values=$cluster" --query 'length(Volumes)')"
check "EBS volumes (Kubernetes-created)" "$(aws ec2 describe-volumes --filters "Name=tag-key,Values=kubernetes.io/cluster/$cluster" --query 'length(Volumes)')"
check "launch templates" "$(aws ec2 describe-launch-templates --filters "Name=tag:karpenter.k8s.aws/cluster,Values=$cluster" --query 'length(LaunchTemplates)')"
check "security groups" "$(aws ec2 describe-security-groups --filters "Name=tag:Cluster,Values=$cluster" --query 'length(SecurityGroups)')"
check "network interfaces" "$(aws ec2 describe-network-interfaces --filters "Name=tag:cluster.k8s.amazonaws.com/name,Values=$cluster" --query 'length(NetworkInterfaces)')"
check "load balancers" "$(aws elbv2 describe-load-balancers --query 'length(LoadBalancers)' 2>/dev/null || echo 0)"
check "instance profiles" "$(aws iam list-instance-profiles --query "length(InstanceProfiles[?starts_with(InstanceProfileName, '${cluster}_')])")"

if [ "$leftovers" = "1" ]; then
  echo "Cluster $cluster is down, but the resources above were left behind."
  exit 1
fi
echo "Cluster $cluster is down. Nothing left behind."
