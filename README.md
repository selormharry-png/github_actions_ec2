# Terraform EC2 with a DevSecOps GitHub Actions Pipeline

Provisions an EC2 instance on AWS (with its own VPC, public subnet and security group) using Terraform, and deploys it through a GitHub Actions pipeline that scans for secrets and misconfigurations before anything is planned or applied. Terraform state is stored remotely in an encrypted, versioned S3 bucket with native state locking.

## What gets deployed

The project has two Terraform configurations:

| Configuration | Location | Run by | Creates |
|---------------|----------|--------|---------|
| **Bootstrap** | [`bootstrap/`](bootstrap/) | You, once, locally | The S3 bucket that stores Terraform state |
| **Main** | repo root | The GitHub Actions pipeline | VPC, public subnet, security group and EC2 instance |

The main configuration calls the [`selormharry-png/ec2/aws`](https://registry.terraform.io/modules/selormharry-png/ec2/aws) module (v1.0.3).

Region: `eu-central-1`.

## Repository layout

```
.
├── .github/workflows/terraform.yml   # CI/CD pipeline
├── .pre-commit-config.yaml           # Local pre-commit hooks
├── .gitignore                        # Ignores state, plans, .terraform/, *.tfvars
├── backend.tf                        # S3 remote state backend
├── versions.tf                       # Terraform and AWS provider version constraints
├── main.tf                           # EC2 module call
├── variables.tf                      # Input variables
├── output.tf                         # Outputs
└── bootstrap/                        # One-time setup of the state bucket
    ├── providers.tf
    ├── main.tf
    ├── variables.tf
    └── output.tf
```

## Remote state

State for the main configuration is kept in S3 ([`backend.tf`](backend.tf)):

| Setting | Value |
|---------|-------|
| Bucket | `securejambo14` |
| Key | `github_actions_ec2/terraform.tfstate` |
| Region | `eu-central-1` |
| Locking | S3 native lock file (`use_lockfile = true`, Terraform ≥ 1.10) |

The bootstrap configuration creates and hardens that bucket:

- Versioning enabled, so earlier state versions can be recovered
- Server-side encryption with KMS (AWS-managed `aws/s3` key, S3 Bucket Key enabled)
- All public access blocked; ACLs disabled (`BucketOwnerEnforced`)
- Bucket policy that denies any request not made over HTTPS
- Lifecycle rule that expires old state versions after 90 days and aborts incomplete uploads after 7 days
- `prevent_destroy` so the bucket cannot be deleted by `terraform destroy`

## Pipeline

The workflow `Terraform DevSecOps` runs on pushes and pull requests to `main` (Markdown and `.gitignore` changes are ignored), and can be started manually with `workflow_dispatch`.

```
secrets-scan ─┐
lint ─────────┼──► plan ──► apply (push to main only)
iac-scan ─────┘
```

| Job | Tooling | Purpose |
|-----|---------|---------|
| **secrets-scan** | Gitleaks | Scans the full git history for committed keys, tokens and passwords |
| **lint** | `terraform fmt`, `terraform validate`, TFLint | Formatting, syntax and best-practice checks |
| **iac-scan** | Checkov | Static security scan of this repo's code and the downloaded EC2 module; results are uploaded as SARIF to the GitHub **Security** tab |
| **plan** | Terraform | Runs `terraform plan` against the S3 state and uploads the plan file as an artifact (kept 5 days) |
| **apply** | Terraform | Applies the exact saved plan; runs only on a push to `main` |

Runs on the same ref are queued rather than cancelled, so two applies never overlap.

### Pipeline configuration

| Setting | Where | Value |
|---------|-------|-------|
| `AWS_REGION` | workflow `env` | `eu-central-1` |
| `TF_VERSION` | workflow `env` | `1.10.5` |
| `TF_DIR` | workflow `env` | `.` (Terraform code is at the repo root) |
| `AWS_ROLE_ARN` | repository secret | IAM role assumed via GitHub OIDC |

### Checkov

Checkov currently runs with `soft_fail: true`: findings are reported in the log and the Security tab, but they do not stop the pipeline. Set it to `false` to make findings block Plan and Apply.

`download_external_modules: true` makes Checkov also scan the resources inside the registry EC2 module, not just the files in this repo.

Checks that do not apply to this project are skipped inline, each with a reason, next to the resource they relate to:

| Check | Resource | Reason |
|-------|----------|--------|
| `CKV_TF_1` | `module.ec2` | Registry modules are pinned by version; commit hashes only apply to git sources |
| `CKV_AWS_18` | state bucket | Access logging not required for a single-user state bucket |
| `CKV_AWS_144` | state bucket | Cross-region replication not required for this project |
| `CKV2_AWS_62` | state bucket | No consumers for S3 event notifications |

## Prerequisites

- Terraform `>= 1.10.5` and the AWS CLI installed locally
- An AWS CLI profile with permissions to create S3 buckets (used by bootstrap)
- **An EC2 key pair** in `eu-central-1` whose name matches `key_name` (default `safe_key`)
- **An AWS IAM role for GitHub OIDC.** The pipeline uses short-lived credentials, not access keys. Create an OIDC identity provider for `token.actions.githubusercontent.com` and a role that trusts it for this repository. The role needs permissions to manage VPC, EC2 and security group resources, and read/write access to the state bucket.
- **The `AWS_ROLE_ARN` repository secret**, set under *Settings → Secrets and variables → Actions*
- **Code scanning enabled** on the repository so the Checkov SARIF upload succeeds

## Setup

### 1. Create the state bucket (once)

The bootstrap configuration uses the local AWS CLI profile set in `aws_profile_name` ([`bootstrap/variables.tf`](bootstrap/variables.tf)). Change it, and `bucket_name` if needed, since S3 bucket names are globally unique.

```bash
cd bootstrap
terraform init
terraform plan
terraform apply
```

Bootstrap's own state stays local in `bootstrap/terraform.tfstate`. It is git-ignored; keep it somewhere safe.

If you change `bucket_name`, update `bucket` in [`backend.tf`](backend.tf) to match.

### 2. Initialise the main configuration

From the repo root:

```bash
terraform init
```

If you already have local state from an earlier run, use `terraform init -migrate-state` to copy it into the bucket, then delete the local `terraform.tfstate`.

### 3. Deploy

Push to `main` and the pipeline scans, plans and applies. Pull requests to `main` run the scans and the plan, but not apply.

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `environment` | Environment to deploy to | `string` | `dev` |
| `instance_type` | EC2 instance type | `string` | `t3.micro` |
| `key_name` | Name of an existing EC2 key pair for SSH | `string` | `safe_key` |
| `project_name` | Name used for the EC2 instance and resources | `string` | `duplicate12` |
| `vpc_cidr` | VPC CIDR block | `string` | `10.0.0.0/16` |
| `public_subnet_cidr` | Public subnet CIDR block | `string` | `10.0.1.0/24` |

Override defaults with a `terraform.tfvars` file (git-ignored) or `-var` flags.

## Outputs

| Name | Description |
|------|-------------|
| `instance_id` | EC2 instance ID |
| `instance_public_ip` | Public IP of the instance |
| `public_subnet_id` | Public subnet ID |
| `security_group_id` | Security group ID |
| `vpc_id` | VPC ID |
| `ssh_command` | Command to SSH into the instance |

## Running locally

From the repo root, with AWS credentials for `eu-central-1` in your environment:

```bash
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

## Clean up

Destroy the EC2 resources from the repo root:

```bash
terraform destroy
```

The state bucket is protected by `prevent_destroy`. To remove it, first delete the `lifecycle` block in [`bootstrap/main.tf`](bootstrap/main.tf), empty the bucket (including all object versions), then run `terraform destroy` in `bootstrap/`.

## Pre-commit hooks

[`.pre-commit-config.yaml`](.pre-commit-config.yaml) runs the same checks locally before each commit: whitespace and YAML checks, AWS credential and private key detection, Gitleaks, `terraform fmt`, `terraform validate`, TFLint and Checkov.

```bash
pip install pre-commit
pre-commit install
pre-commit run --all-files
```

You also need `terraform`, `tflint`, `checkov` and `gitleaks` on your `PATH`.

## Security notes

- State and plan files (`*.tfstate`, `tfplan`) and variable files (`*.tfvars`) are git-ignored because they can contain sensitive values.
- Remote state is encrypted at rest with KMS, only reachable over HTTPS, versioned and locked during writes.
- AWS access from the pipeline uses OIDC role assumption; no long-lived keys are stored in GitHub.
- Workflow permissions default to `contents: read`; jobs request `id-token: write` or `security-events: write` only where needed.
