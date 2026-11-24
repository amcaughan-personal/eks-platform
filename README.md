# eks-platform

A shared EKS cluster for a small data team, built the way a platform team would run it:
Terraform creates the cluster, Argo CD installs everything else from git, and Karpenter
adds and removes nodes as work arrives. The first tenant is Airflow, running the pipelines
in [data-pipelines](https://github.com/amcaughan-personal/data-pipelines).

## Layout

```
infra/terragrunt/
  root.hcl            state backend, tags (Repo, Stack), tool versions
  live/
    platform.hcl      values every stack shares: the platform's name, its clusters
    shared/           what every cluster stands on, kept between clusters
      network/        VPC, public subnets in three zones, no NAT gateway
      logs/           Airflow task-log bucket, per-cluster log groups
      iam/            each cluster's control-plane and node roles
      karpenter/      each cluster's Karpenter controller role and interruption queue
    clusters/
      main/
        cluster.hcl   its name and Kubernetes version; tags everything Cluster = main
        eks/          control plane, a small system node group, core add-ons
        karpenter/    Karpenter, signed in to AWS through EKS Pod Identity
  modules/            the few modules no community module covers
gitops/
  clusters/main/      Kubernetes objects for one cluster, e.g. Karpenter's node pool
scripts/
  cluster-down.sh     takes a cluster down and checks nothing is left behind
```

Karpenter adds nodes when pods don't fit on the system nodes (spot first, Graviton or
x86) and removes them five minutes after they empty.

Clusters are replaceable: rebuilding one, or upgrading by standing up a second beside
it, never touches `shared/`.

## Running it

Terragrunt runs in the dev container (`.devcontainer/`), with `~/.aws` mounted:

```bash
docker build -f .devcontainer/Dockerfile -t eks-platform-dev .
docker run --rm -it -v "$PWD:/workspace" -v "$HOME/.aws:/home/dev/.aws" -e AWS_PROFILE=default eks-platform-dev
cd /workspace/infra/terragrunt/live
terragrunt run --all -- plan
```

## Bring a cluster up

About 15 minutes, from the dev container:

```bash
cd /workspace/infra/terragrunt/live
terragrunt run --all --working-dir clusters/main -- apply
aws eks update-kubeconfig --name main --region us-east-2
kubectl apply --recursive -f /workspace/gitops/clusters/main/
```

## Take it down

```bash
cd /workspace
scripts/cluster-down.sh main
```

The script first deletes Karpenter's node pools and waits for its nodes to go: Terraform
never knew about those instances, so `destroy` alone would leave them running. Then it
destroys the cluster's stacks, and finally checks for anything still tagged as the
cluster's (instances, volumes, launch templates, security groups, network interfaces,
load balancers, instance profiles), failing if it finds any.

`shared/` costs nothing while idle (no NAT gateway, an empty bucket, empty log groups, an
idle queue), so it stays up between clusters. To remove it too, after every cluster is
down:

```bash
cd /workspace/infra/terragrunt/live
terragrunt run --all --working-dir shared -- destroy
```

## Checks

Every pull request runs the org's shared security scan: leaked secrets (gitleaks),
vulnerable dependencies (Trivy), workflow problems (actionlint) and infrastructure
misconfigurations (Checkov). `pre-commit install` adds the same secret check to every
local commit.
