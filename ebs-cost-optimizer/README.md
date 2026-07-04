# EBS Cost Optimizer

Scan, tag, and clean up Amazon EBS volumes to enforce cost-allocation tagging policies and eliminate spend on unattached volumes.

## What It Does

| Feature | Description |
|---|---|
| **Scan** | Discover all EBS volumes across one or all regions |
| **Tag** | Enforce mandatory cost-allocation tags (propagated from attached EC2 instances or from config) |
| **Report** | Generate a CSV/JSON savings report with per-volume monthly cost |
| **Cleanup** | Snapshot + delete unattached volumes (dry-run safe) |

## Savings Opportunities Detected

- **Unattached volumes** – volumes in `available` state with no EC2 attachment → direct monthly cost with zero value
- **Untagged volumes** – no `CostCenter` / `Project` tag → hidden spend that cannot be allocated
- **Oversized gp2 volumes** → recommend migration to `gp3` (20 % cheaper, higher baseline IOPS)

## Quick Start

```bash
cd ebs-cost-optimizer
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# Dry-run: show what would be tagged/deleted, write report
python ebs_optimizer.py scan   --region us-east-1
python ebs_optimizer.py tag    --region us-east-1 --dry-run
python ebs_optimizer.py report --region us-east-1 --output reports/ebs_report.csv
python ebs_optimizer.py cleanup --region us-east-1 --dry-run
```

## Configuration

Copy and edit `config.yaml.example`:

```bash
cp config.yaml.example config.yaml
```

```yaml
mandatory_tags:
  - Environment
  - Owner
  - Project
  - CostCenter

default_tags:
  ManagedBy: ebs-cost-optimizer

tag_propagation:
  enabled: true          # copy tags from attached EC2 instance
  keys: [Environment, Owner, Project, CostCenter]

cleanup:
  snapshot_before_delete: true
  min_unattached_days: 14   # only delete if unattached for >= N days
```

## AWS Permissions Required

```json
{
  "Effect": "Allow",
  "Action": [
    "ec2:DescribeVolumes",
    "ec2:DescribeSnapshots",
    "ec2:DescribeInstances",
    "ec2:DescribeRegions",
    "ec2:CreateTags",
    "ec2:CreateSnapshot",
    "ec2:DeleteVolume",
    "pricing:GetProducts"
  ],
  "Resource": "*"
}
```

## Scheduled Automation (Terraform)

```bash
cd terraform
terraform init
terraform apply -var="alert_email=you@example.com"
```

Deploys an EventBridge rule that runs the Lambda tagger daily.

## Report Output (CSV sample)

```
VolumeId,Region,State,SizeGB,Type,MountedOn,UnattachedDays,MonthlyUSD,MissingTags,Recommendation
vol-0abc123,us-east-1,available,100,gp2,,22,10.00,"Owner,CostCenter",DELETE
vol-0def456,us-east-1,in-use,500,gp2,i-0xyz,0,50.00,"CostCenter",MIGRATE_TO_GP3
```
