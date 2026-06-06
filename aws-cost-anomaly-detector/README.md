# AWS Cost Anomaly Detector 🔍

> **Intelligent AWS cost monitoring for ~$2/month** — powered by Z-score statistics + Claude 3.5 Sonnet via Amazon Bedrock.

Tells you **WHY** your AWS bill spiked, not just **THAT** it did.

---

## Architecture

```
EventBridge (08:00 UTC)
    └──► Cost Fetcher Lambda
              └──► Cost Explorer API (90 days)
                        └──► DynamoDB (TTL auto-expiry)

EventBridge (08:10 UTC)
    └──► Anomaly Detector Lambda
              └──► DynamoDB (load history)
                        └──► Z-score analysis per service
                                  └──► [if anomaly] Amazon Bedrock (Claude)
                                                └──► SNS → Email Alert
```

## How It Works

### 1. Data Collection (Cost Fetcher — 08:00 UTC)
Pulls 90 days of daily cost-by-service from the Cost Explorer API and upserts each row into DynamoDB. Items have a `expiry_ts` TTL field so DynamoDB automatically deletes rows older than 90 days — no manual cleanup needed.

### 2. Statistical Detection (Anomaly Detector — 08:10 UTC)
For each service, calculates a **Z-score**:

```
Z = (cost_today - mean_baseline) / std_dev_baseline
```

The baseline **excludes today's cost** to prevent the anomaly from tainting its own detection threshold. Services with fewer than 14 days of history are skipped (avoids false positives on new services).

### 3. Intelligent Analysis (Claude 3.5 Sonnet via Bedrock)
If any Z-score exceeds the threshold (default 2.5), the flagged services are sent to Claude with precise statistical context (cost today, 90-day mean, delta %, 30-day trend). Claude responds with:
- **SEVERITY**: LOW / MEDIUM / HIGH / CRITICAL
- **WHAT HAPPENED**: One-sentence description
- **LIKELY CAUSE**: Specific technical root cause (NAT Gateway, instance type, S3 lifecycle, etc.)
- **ACTION**: Concrete AWS CLI command or console path to investigate

### 4. Alert Delivery (SNS → Email)
A structured email is published to SNS, which delivers it to your inbox. The email contains both the raw statistics and Claude's analysis in plain text.

---

## Prerequisites

| Requirement | Details |
|---|---|
| AWS Account | With appropriate IAM permissions |
| Terraform | `>= 1.7` |
| AWS CLI | Configured with credentials |
| Bedrock Access | **Must** enable Claude 3.5 Sonnet manually in the console |

### Enable Bedrock Model Access
> AWS Console → Amazon Bedrock → Model access → Request access to **Claude 3.5 Sonnet**
>
> ⚠️ This **cannot** be automated via Terraform or AWS CLI. It is a manual one-time action.

---

## Quickstart

```bash
# 1. Clone
git clone <your-repo-url>
cd AnamolyDetector

# 2. Configure
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars    # Set alert_email (required)

# 3. Deploy
chmod +x deploy.sh
./deploy.sh             # Equivalent to: terraform init && terraform apply

# 4. Confirm SNS subscription
# Check your email inbox for a message from AWS Notifications
# Click the "Confirm subscription" link — alerts won't arrive without this!
```

---

## Configuration

```hcl
# terraform.tfvars
aws_region       = "us-east-1"
environment      = "prod"
alert_email      = "your@email.com"
zscore_threshold = 2.5
bedrock_model_id = "anthropic.claude-3-5-sonnet-20241022-v2:0"
```

### Z-Score Threshold Tuning

| Threshold | Observations Flagged | Sensitivity | Recommended For |
|---|---|---|---|
| `2.0` | ~4.5% | High | Dev/QA accounts, volatile workloads |
| `2.5` | ~1.2% | Balanced | **Default — most production accounts** |
| `3.0` | ~0.3% | Low | Very stable workloads, less alert fatigue |

---

## Module Structure

```
AnamolyDetector/
├── main.tf                          # Root — wires all modules together
├── variables.tf                     # Root variables with validation
├── outputs.tf                       # Root outputs
├── terraform.tfvars.example         # Example configuration
├── deploy.sh                        # One-command deployment script
└── modules/
    ├── storage/                     # DynamoDB table with TTL
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── bedrock_config/              # Bedrock model config & region validation
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── notifications/               # SNS topic + email subscription
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── cost_analyzer/               # Lambdas, IAM, EventBridge schedulers
        ├── main.tf
        ├── iam.tf
        ├── variables.tf
        ├── outputs.tf
        └── lambda/
            ├── cost_fetcher.py      # Fetches Cost Explorer → DynamoDB
            └── anomaly_detector.py  # Z-score → Bedrock → SNS
```

---

## Cost Breakdown

| Resource | Monthly Cost |
|---|---|
| Lambda (2×, ~1 min/day each) | ~$0.00 (free tier) |
| DynamoDB (PAY_PER_REQUEST, ~few KB) | ~$0.01 |
| Cost Explorer API (~30 calls/month) | ~$0.30 |
| Amazon Bedrock (Claude 3.5 Sonnet, ~1K tokens/day) | ~$0.50–$1.50 |
| SNS (email, ~30 messages/month) | ~$0.00 |
| EventBridge Scheduler (2 rules) | ~$0.00 |
| **Total** | **~$1–$2/month** |

---

## Important Constraints

### Cost Explorer Data Lag
Cost Explorer has a **~24-hour data lag**. Today's costs won't appear until tomorrow. The scheduler runs at 08:00 UTC to ensure yesterday's full-day data is available. Never schedule at midnight expecting same-day data.

### Minimum Baseline Requirement
Z-score requires a minimum of **14 days of history** per service. New services or newly-active services won't trigger alerts until 14 days of data exists. This prevents false positives during ramp-up.

### IAM Constraint on Cost Explorer
`ce:GetCostAndUsage` always requires `Resource: "*"`. This is an **AWS API limitation**, not a security weakness or misconfiguration. It cannot be scoped to a specific resource ARN.

### Bedrock Region Availability
The Bedrock module validates that your chosen region supports Claude. Supported regions: `us-east-1`, `us-west-2`, `eu-west-1`, `ap-southeast-1`, `ap-northeast-1`.

---

## Manual Testing

Trigger either Lambda manually at any time:

```bash
# Trigger Cost Fetcher
aws lambda invoke \
  --function-name cost-anomaly-prod-cost-fetcher \
  --payload '{}' \
  response.json && cat response.json

# Trigger Anomaly Detector
aws lambda invoke \
  --function-name cost-anomaly-prod-anomaly-detector \
  --payload '{}' \
  response.json && cat response.json

# Tail logs in real time
aws logs tail /aws/lambda/cost-anomaly-prod-cost-fetcher --follow
aws logs tail /aws/lambda/cost-anomaly-prod-anomaly-detector --follow
```

---

## Destroy

```bash
./deploy.sh destroy
```

All resources will be removed. DynamoDB data will be permanently deleted.

---

## License

MIT — use freely, break costs responsibly.
