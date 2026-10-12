# ECS Fargate Service — Terraform

Plan-ready Terraform for running a web service on ECS Fargate. Nothing here
is meant to be applied as-is: the goal is a clean, reusable structure where
`terraform init` / `terraform plan` work and every production concern
(networking, secrets, scaling, HA) is wired up and visible.

```
environments/prod ──► module.vpc (terraform-aws-modules/vpc)
                  ──► aws_ecs_cluster
                  ──► module.app (modules/ecs-service)
                          ├── ALB + target group + listener (public subnets)
                          ├── ECS service + task definition (private subnets)
                          ├── security groups (+ rule into the existing Redis SG)
                          ├── Secrets Manager secret (value set out-of-band)
                          ├── IAM execution / task roles
                          ├── CloudWatch log group
                          └── Application Auto Scaling (CPU + ALB request count)

external:  ElastiCache Redis replication group (referenced, not created)
state:     S3 backend with native locking (created by bootstrap.py)
```

## What's provided

- **One reusable module** — `modules/ecs-service`: a complete Fargate web
  service (ALB, task definition, service, IAM, SGs, logs, autoscaling) that
  any environment can instantiate with different sizing.
- **Networking** — the off-the-shelf `terraform-aws-modules/vpc` module;
  prod spans 3 AZs with a NAT gateway per AZ.
- **One secret from Secrets Manager** — the module creates the secret and
  injects it into the container as `APP_SECRET` via the task's `secrets`
  block and execution role.
- **ElastiCache Redis connectivity** — the replication group is *not*
  managed here; the module adds a security-group rule (app SG → Redis SG on
  6379) and hands the endpoint to the container via `REDIS_HOST`. See
  [Redis connectivity](#redis-connectivity--why-it-would-work).
- **Autoscaling** — Application Auto Scaling target tracking on CPU
  (baseline) and ALB request count per target (prod).
- **Plan-ready backend** — S3 + native lockfile (`use_lockfile`), bucket
  created and hardened by `bootstrap.py`.

## Prerequisites

- Terraform `~> 1.11`
- An AWS CLI profile named `ecs-prod` with credentials for the target
  account (see the header of `bootstrap.py` for the expected file format)
- One-time backend bootstrap:

```bash
python bootstrap.py   # creates + hardens the ecs-prod-tfstate S3 bucket
```

## How to run

```bash
cd environments/prod
terraform init
terraform plan
```

A real `plan` requires valid AWS credentials for the `ecs-prod` profile —
there is no fully offline plan. For a pure syntax/shape check without any
credentials:

```bash
terraform init -backend=false
terraform validate
terraform fmt -check
```

The Redis endpoint and security group ID in `terraform.tfvars` are
deliberate placeholders (`dummy.prod.cache.amazonaws.com`,
`sg-00000000000000000`). `terraform plan` does not validate them; drop in
the real values of the existing replication group before any `apply`.

## Architecture decisions & trade-offs

| Decision | Why | Trade-off |
|---|---|---|
| Off-the-shelf VPC module | Battle-tested subnets/NAT/route tables; HA toggles are single flags | External version pin to track |
| ALB in front of the service | Real HTTP health checks, stable endpoint, enables request-count autoscaling | ~$16/mo + LCU even when idle; HTTP only (no ACM yet) |
| Secret as a **resource**, not a data source | A data source makes `plan` fail if the secret doesn't exist yet | Terraform "owns" the secret object; value managed out-of-band |
| Secret permission on the **execution** role | The ECS agent injects secrets at task start, not the app | Common confusion point — the task role stays empty until the app needs AWS API access |
| CPU target tracking as the baseline | Works with zero traffic and zero extra infra | CPU is a lagging proxy for offered load on web apps |
| + `ALBRequestCountPerTarget` in prod | Scales directly on requests per task — the better web signal | Noisy at low request rates (dev), requires the ALB; with multiple policies, scale-out follows whichever demands more |
| Cluster at the environment root | A cluster is env-scoped shared capacity; a second service joins it without restructuring | One more resource outside the module |
| `ignore_changes = [desired_count]` | Autoscaling owns the count after creation; keeps plans clean | Manual count changes must go through autoscaling, not tfvars |
| `recovery_window_in_days = 0` on the secret | No 7–30 day deletion lock while experimenting | No recovery window if deleted — raise it for real workloads |
| NAT per AZ in prod | Survives an AZ loss; tasks also need NAT for image pull + Secrets Manager + CloudWatch | ~3× NAT cost vs a single shared NAT |
| No data sources that touch AWS APIs | `plan` can't fail on lookups of things that don't exist | Redis SG / endpoint are plain variables, not validated |

## Redis connectivity — why it would work

The replication group is assumed to live in the **same VPC** (its endpoint
resolves to ENIs there). Given that, the path is complete:

1. **Ingress**: `aws_security_group_rule.redis_ingress` authorizes the app
   tasks' security group to reach the Redis security group on port 6379.
   Security groups are stateful, so reply traffic flows automatically.
2. **Egress**: the app tasks' security group allows all outbound traffic.
3. **Addressing**: the endpoint reaches the container through the
   `REDIS_HOST` / `REDIS_PORT` environment variables in the task definition.

If the existing Redis actually lives in a *different* VPC, SG-to-SG rules
don't apply — you'd need VPC peering or a Transit Gateway (see
[future work](#what-id-add-with-more-time)).

In a real service the Redis **auth token** (and arguably the endpoint too)
would ride in the same Secrets Manager secret as a JSON blob, selected with
`valueFrom = "<arn>:key::"`. The endpoint is passed as a plain env var here
because it isn't sensitive and the requirement asks for exactly one secret.

## Secrets flow

- The module creates `/prod/app/app-secret` and grants
  `secretsmanager:GetSecretValue` on it to the **execution role** only.
- The ECS agent resolves the `secrets` block at task start and exposes the
  value as the `APP_SECRET` environment variable inside the container.
- The value is intentionally **not** in `terraform.tfvars`. Set it
  out-of-band after apply:

```bash
aws secretsmanager put-secret-value --profile ecs-prod \
  --secret-id /prod/app/app-secret \
  --secret-string '{"redis_auth_token":"..."}'
```

(If the secret were encrypted with a customer-managed KMS key, the execution
role would also need `kms:Decrypt` — a commented statement in
`modules/ecs-service/iam.tf` marks the spot.)

## Dev vs prod

Only `environments/prod` exists, but every difference is a variable — a dev
environment is the same root module with a different backend block and
tfvars. 

## What I'd add with more time

- **HTTPS**: ACM certificate, 443 listener, HTTP→HTTPS redirect.
- **VPC endpoints** (Secrets Manager, ECR, CloudWatch Logs): cut NAT
  traffic/cost and remove the internet dependency for AWS API calls.
- **Redis auth token in the secret** with JSON key selectors, and a container
  that actually uses it (the current image is a placeholder nginx).
- **ECR repo + image scanning** instead of a public image.
- **Blue/green deployments** via CodeDeploy for ECS.
- **Alarms**: ALB 5xx, unhealthy targets, CPU/memory, plus SNS notification.
- **WAF** on the ALB and ALB access logs to S3.
- **CI**: `fmt` / `validate` / `plan` in GitHub Actions with OIDC (no stored
  AWS keys), plus `tflint`.
- **Raise `recovery_window_in_days`** on the secret for anything real.
- **VPC peering / TGW** if the Redis replication group lives in another VPC.
- **Multi-service support** — the module already allows it: instantiate
  `module.app` again with a different `name` against the same cluster/VPC.
