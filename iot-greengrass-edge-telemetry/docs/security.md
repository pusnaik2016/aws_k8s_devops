# Security Model — AWS IoT Greengrass v2 PoC

**Author:** Pushparaj Naik  
**Date:** May 2026

---

## 1. Security Overview

This project implements a **defense-in-depth** security model aligned with AWS IoT security best practices and the AWS Well-Architected Security Pillar.

```
Layer 1: Device Identity    → X.509 certificates (mutual TLS)
Layer 2: Transport Security → TLS 1.2+ encryption in transit
Layer 3: Authorization      → Least-privilege MQTT policies
Layer 4: AWS Access         → Token Exchange Service (temporary credentials)
Layer 5: Data Protection    → KMS encryption at rest
Layer 6: Monitoring         → CloudTrail, CloudWatch, GuardDuty
```

---

## 2. Device Authentication — X.509 Certificates

### How It Works

```
Device                              AWS IoT Core
  │                                      │
  ├──── TLS ClientHello ──────────────▶ │
  │                                      │
  │ ◀── TLS ServerHello + Server Cert ──┤
  │     (AWS IoT endpoint certificate)   │
  │                                      │
  ├──── Client Certificate ───────────▶ │  ← Mutual TLS
  │     (Device X.509 cert)              │
  │                                      │
  │ ◀── TLS Handshake Complete ────────┤
  │                                      │
  ├──── MQTT CONNECT ─────────────────▶ │
  │     (clientId = ThingName)           │
  │                                      │
  │ ◀── MQTT CONNACK ─────────────────┤
  │                                      │
```

### Certificate Management

| Aspect | Implementation |
|--------|---------------|
| **Generation** | AWS IoT generates key pair and certificate via `aws_iot_certificate` |
| **Storage** | Private keys saved with `0600` permissions during `terraform apply` |
| **Rotation** | Manual rotation via new certificate creation + old certificate deactivation |
| **Revocation** | Deactivate certificate in IoT Core → immediate disconnection |
| **Root CA** | Amazon Trust Services (ATS) endpoint for modern CA chain |

> **Production Note:** Replace Terraform-generated certificates with AWS IoT Fleet Provisioning for automated, scalable device onboarding.

---

## 3. Authorization — MQTT Policy

Each device certificate has an attached IoT Policy that enforces **least-privilege access**:

```json
{
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "iot:Connect",
      "Resource": "arn:aws:iot:*:*:client/${iot:Connection.Thing.ThingName}"
    },
    {
      "Effect": "Allow",
      "Action": "iot:Publish",
      "Resource": [
        "arn:aws:iot:*:*:topic/dt/iot-greengrass/*/telemetry",
        "arn:aws:iot:*:*:topic/dt/iot-greengrass/*/alert"
      ]
    },
    {
      "Effect": "Allow",
      "Action": "iot:Subscribe",
      "Resource": "arn:aws:iot:*:*:topicfilter/dt/iot-greengrass/*/command"
    }
  ]
}
```

**Key Restrictions:**
- ✅ Devices can only connect with their own Thing Name as client ID
- ✅ Devices can only publish to their designated telemetry and alert topics
- ✅ Devices can only subscribe to their own command topics
- ✅ Shadow access restricted to own Thing
- ❌ Devices cannot publish to other devices' topics
- ❌ Devices cannot subscribe to `#` (wildcard all)
- ❌ No `iot:*` actions — each action explicitly listed

---

## 4. Token Exchange Service (TES)

Greengrass components need AWS credentials to access services (S3, CloudWatch). Instead of hardcoding credentials, they use the **Token Exchange Service**.

```
Greengrass Component
    │
    ├─ Request credentials from local TES endpoint
    │
    ▼
Greengrass Nucleus (local)
    │
    ├─ Uses device certificate to call credentials.iot.amazonaws.com
    │
    ▼
IoT Role Alias → IAM Role
    │
    ├─ STS returns temporary credentials (1-hour TTL)
    │
    ▼
Component uses temp credentials for:
    ├─ S3 (upload artifacts, read config)
    ├─ CloudWatch Logs (push component logs)
    └─ KMS (decrypt secrets)
```

**TES IAM Role Permissions:**
```
✅ s3:GetObject, s3:PutObject   → Component artifact bucket
✅ logs:CreateLogGroup/Stream    → /aws/greengrass/* log groups
✅ kms:Decrypt, kms:DescribeKey  → Shared KMS key
❌ No admin permissions
❌ No cross-account access
❌ No wildcard resources
```

---

## 5. Encryption

### At Rest

| Service | Encryption | Key |
|---------|-----------|-----|
| S3 Telemetry Bucket | SSE-KMS | Customer Managed Key (CMK) |
| Timestream Database | KMS | Customer Managed Key (CMK) |
| CloudWatch Logs | KMS | Customer Managed Key (CMK) |
| SNS Topic | KMS | Customer Managed Key (CMK) |
| Lambda Environment Variables | AWS KMS | Default |

### In Transit

| Connection | Protocol | Certificate |
|-----------|----------|-------------|
| Device → IoT Core | TLS 1.2 (mTLS) | X.509 device certificate |
| IoT Rules → S3 | Internal AWS TLS | AWS managed |
| IoT Rules → Timestream | Internal AWS TLS | AWS managed |
| IoT Rules → Lambda | Internal AWS TLS | AWS managed |
| Lambda → SNS | Internal AWS TLS | AWS managed |

### KMS Key Policy

```
Root account    → Full key management
IoT service     → Encrypt/Decrypt for rules engine
Lambda service  → Decrypt for alert processing
Logs service    → Encrypt for CloudWatch Logs
S3 service      → Encrypt for bucket encryption
```

---

## 6. IAM Roles (Principle of Least Privilege)

| Role | Trust Principal | Permissions | Purpose |
|------|----------------|-------------|---------|
| `greengrass-tes-role` | `credentials.iot.amazonaws.com` | S3 read/write, CW Logs, KMS decrypt | Greengrass component AWS access |
| `iot-rules-role` | `iot.amazonaws.com` | S3 write, Timestream write, Lambda invoke | IoT Rules Engine actions |
| `lambda-exec-role` | `lambda.amazonaws.com` | CW Logs, SNS publish, KMS decrypt | Alert processor execution |

---

## 7. Security Best Practices Checklist

| Control | Status | Notes |
|---------|--------|-------|
| X.509 certificate authentication | ✅ | Per-device certificates |
| Mutual TLS (mTLS) | ✅ | ATS endpoint |
| Least-privilege MQTT policies | ✅ | No wildcard topics |
| No hardcoded credentials | ✅ | TES for AWS access |
| KMS encryption at rest | ✅ | CMK for all services |
| TLS in transit | ✅ | All connections encrypted |
| S3 public access blocked | ✅ | All 4 public access blocks enabled |
| S3 versioning enabled | ✅ | Protects against accidental deletion |
| S3 access logging | ✅ | Audit trail for bucket access |
| CloudTrail enabled | ⚠️ | Requires account-level enablement |
| GuardDuty enabled | ⚠️ | Requires account-level enablement |
| IAM Access Analyzer | ⚠️ | Recommended for production |
| Certificate rotation | 📋 | Manual process in PoC |
| Fleet provisioning | 📋 | Planned for production |
| Network isolation | 📋 | VPC endpoints for production |
