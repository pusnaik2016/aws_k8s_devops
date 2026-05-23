# Well-Architected Framework Review — AWS IoT Greengrass v2 PoC

**Author:** Pushparaj Naik  
**Date:** May 2026  
**Review Type:** AWS Well-Architected Framework (WAF) — 6 Pillars

---

## Summary

This document evaluates the AWS IoT Greengrass v2 PoC against the six pillars of the AWS Well-Architected Framework, identifying strengths and areas for production hardening.

| Pillar | Score | Status |
|--------|-------|--------|
| Operational Excellence | ⭐⭐⭐⭐☆ | Strong |
| Security | ⭐⭐⭐⭐⭐ | Excellent |
| Reliability | ⭐⭐⭐⭐☆ | Strong |
| Performance Efficiency | ⭐⭐⭐⭐☆ | Strong |
| Cost Optimization | ⭐⭐⭐⭐⭐ | Excellent |
| Sustainability | ⭐⭐⭐⭐☆ | Strong |

---

## Pillar 1: Operational Excellence

> *How do you run and monitor systems to deliver business value and continuously improve?*

### ✅ What We Do Well

| Practice | Implementation |
|----------|---------------|
| **Infrastructure as Code** | 100% Terraform — 7 modular modules, versioned, reproducible |
| **CI/CD Pipeline** | GitHub Actions: format → validate → scan → plan → apply |
| **Monitoring Dashboard** | CloudWatch dashboard with IoT metrics, Lambda stats, device connectivity |
| **Structured Logging** | CloudWatch Logs for Greengrass components and Lambda |
| **Alerting** | SNS notifications for threshold breaches and system errors |
| **Environment Separation** | Separate tfvars for dev/prod with different retention policies |

### 📋 Production Improvements

- Add **runbooks** for common operational procedures (device replacement, certificate rotation)
- Implement **AWS Systems Manager OpsCenter** for incident tracking
- Add **custom CloudWatch metrics** for business KPIs (e.g., sensors reporting vs expected)
- Implement **GameDay exercises** to test failure scenarios

---

## Pillar 2: Security

> *How do you protect your information, systems, and assets?*

### ✅ What We Do Well

| Practice | Implementation |
|----------|---------------|
| **Identity & Access** | X.509 certificates for device identity, IAM roles for service access |
| **Detection** | CloudWatch alarms, CloudTrail (account-level), IoT Rules error actions |
| **Infrastructure Protection** | Least-privilege MQTT policies, no wildcard permissions |
| **Data Protection** | KMS encryption at rest (all services), TLS 1.2+ in transit |
| **Incident Response** | SNS alerting, S3 error logging for failed rule actions |
| **No Hardcoded Credentials** | TES for Greengrass, IAM roles for Lambda, no static keys |

### 📋 Production Improvements

- Enable **AWS GuardDuty** for IoT threat detection
- Implement **certificate rotation** automation
- Add **AWS IoT Device Defender** for device-side security auditing
- Implement **VPC Endpoints** for Lambda-to-AWS service communication
- Add **SCPs** at organization level to prevent IoT policy over-permissioning

---

## Pillar 3: Reliability

> *How do you ensure a workload performs its intended function correctly and consistently?*

### ✅ What We Do Well

| Practice | Implementation |
|----------|---------------|
| **Message Delivery** | MQTT QoS 1 (At Least Once) — messages survive brief disconnections |
| **Error Handling** | Dead-letter S3 paths for all IoT Rule failures |
| **State Management** | Terraform remote state with S3 versioning + DynamoDB locking |
| **Multi-AZ** | Timestream and S3 are inherently multi-AZ |
| **Edge Buffering** | Greengrass Disk Spooler component for offline operation |
| **Lambda DLQ** | Failed alert processing sent to SNS dead-letter queue |

### 📋 Production Improvements

- Implement **IoT Device Shadows** for device state resilience
- Add **Kinesis Data Streams** as buffer between IoT Rules and backends
- Implement **cross-region replication** for S3 telemetry
- Add **health check** Lambda for device connectivity monitoring
- Implement **circuit breaker pattern** for alert processing

---

## Pillar 4: Performance Efficiency

> *How do you use computing resources efficiently?*

### ✅ What We Do Well

| Practice | Implementation |
|----------|---------------|
| **Edge Processing** | Aggregate and filter at edge — reduces cloud data by ~80% |
| **Right Service Selection** | Timestream for time-series (optimized queries), S3 for archive |
| **Serverless Compute** | Lambda for alert processing — no idle compute |
| **Efficient Protocols** | MQTT (lightweight binary protocol) vs HTTP |
| **Right-Sized Lambda** | 128MB memory, 30s timeout — minimal for SNS publish |

### 📋 Production Improvements

- Benchmark **Lambda memory** using AWS Lambda Power Tuning
- Implement **IoT Basic Ingest** for high-volume telemetry (bypasses message broker → cost savings)
- Add **Timestream scheduled queries** for pre-aggregated dashboards
- Profile Greengrass component **CPU/memory** usage on actual edge hardware

---

## Pillar 5: Cost Optimization

> *How do you manage your costs to deliver business value?*

### ✅ What We Do Well

| Practice | Implementation |
|----------|---------------|
| **S3 Lifecycle** | Standard → IA (30d) → Glacier (90d) → Expire (7y) |
| **Timestream Retention** | Memory: 6h (dev) / 24h (prod), Magnetic: 30d (dev) / 365d (prod) |
| **Edge Filtering** | Reduces IoT Core message ingestion costs |
| **Serverless** | Lambda — pay only for invocations, no idle costs |
| **Environment Configs** | Shorter retention and lifecycle for dev environment |
| **Free Tier Usage** | SNS, Lambda within free tier for PoC scale |

### Estimated Monthly Cost

| Environment | Devices | Cost |
|-------------|---------|------|
| Dev (3 devices) | 3 | ~$9.60/month |
| Prod (3 devices) | 3 | ~$15.00/month |
| Prod (100 devices) | 100 | ~$85.00/month |

### 📋 Production Improvements

- Set up **AWS Budgets** with alerts at 80% threshold
- Use **Savings Plans** for Lambda if invocation volume is predictable
- Implement **S3 Intelligent-Tiering** for unpredictable access patterns
- Review **Timestream pricing** — consider DynamoDB for simple lookups

---

## Pillar 6: Sustainability

> *How do you minimize the environmental impact of your workload?*

### ✅ What We Do Well

| Practice | Implementation |
|----------|---------------|
| **Edge Processing** | Reduces unnecessary cloud compute by processing at edge |
| **Serverless Architecture** | Resources scale to zero when unused |
| **Data Lifecycle** | Automatic cleanup of old data (S3 expiration, Timestream retention) |
| **Right-Sized Resources** | Lambda at minimum memory, no over-provisioned EC2 |
| **Efficient Data Transfer** | MQTT is binary and compact, aggregation reduces message volume |

### 📋 Production Improvements

- Monitor **carbon footprint** via AWS Customer Carbon Footprint Tool
- Select **lowest-carbon AWS region** for non-latency-sensitive processing
- Implement **dynamic publish intervals** — slower publishing when readings are stable

---

## Architecture Decision Records (ADRs)

### ADR-001: Timestream over DynamoDB for Telemetry

**Decision:** Use Amazon Timestream instead of DynamoDB for telemetry storage.

**Rationale:**
- Timestream is purpose-built for time-series data with native time-based queries
- Automatic data tiering (memory → magnetic) reduces cost
- Built-in interpolation, smoothing, and aggregation functions
- 1000x cheaper than DynamoDB for time-series queries at scale

**Trade-off:** Timestream is not available in all AWS regions.

### ADR-002: Simulated Devices over Physical Hardware

**Decision:** Use Python-based MQTT simulators instead of physical IoT devices.

**Rationale:**
- PoC focus is on cloud architecture, not hardware integration
- Simulators are reproducible and can be automated in CI/CD
- Same MQTT protocol and payload format as real devices
- Easy to scale to 100+ simulated devices for load testing

### ADR-003: Per-Module IAM over Shared Roles

**Decision:** Create dedicated IAM roles per module (TES, Rules, Lambda).

**Rationale:**
- Follows least-privilege principle — each service gets only what it needs
- Easier to audit and troubleshoot permission issues
- Matches AWS Security Hub best practices
- Roles can be independently updated without cascading changes
