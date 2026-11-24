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
    clusters/
      main/           one cluster
  modules/            the few modules no community module covers
```

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

## Tear down everything

Clusters first, then what they stand on. Each step is safe to rerun.

```bash
cd /workspace/infra/terragrunt/live
terragrunt run --all --working-dir clusters -- destroy
terragrunt run --all --working-dir shared -- destroy
```

`shared/` costs nothing while idle (no NAT gateway, an empty bucket, empty log groups), so
leaving it up between clusters is fine. The task-log bucket is emptied on destroy.

## Checks

Every pull request runs the org's shared security scan: leaked secrets (gitleaks),
vulnerable dependencies (Trivy), workflow problems (actionlint) and infrastructure
misconfigurations (Checkov). `pre-commit install` adds the same secret check to every
local commit.
