# Design decisions

Why the platform is built the way it is, and what each choice gives up.

- [A shared cluster instead of MWAA](#a-shared-cluster-instead-of-mwaa)
- [Clusters are replaceable; what they stand on is not](#clusters-are-replaceable-what-they-stand-on-is-not)
- [Terraform bootstraps, Argo CD runs everything else](#terraform-bootstraps-argo-cd-runs-everything-else)
- [Karpenter on spot, self-managed](#karpenter-on-spot-self-managed)
- [Pod Identity, not IRSA](#pod-identity-not-irsa)
- [Up on approval, down every night, verified empty](#up-on-approval-down-every-night-verified-empty)
- [A CI role that can only do one job](#a-ci-role-that-can-only-do-one-job)
- [Onboarding a team is one folder](#onboarding-a-team-is-one-folder)
- [No NAT gateway](#no-nat-gateway)

## A shared cluster instead of MWAA

**Decision:** Airflow runs on a shared EKS cluster that a platform team operates, with the data
team as its first tenant, rather than on Amazon MWAA.

**Why:** for a single small team starting from nothing, MWAA is the simpler choice. The case
for self-hosting is a company that already runs a cluster: Airflow becomes one more Helm
release, on the same nodes, monitoring and GitOps as everything else. Each task runs as its own
pod (the KubernetesExecutor) with its own image, CPU and memory, and spot nodes appear only
while tasks need them.

**Trade-off:** the platform team owns Airflow's upgrades and its database, which MWAA would
handle.

## Clusters are replaceable; what they stand on is not

**Decision:** two layers. `shared/` (the VPC, log storage, every IAM role, Karpenter's queue)
stays up and costs about nothing. `clusters/<name>/` is one cluster, named after its folder,
and can be destroyed and rebuilt at any time.

**Why:** platform teams treat clusters as disposable: they rebuild one to recover, or upgrade by
standing up a second beside it. Keeping the IAM roles in `shared/` also means bringing a
cluster up or down never creates or deletes an IAM role, so the role that does it needs no IAM
write access at all.

**Trade-off:** a cluster's roles exist even while the cluster doesn't (harmless: unused roles
grant nothing).

## Terraform bootstraps, Argo CD runs everything else

**Decision:** Terraform creates only what must exist before Argo CD can run: the cluster,
Karpenter and Argo CD itself. Argo CD installs everything else from `gitops/` and keeps the
cluster matching git. The same Argo CD chart and values run on a local kind cluster for
working on `gitops/` without AWS, and every pull request validates the manifests against
their schemas, custom resources included.

**Why:** in-cluster software changes far more often than infrastructure. GitOps gives it
review, history and drift correction without a Terraform apply, and a cluster rebuilt from
nothing converges on its own.

**Trade-off:** two tools to understand, with a deliberate line between them.

## Karpenter on spot, self-managed

**Decision:** Karpenter launches nodes as pods need them (spot first, Graviton or x86) and
removes them five minutes after they empty, within a ceiling of 16 CPUs. It's installed and run
by the platform, not through EKS Auto Mode.

**Why:** capacity follows the work, so an idle cluster runs one small node. Running Karpenter
directly (its IAM, interruption queue and version upgrades) is the operational work Auto Mode
hides, and it avoids Auto Mode's per-instance fee, which AWS charges on top of EC2 regardless
of spot discounts.

**Trade-off:** more to maintain. A team optimising for low upkeep should choose Auto Mode and
accept the fee.

## Pod Identity, not IRSA

**Decision:** pods get AWS permissions through EKS Pod Identity. The cluster has no IAM OIDC
provider.

**Why:** IRSA ties each role's trust policy to one cluster's OIDC provider, which changes every
time a cluster is rebuilt. Pod Identity roles trust the EKS service instead, so they live in
`shared/` and work unchanged with every new cluster.

## Up on approval, down every night, verified empty

**Decision:** a cluster comes up from a GitHub workflow that waits for approval, and comes down
every night on its own unless asked to stay up. Teardown removes what controllers created
before destroying anything, then checks AWS for anything still tagged as the cluster's and fails
if it finds any.

**Why:** a forgotten cluster costs about $100 a month. Terraform can't see what runs inside the
cluster creates (Karpenter's instances, leftover network interfaces), so `destroy` alone leaves
them running. Checking afterwards turns "probably clean" into "verified clean".

**Trade-off:** each bring-up takes about 15 minutes, and a cluster wanted overnight has to be
flagged.

## A CI role that can only do one job

**Decision:** one IAM role brings clusters up and down. It trusts only the two workflow files
that do so, each in its own GitHub environment (bring-up's needs approval). It can manage only
this cluster's EKS resources and EC2 resources tagged as this cluster's, and pass only the
cluster's existing roles. Its permissions were confirmed against real bring-ups and teardowns
and the IAM policy simulator.

**Why:** a role that can create and delete clusters is powerful. Checking the environment
*and* the workflow file means no other workflow, even one added later, can use it, and tag
scoping keeps it away from everything else in the account.

**Trade-off:** a wider change (a second cluster, a new kind of resource) needs a deliberate
change to the role.

## Onboarding a team is one folder

**Decision:** a team that needs compute gets a folder, `gitops/tenants/<name>/`, in one pull
request. From it, Argo CD gives the team a namespace with a budget, default pod sizes, an
Argo CD project that deploys only from their repo into their namespace, and isolation from
other teams' traffic and from the system priorities; Terraform links their service accounts
to IAM roles in their own repo through Pod Identity.

**Why:** teams ship by merging in their own repo, without tickets, while the platform owns
the limits. Rather than approving each team's AWS access separately, personal-infra
delegates one bounded rule: the CI role may hand pods any role named `*-pod-*`, and only to
Pod Identity. Every such role carries its repo's permissions boundary, and the tenants stack
refuses a team whose pod roles aren't named after it, so a team can only get its own roles.

**Trade-off:** namespaces are a policy boundary, not hardware: teams share nodes and the
Kubernetes version. A team needing stronger isolation (regulated data, its own upgrade pace)
gets its own cluster, another folder under `clusters/`.

## No NAT gateway

**Decision:** nodes run in public subnets with public IPs. Their security groups allow no
inbound traffic from the internet.

**Why:** a NAT gateway costs about $32 a month before any traffic, more than everything else
here combined while the cluster is down. Without inbound rules, a public IP only lets nodes
reach out (to pull images and call AWS).

**Trade-off:** many organisations require private subnets as policy. Moving to them means adding
a NAT gateway or VPC endpoints to `shared/network`, with no change to the clusters.
