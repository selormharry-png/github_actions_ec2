# Terraform EC2 with a DevSecOps GitHub Actions Pipeline

Provisions an EC2 instance on AWS (with its own VPC, public subnet and security group) using Terraform, and deploys it through a GitHub Actions pipeline that scans for secrets and misconfigurations before anything is planned or applied.

## What gets deployed

The root configuration calls the [`selormharry-png/ec2/aws`](https://registry.terraform.io/modules/selormharry-png/ec2/aws) module (v1.0.3), which creates:

- A VPC
- A public subnet
- A security group
- An EC2 instance attached to an existing SSH key pair

Default region: `eu-central-1` (set in the workflow).

## Repository layout

```
.
├── .github/workflows/terraform.yml   # CI/CD pipeline
├── .pre-commit-configuration-yaml    # Local pre-commit hooks
├── .gitignore                        # Ignores state, plans, .terraform/, *.tfvars
├── main.tf                           # EC2 module call
├── variables.tf                      # Input variables
└── output.tf                         # Outputs
```

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
| **iac-scan** | Checkov | Static security scan; fails on findings and uploads SARIF to the GitHub **Security** tab |
| **plan** | Terraform | Runs `terraform plan` and uploads the plan file as an artifact (kept 5 days) |
| **apply** | Terraform | Applies the exact saved plan; runs only on a push to `main` |

Runs on the same ref are queued rather than cancelled, so two applies never overlap.

### Pipeline configuration

| Setting | Where | Value |
|---------|-------|-------|
| `AWS_REGION` | workflow `env` | `eu-central-1` |
| `TF_VERSION` | workflow `env` | `1.10.5` |
| `TF_DIR` | workflow `env` | Directory holding the Terraform code |
| `AWS_ROLE_ARN` | repository secret | IAM role assumed via GitHub OIDC |

## Prerequisites

1. **An AWS IAM role for GitHub OIDC.** The pipeline uses short-lived credentials, not access keys. Create an OIDC identity provider for `token.actions.githubusercontent.com` in your AWS account and a role that trusts it for this repository. Grant the role permissions to manage VPC, EC2 and security group resources.
2. **The `AWS_ROLE_ARN` secret.** Add the role ARN under *Settings → Secrets and variables → Actions*.
3. **An EC2 key pair** in the target region whose name matches `key_name` (default `safe_key`).
4. **Code scanning enabled** on the repository so the Checkov SARIF upload succeeds.

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
| `ssh_command` | SSH helper output |

## Running locally

```bash
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

Clean up when finished:

```bash
terraform destroy
```

## Pre-commit hooks

The repo ships a [pre-commit](https://pre-commit.com/) configuration that runs the same checks locally before each commit: whitespace and YAML checks, AWS credential and private key detection, Gitleaks, `terraform fmt`, `terraform validate`, TFLint and Checkov.

Pre-commit looks for a file named `.pre-commit-config.yaml`, so rename the config file before installing:

```bash
mv .pre-commit-configuration-yaml .pre-commit-config.yaml
pip install pre-commit
pre-commit install
pre-commit run --all-files
```

You also need `terraform`, `tflint`, `checkov` and `gitleaks` on your `PATH`.

## Security notes

- State and plan files (`*.tfstate`, `tfplan`) and variable files (`*.tfvars`) are git-ignored because they can contain sensitive values.
- AWS access uses OIDC role assumption; no long-lived keys are stored in GitHub.
- Workflow permissions default to `contents: read`; jobs request `id-token: write` or `security-events: write` only where needed.
