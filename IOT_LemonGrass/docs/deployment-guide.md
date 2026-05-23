# Deployment Guide — AWS IoT Greengrass v2 PoC

**Author:** Pushparaj Naik  
**Date:** May 2026

---

## Prerequisites

### Required Tools

| Tool | Version | Purpose |
|------|---------|---------|
| AWS CLI | v2.x | AWS account access |
| Terraform | >= 1.5.0 | Infrastructure provisioning |
| Python | >= 3.11 | Simulator scripts and Lambda |
| Git | Latest | Version control |

### Required AWS Resources (Pre-existing)

1. **S3 Bucket** for Terraform state: `iot-greengrass-terraform-state`
2. **DynamoDB Table** for state locking: `terraform-lock`
3. **AWS Account** with IoT Core enabled in `us-east-1`

### Create State Backend (if not exists)

```bash
# Create S3 bucket for Terraform state
aws s3api create-bucket \
  --bucket iot-greengrass-terraform-state \
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket iot-greengrass-terraform-state \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket iot-greengrass-terraform-state \
  --server-side-encryption-configuration '{
    "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
  }'

# Create DynamoDB table for locking
aws dynamodb create-table \
  --table-name terraform-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

---

## Step 1: Clone and Configure

```bash
cd /path/to/IOT_LemonGrass

# Review variables
cat terraform/variables.tf

# Configure environment
cp terraform/environments/dev.tfvars terraform/terraform.tfvars

# Edit to set your alert email (optional)
# alert_email = "your.email@example.com"
```

---

## Step 2: Initialize Terraform

```bash
cd terraform

# Initialize providers and modules
terraform init

# Expected output:
# Initializing modules...
# Initializing the backend...
# Initializing provider plugins...
# - hashicorp/aws ~> 5.0
# - hashicorp/tls ~> 4.0
# Terraform has been successfully initialized!
```

---

## Step 3: Plan and Review

```bash
# Generate execution plan
terraform plan -var-file=environments/dev.tfvars -out=tfplan

# Review the plan — expected resources:
# - 3 IoT Things (one per customer site)
# - 3 IoT Certificates
# - 1 IoT Policy + 1 TES Policy
# - 3 Certificate-Policy attachments
# - 3 Certificate-Thing attachments
# - 1 IoT Thing Group + 3 memberships
# - 1 IoT Role Alias
# - 4 IoT Topic Rules
# - 1 S3 Bucket (with versioning, encryption, lifecycle, logging)
# - 1 Timestream Database + 1 Table
# - 1 Lambda Function + 1 Log Group
# - 1 SNS Topic
# - 2 CloudWatch Alarms
# - 1 CloudWatch Dashboard
# - 3 IAM Roles + policies
# - 1 KMS Key + alias
```

---

## Step 4: Apply Infrastructure

```bash
# Apply the plan
terraform apply tfplan

# Or apply directly
terraform apply -var-file=environments/dev.tfvars -auto-approve

# Save outputs for later use
terraform output -json > ../outputs.json

# Key outputs:
# iot_endpoint        → MQTT endpoint for device connections
# thing_names         → Map of site → thing name
# telemetry_bucket    → S3 bucket for raw telemetry
# timestream_database → Timestream DB name
# greengrass_role_alias → TES role alias for device setup
```

---

## Step 5: Download Root CA Certificate

```bash
# Download Amazon Root CA (required for MQTT connections)
curl -o modules/iot_core/certs/AmazonRootCA1.pem \
  https://www.amazontrust.com/repository/AmazonRootCA1.pem
```

---

## Step 6: Test Telemetry Simulator

```bash
cd ..  # Back to project root

# Install Python dependencies
pip install awsiotsdk

# Get IoT endpoint
IOT_ENDPOINT=$(cd terraform && terraform output -raw iot_endpoint)

# Run simulator in dry-run mode first
python scripts/simulate_telemetry.py \
  --endpoint $IOT_ENDPOINT \
  --cert terraform/modules/iot_core/certs/site-mumbai-certificate.pem \
  --key terraform/modules/iot_core/certs/site-mumbai-private.key \
  --root-ca terraform/modules/iot_core/certs/AmazonRootCA1.pem \
  --site site-mumbai \
  --count 20 \
  --interval 3 \
  --dry-run

# Run actual simulation (publishes to AWS IoT Core)
python scripts/simulate_telemetry.py \
  --endpoint $IOT_ENDPOINT \
  --cert terraform/modules/iot_core/certs/site-mumbai-certificate.pem \
  --key terraform/modules/iot_core/certs/site-mumbai-private.key \
  --root-ca terraform/modules/iot_core/certs/AmazonRootCA1.pem \
  --site site-mumbai \
  --count 50 \
  --interval 5
```

---

## Step 7: Verify Data Flow

### Check S3 (Raw Telemetry Archive)
```bash
BUCKET=$(cd terraform && terraform output -raw telemetry_bucket_name)
aws s3 ls "s3://$BUCKET/telemetry/" --recursive | head -10
```

### Check Timestream (Time-Series Data)
```bash
DB_NAME=$(cd terraform && terraform output -raw timestream_database)
aws timestream-query query \
  --query-string "SELECT * FROM \"$DB_NAME\".\"sensor_data\" ORDER BY time DESC LIMIT 10"
```

### Check CloudWatch Dashboard
```bash
DASHBOARD_URL=$(cd terraform && terraform output -raw cloudwatch_dashboard_url)
echo "Open in browser: $DASHBOARD_URL"
```

### Check SNS Alerts (if email configured)
- Confirm SNS subscription via email
- Monitor inbox for threshold breach alerts

---

## Step 8: (Optional) Setup Greengrass Core Device

For a full edge-to-cloud demo on an EC2 instance:

```bash
# Launch an EC2 instance (Amazon Linux 2023)
# SSH into the instance, then:

# Copy certificates to device
scp -i key.pem terraform/modules/iot_core/certs/site-mumbai-* ec2-user@<IP>:/tmp/certs/
scp terraform/modules/iot_core/certs/AmazonRootCA1.pem ec2-user@<IP>:/tmp/certs/

# Run setup script on the device
./scripts/setup_greengrass_device.sh \
  --thing-name iot-greengrass-site-mumbai \
  --thing-group iot-greengrass-fleet \
  --tes-role-alias iot-greengrass-GreengrassTESAlias \
  --region us-east-1 \
  --cert-dir /tmp/certs
```

---

## Cleanup

```bash
cd terraform

# Destroy all resources
terraform destroy -var-file=environments/dev.tfvars -auto-approve

# Verify no resources remain
terraform state list
```

---

## Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| `terraform init` fails | Missing state bucket | Create S3 bucket and DynamoDB table (Step 0) |
| MQTT connection refused | Wrong endpoint or cert | Verify IoT endpoint and certificate paths |
| No data in S3 | Rules not matching | Check IoT Rules are enabled in console |
| No alerts received | SNS subscription pending | Confirm email subscription |
| Timestream write error | Wrong region | Ensure Timestream is supported in your region |
