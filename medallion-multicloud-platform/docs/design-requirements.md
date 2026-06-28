# Design & Requirements Document

## Enterprise Multi-Cloud Medallion Data Platform

| Field | Value |
|-------|-------|
| **Document Version** | 1.0 |
| **Last Updated** | 2026-06-28 |
| **Classification** | Internal — Confidential |
| **Compliance Scope** | HIPAA · SOC 2 Type II · PCI-DSS v4.0 |

---

## 1. Executive Summary

This document specifies the design and requirements for an enterprise-grade multi-cloud data lakehouse platform implementing the **Medallion Architecture** (Bronze → Silver → Gold) on **Databricks**, deployed across **AWS (Primary Active)** and **Azure (Disaster Recovery Passive Standby)** in an **Active-Passive Pilot Light** pattern.

The platform is designed to process regulated data categories including **ePHI** (HIPAA), **cardholder data** (PCI-DSS), and **sensitive business information** (SOC 2), requiring strict security controls, encryption, and audit capabilities.

---

## 2. Functional Requirements

### 2.1 Data Ingestion (Bronze Layer)

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-001 | System shall ingest raw data files (JSON, CSV, Parquet) from source systems using Auto Loader (Structured Streaming) | P0 |
| FR-002 | System shall enforce schema validation on all incoming data using predefined JSON schema definitions | P0 |
| FR-003 | System shall append ingestion metadata (_ingestion_timestamp, _source_file, _pipeline_run_id) to every record | P0 |
| FR-004 | System shall support schema evolution (addNewColumns mode) without pipeline failure | P1 |
| FR-005 | System shall deduplicate records at the Bronze boundary using checkpointing | P1 |

### 2.2 Data Transformation (Silver Layer)

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-010 | System shall read Bronze Delta tables and apply data quality validations (null checks, type casting, deduplication) | P0 |
| FR-011 | System shall tokenize all PII fields (SSN, email, phone, patient_id, MRN) using format-preserving encryption before Silver persistence | P0 — HIPAA |
| FR-012 | System shall tokenize PAN (credit card number) using format-preserving encryption, preserving only the last 4 digits | P0 — PCI-DSS |
| FR-013 | System shall generate a SHA-256 record hash (_record_hash) for SCD Type 2 change detection | P1 |
| FR-014 | System shall write data quality audit results to a separate Delta table for compliance reporting | P0 |
| FR-015 | System shall fetch encryption keys at runtime from Databricks Secret Scope (never hardcoded) | P0 — SOC 2 |

### 2.3 Data Aggregation (Gold Layer)

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-020 | System shall produce event summary aggregates (total records, unique records, timestamp ranges) | P0 |
| FR-021 | System shall produce daily time-series aggregates for dashboard consumption | P0 |
| FR-022 | System shall record pipeline metrics (record counts per layer, status) in a metrics Delta table | P0 |
| FR-023 | System shall apply Z-ORDER optimization on date columns for query performance | P1 |

### 2.4 Data Governance

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-030 | All data access shall be governed through Databricks Unity Catalog with explicit permissions | P0 |
| FR-031 | Row-Level Security (RLS) and Column-Level Masking shall be configurable per table | P0 — HIPAA |
| FR-032 | All data catalogs shall be organized as medallion.{bronze,silver,gold}.{table_name} | P0 |

---

## 3. Non-Functional Requirements

### 3.1 Security

| ID | Requirement | Standard |
|----|-------------|----------|
| NFR-001 | All data at rest shall be encrypted using Customer-Managed Keys (CMK) via AWS KMS and Azure Key Vault | HIPAA/PCI-DSS |
| NFR-002 | All data in transit shall use minimum TLS 1.3 encryption | PCI-DSS |
| NFR-003 | No compute resources, storage endpoints, or analytics services shall have public IP addresses | HIPAA |
| NFR-004 | All credential storage shall use cloud-native vaulting (AWS Secrets Manager / Azure Key Vault) | SOC 2 |
| NFR-005 | All credentials shall rotate automatically every 90 days | PCI-DSS |
| NFR-006 | CI/CD authentication shall use OIDC Workload Identity Federation (no static secrets in GitHub) | SOC 2 |
| NFR-007 | Cross-cloud transit shall use dedicated connections (DirectConnect/ExpressRoute) with IPSec VPN failover | PCI-DSS |

### 3.2 Availability & DR

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-010 | Platform shall maintain 99.9% availability on the primary (AWS) site | SLA |
| NFR-011 | DR failover to Azure shall be achievable within 4 hours (RTO) | DR |
| NFR-012 | Maximum data loss on failover shall not exceed 1 hour of data (RPO) | DR |
| NFR-013 | Azure DR site shall operate in Pilot Light mode (infrastructure provisioned, pipelines paused) | Cost Optimization |

### 3.3 Performance

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-020 | Bronze ingestion shall process files within 5 minutes of landing | Latency |
| NFR-021 | Silver transformation shall complete within 30 minutes for batch runs | Throughput |
| NFR-022 | Gold aggregation queries shall return within 10 seconds for standard dashboards | Query |

### 3.4 Audit & Compliance

| ID | Requirement | Standard |
|----|-------------|----------|
| NFR-030 | All access events shall be captured in an immutable audit log (365-day retention minimum) | HIPAA/SOC 2 |
| NFR-031 | Encryption validation shall achieve 100% CMK enforcement (reject unencrypted writes) | PCI-DSS |
| NFR-032 | CI/CD pipeline shall block deployment on any Critical SAST vulnerability | PCI-DSS |
| NFR-033 | Configuration drift between AWS and Azure environments shall be 0 gaps | SOC 2 |

---

## 4. System Design

### 4.1 Medallion Architecture

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   BRONZE     │     │   SILVER     │     │    GOLD      │
│              │     │              │     │              │
│  Raw Data    │────▶│  Cleansed &  │────▶│  Business    │
│  Ingestion   │     │  Tokenized   │     │  Aggregates  │
│              │     │              │     │              │
│  • Auto Loader│    │  • DQ Checks │     │  • Z-ORDER   │
│  • Schema    │     │  • PII Token │     │  • Summaries │
│    Enforce   │     │  • SCD Type 2│     │  • Metrics   │
│  • Metadata  │     │  • Dedup     │     │  • Time-series│
└──────────────┘     └──────────────┘     └──────────────┘
     Delta Lake           Delta Lake           Delta Lake
     S3/ADLS Gen2         S3/ADLS Gen2         S3/ADLS Gen2
     CMK Encrypted        CMK Encrypted        CMK Encrypted
```

### 4.2 Network Architecture

- **AWS VPC** (10.0.0.0/16): 3-tier subnet isolation (Public/Compute/Data)
- **Azure VNet** (10.1.0.0/16): Databricks VNet injection with NSG deny-all
- **Cross-Cloud**: Direct Connect ↔ ExpressRoute (primary), IPSec VPN (failover)
- **Zero Public Exposure**: All services accessed via VPC Endpoints / Private Endpoints

### 4.3 Encryption Architecture

| Domain | AWS | Azure | Key Type |
|--------|-----|-------|----------|
| Medallion Data (S3/ADLS) | KMS CMK `s3-data` | Key Vault CMK `storage-cmk` | RSA 2048 |
| Databricks Services | KMS CMK `databricks` | Key Vault CMK `databricks-cmk` | RSA 2048 |
| Audit Logs | KMS CMK `logs` | Log Analytics default | AES 256 |

### 4.4 Identity Architecture

- **Central IdP**: Microsoft Entra ID (SCIM provisioning to Databricks)
- **AWS Auth**: IAM roles with cross-account trust for Databricks
- **Azure Auth**: Managed Identity for Databricks → ADLS/Key Vault
- **CI/CD Auth**: OIDC Federation (GitHub → AWS IAM / Azure Service Principal)

---

## 5. Technology Stack

| Layer | Technology | Version |
|-------|-----------|---------|
| Infrastructure as Code | Terraform | >= 1.6.0 |
| Cloud Providers | AWS, Azure | Latest |
| Data Platform | Databricks (E2/Premium) | Latest |
| Compute | PySpark on Databricks | 3.5.x |
| Data Format | Delta Lake | 3.x |
| Data Governance | Unity Catalog | Latest |
| CI/CD | GitHub Actions | Latest |
| Pipeline as Code | Databricks Asset Bundles | Latest |
| Testing | pytest | 8.x |
| SAST | Trivy, Gitleaks | Latest |
| Monitoring (AWS) | CloudWatch, AWS Config | Latest |
| Monitoring (Azure) | Log Analytics, Azure Monitor | Latest |

---

## 6. Constraints & Assumptions

### Constraints
1. All data must reside within US regions (HIPAA data residency)
2. No data may traverse public internet between AWS and Azure
3. Minimum TLS 1.3 for all transport encryption
4. 90-day maximum credential lifetime (PCI-DSS)

### Assumptions
1. Databricks E2 architecture is available in the target AWS region
2. Direct Connect / ExpressRoute exchange provider (Equinix/Megaport) is available
3. Unity Catalog is available in both AWS and Azure Databricks
4. GitHub Actions runners can reach Databricks workspace API endpoints
