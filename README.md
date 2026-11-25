# eks-platform

A shared EKS cluster for a small data team, built the way a platform team would run it:
Terraform creates the cluster, Argo CD installs everything else from git, and Karpenter
adds and removes nodes as work arrives. The first tenant is Airflow, running the pipelines
in [data-pipelines](https://github.com/amcaughan-personal/data-pipelines).

Why it's built this way, and what each choice gives up: [design decisions](docs/design-decisions.md).

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
        tenants/      each tenant's Pod Identity links, from gitops/tenants/
        bootstrap/    Argo CD, and the root app that points it at gitops/clusters/main/
  modules/            the few modules no community module covers
gitops/               everything Argo CD installs
  argocd/             Argo CD: the upstream chart's version and this platform's values
  root/               the one app a cluster starts from; points Argo CD at clusters/<name>/
  addons/             what every cluster runs: metrics-server, the tenants ApplicationSet
  tenant/             what every tenant team gets (a Helm chart)
  tenants/<name>/     one folder per tenant team: its repo, budget and pod roles
  clusters/
    main/             what the main cluster runs: the add-ons, Karpenter's node pool
    local/            what the local kind cluster runs: the add-ons that don't need AWS
scripts/
  cluster-down.sh     takes a cluster down and checks nothing is left behind
  apply-stack.sh      applies one stack, printing only its summary (CI)
  local-cluster.sh    a local kind cluster running Argo CD, for working on gitops/
```

Terraform creates only what has to exist before Argo CD can run (the cluster, Karpenter,
Argo CD itself). Argo CD installs everything else from `gitops/clusters/<name>/`, and keeps
the cluster matching it.

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

From GitHub: run the **cluster-up** workflow (Actions tab). It waits for approval (the
`cluster-up` environment), then applies `clusters/main` in about 15 minutes. Every night at
03:00 UTC, **cluster-down** takes the cluster down again, unless the `cluster-down`
environment's variable `KEEP_CLUSTER_UP` is `true`. Each runs in its own environment
(`cluster-up`, `cluster-down`) and signs in to AWS as the `cluster-lifecycle` role from
personal-infra, which can manage this cluster's resources and nothing else. Both log only
summary lines (this repo is public). cluster-up finishes once Argo CD's applications are
synced and healthy.

`KEEP_CLUSTER_UP`, like every GitHub setting in this org, comes from personal-infra: an SSM
parameter at `/github/eks-platform/cluster-down/KEEP_CLUSTER_UP` (value `true`) becomes that
environment's variable when personal-infra's GitHub stack is applied. Delete the parameter
and apply again to go back to nightly teardowns.

Or from the dev container:

```bash
cd /workspace/infra/terragrunt/live
terragrunt run --all --working-dir clusters/main -- apply
```

Argo CD follows `main`. To try a branch on the cluster, push it and set
`TF_VAR_revision=<branch>` on the apply. To reach Argo CD's UI:

```bash
aws eks update-kubeconfig --name main --region us-east-2
kubectl -n argocd port-forward svc/argocd-server 8080:80    # then http://localhost:8080
```

## Onboarding a team

A team that needs compute gets one folder, `gitops/tenants/<name>/values.yaml`, added in one
pull request:

```yaml
repo: https://github.com/amcaughan-personal/<their-repo>.git
path: k8s                                   # what Argo CD deploys from their repo
quota: { cpu: "8", memory: 32Gi, pods: "50" }
podRoles:                                   # service account -> IAM role in their repo
  workers: <name>-pod-workers
```

Argo CD then gives the team a namespace, that budget (and default pod sizes), and an Argo CD
project that deploys only from their repo, only into their namespace, and nothing
cluster-wide or that changes their budget. Their pods accept traffic only from their own
namespace, and can't use the system priorities to push other teams' pods off a node. From then on they ship by merging in their own
repo. The `clusters/<name>/tenants` stack links each service account to its IAM role
through Pod Identity; roles must be named `<name>-pod-*`, so a team can only get roles from
its own repo, and personal-infra's `cluster-lifecycle` role may pass exactly those.

A change that breaks the rules is refused whole (Argo CD shows why, and what's running
stays as it was); pods over the budget aren't created, and running ones keep running.

## Working on gitops/ locally

`scripts/local-cluster.sh up` creates a [kind](https://kind.sigs.k8s.io) cluster in Docker,
installs Argo CD with the same chart and values, and points it at `gitops/clusters/local/`
on the current branch (push it first). `scripts/local-cluster.sh down` deletes it. The dev
container needs the host's Docker: VS Code sets that up; with `docker run`, add
`--network host -v /var/run/docker.sock:/var/run/docker.sock --group-add $(getent group docker | cut -d: -f3)`.

## Take it down

From GitHub: run the **cluster-down** workflow. Or from the dev container:

```bash
cd /workspace
scripts/cluster-down.sh main
```

The script:

1. Deletes Argo CD's applications, which removes everything they installed (otherwise Argo CD
   would put back whatever is deleted next).
2. Deletes Karpenter's node pools and waits for its nodes to go: Terraform never knew about
   those instances, so `destroy` alone would leave them running.
3. Deletes network interfaces the VPC CNI left behind (they keep the node security group in
   use), then destroys the cluster's stacks. If the destroy stops on one, it cleans up and
   tries once more.
4. Checks for anything still tagged as the cluster's (instances, volumes, launch templates,
   security groups, network interfaces, load balancers, instance profiles), and fails if it
   finds any.

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

Every pull request also validates `gitops/` with kubeconform: each manifest and each
cluster's rendered kustomization against Kubernetes' schemas and, for custom resources such
as Argo CD Applications and Karpenter NodePools, their published schemas. Unknown fields
fail, so a misspelt setting is caught before Argo CD applies it. Pull requests that touch
`infra/` also get a Terragrunt plan comment, and `shared/` is checked for drift every
morning.
