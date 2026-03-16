# Spring Boot Three-Tier Infrastructure — Terraform

> Full AWS infrastructure for a Spring Boot application, reproduced from the architecture diagram:  
> **GoDaddy DNS → CloudFront + WAF → ALB → Frontend ASG → NLB → Backend ASG → RDS (MySQL)**  
> Application data is stored on **S3** (frontend static assets + backend app data/artifacts).

---

## Architecture Overview

```
Internet
   │
[GoDaddy DNS]
   │
[CloudFront]  ←── AWS WAF (CRS + SQLi + Rate-limit)
   │            ←── ACM Certificate (us-east-1)
   │
[Application Load Balancer]  (internet-facing, public subnets)
   │   └─ HTTPS listener → Frontend Target Group
   │
[Frontend ASG]  (private subnets)
   │   FE Linux Service  +  systemd
   │   ↕ CloudWatch Agent → CW Log Group → Metric Filter → CW Alarm
   │   ↕ Lifecycle Hook (drain on scale-in)
   │   ↕ Scheduled scaling (cost-cutting cron)
   │   ↕ S3 (frontend-app.jar pulled on boot)
   │
[Network Load Balancer]  (internal, private subnets)
   │
[Backend ASG]  (private subnets)
   │   Spring Boot app  +  systemd
   │   ↕ CloudWatch Agent → CW Log Group → Metric Filter → CW Alarm
   │   ↕ Lifecycle Hook (drain on scale-in)
   │   ↕ Scheduled scaling (cost-cutting cron)
   │   ↕ S3 (backend-app.jar + app data)
   │
[Amazon RDS MySQL]  (isolated DB subnets, DB Subnet Group)
   │
[CloudWatch Alarms] → [SNS Topic] → [Email subscription]
                                  → [Lambda] → [Slack]
                                  → [CloudWatch Log Group (Lambda)]
```

---

## Project Structure

```
terraform/
├── providers.tf            # AWS provider, backend (S3 + DynamoDB)
├── variables.tf            # All input variables
├── modules.tf              # Root module – wires all child modules
├── outputs.tf              # All root-level outputs
├── Makefile                # Workflow shortcuts
├── .gitignore
│
├── environments/
│   ├── dev.tfvars          # Dev environment values
│   └── prod.tfvars         # Prod environment values
│
└── modules/
    ├── vpc/                # VPC, subnets, IGW, NAT, route tables, flow logs
    ├── security_groups/    # ALB, frontend, backend, RDS security groups
    ├── iam/                # EC2 instance profiles + Lambda execution role
    ├── acm/                # ACM TLS certificate (us-east-1)
    ├── waf/                # WAF v2 WebACL (CloudFront scope)
    ├── s3/                 # Frontend assets bucket + Backend data bucket
    ├── alb/                # Internet-facing ALB + target group + listeners
    ├── nlb/                # Internal NLB + backend target group
    ├── frontend_asg/       # Launch Template, ASG, scheduled + dynamic scaling
    ├── backend_asg/        # Launch Template, ASG, scheduled + dynamic scaling
    ├── rds/                # RDS MySQL, parameter group, subnet group
    ├── cloudwatch/         # Log groups, metric filters, CW alarms, dashboard
    ├── sns/                # SNS topic + email subscription
    ├── lambda/             # Python Lambda – SNS → Slack relay
    └── cloudfront/         # CloudFront distribution, OAI, cache behaviours
```

---

## Prerequisites

| Tool          | Minimum version |
|---------------|-----------------|
| Terraform     | 1.5.0           |
| AWS CLI       | 2.x             |
| Python        | 3.12 (Lambda build only) |

### AWS resources required before first apply

1. **S3 bucket for Terraform state** – create manually:
   ```bash
   aws s3 mb s3://springboot-terraform-state --region ap-south-1
   aws s3api put-bucket-versioning \
     --bucket springboot-terraform-state \
     --versioning-configuration Status=Enabled
   ```

2. **DynamoDB table for state locking**:
   ```bash
   aws dynamodb create-table \
     --table-name terraform-state-lock \
     --attribute-definitions AttributeName=LockID,AttributeType=S \
     --key-schema AttributeName=LockID,KeyType=HASH \
     --billing-mode PAY_PER_REQUEST \
     --region ap-south-1
   ```

3. **EC2 Key Pair** (optional, for SSH access):
   ```bash
   aws ec2 create-key-pair \
     --key-name springboot-dev-key \
     --query 'KeyMaterial' \
     --output text > springboot-dev-key.pem
   chmod 400 springboot-dev-key.pem
   ```

---

## Quick Start

### 1. Clone and configure

```bash
git clone <repo>
cd terraform
cp environments/dev.tfvars environments/dev.tfvars.local   # add secrets
```

Edit `environments/dev.tfvars.local` and fill in:
- `frontend_ami_id`  / `backend_ami_id`  – your custom AMI with Java 17
- `db_password`                           – strong random password
- `slack_webhook_url`                     – Slack incoming webhook URL

### 2. Initialise

```bash
make init
```

### 3. Plan

```bash
make plan ENV=dev
```

### 4. Apply

```bash
make apply ENV=dev
```

### 5. Point GoDaddy DNS

After apply, Terraform outputs the CloudFront domain name and the ACM
validation CNAMEs. Add the following records to GoDaddy:

| Type  | Name               | Value                              |
|-------|--------------------|------------------------------------|
| CNAME | `www`              | `<cloudfront_domain_name>`         |
| CNAME | `@` (root)         | Use ALIAS/ANAME if supported       |
| CNAME | ACM validation (×2)| From `terraform output acm_certificate_arn` |

---

## Deploy a new application version

1. Upload the new JAR to S3:
   ```bash
   aws s3 cp target/backend-app.jar \
     s3://$(terraform output -raw backend_s3_bucket_name)/backend-app.jar
   ```

2. Trigger an instance refresh (rolling deploy):
   ```bash
   aws autoscaling start-instance-refresh \
     --auto-scaling-group-name $(terraform output -raw backend_asg_name) \
     --preferences '{"MinHealthyPercentage":50,"InstanceWarmup":120}'
   ```

---

## Cost-Cutting Scheduled Scaling

Both ASGs are configured with **scheduled scale-in/scale-out** actions controlled by cron expressions in the tfvars:

| Variable              | Default (UTC)          | IST equivalent |
|-----------------------|------------------------|----------------|
| `*_scale_out_cron`    | `0 2 * * MON-FRI`      | 07:30 IST      |
| `*_scale_in_cron`     | `0 15 * * MON-FRI`     | 20:30 IST      |

Change to `0 0 * * *` / `0 18 * * *` etc. for your team's working hours.

---

## Monitoring

| Resource               | What it tracks                              |
|------------------------|---------------------------------------------|
| CW Alarm – Frontend CPU | `>= threshold` for 2 × 5 min periods        |
| CW Alarm – Backend CPU  | `>= threshold` for 2 × 5 min periods        |
| CW Alarm – RDS CPU      | `>= threshold` for 2 × 5 min periods        |
| CW Alarm – RDS Storage  | Free storage `< 5 GB`                       |
| CW Alarm – RDS Conns    | Connections `>= 100`                        |
| CW Alarm – App Errors   | Log ERROR count `> 10` per 5 min            |
| CW Dashboard            | `<project>-<env>` in CloudWatch console     |

Alarms fan out to:  
→ **SNS Email** (immediate)  
→ **Lambda → Slack** (#prod-alerts / #dev-alerts channel)

---

## Security Highlights

- All EC2 instances use **IMDSv2** (hop-limit = 1)
- S3 buckets have **Public Access Block** fully enabled + AES-256 SSE
- Backend instances are in **private subnets** — no public IP
- RDS is in **isolated DB subnets** — accessible only from Backend SG
- WAF rules: AWS CRS, Known Bad Inputs, SQLi, IP Reputation, Rate Limit
- ALB → CloudFront secret header prevents direct ALB access bypass
- All EC2 roles use **least-privilege S3 policies**
- VPC **Flow Logs** enabled and shipped to CloudWatch

---

## Destroying the infrastructure

```bash
# Dev – force destroy allowed (s3_force_destroy = true)
make destroy ENV=dev

# Prod – RDS deletion protection must be disabled first
terraform apply -var-file=environments/prod.tfvars \
  -var="db_deletion_protection=false" \
  -var="alb_deletion_protection=false"
make destroy ENV=prod
```
