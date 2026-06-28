# Architecture Decision Records (ADRs)

## ADR-001: Active-Passive Pilot Light Over Active-Active

**Status**: Accepted
**Date**: 2026-06-28

### Context

The platform requires disaster recovery capability across AWS and Azure. Options considered:

1. **Active-Active**: Both sites process data simultaneously
2. **Active-Passive (Hot Standby)**: DR site fully running but idle
3. **Active-Passive (Pilot Light)**: DR infrastructure provisioned, pipelines paused

### Decision

Selected **Pilot Light** pattern.

### Rationale

- **Cost**: Hot standby doubles compute costs; pilot light reduces Azure spend by ~70%
- **Complexity**: Active-active requires bi-directional replication, conflict resolution, and split-brain handling
- **RTO**: 4-hour RTO is acceptable for regulatory requirements
- **Compliance**: Both HIPAA and SOC 2 require DR capability, not active-active

### Consequences

- DR activation requires manual intervention (unpause schedules)
- RPO limited by replication lag (~1 hour max)
- Azure compute starts cold on failover (cluster spin-up time)

---

## ADR-002: Format-Preserving Tokenization Over Full Encryption

**Status**: Accepted
**Date**: 2026-06-28

### Context

PII/PAN data must be protected in the Silver layer. Options:

1. Full AES-256 encryption (ciphertext replaces value)
2. Format-preserving encryption (FF3-1)
3. HMAC-based tokenization (deterministic, one-way)

### Decision

Selected **HMAC-based tokenization** with format preservation as the initial implementation, with a migration path to **FF3-1** for production.

### Rationale

- **Analytics Compatibility**: Format-preserving tokens allow downstream joins and pattern analysis without decryption
- **PCI-DSS Compliance**: PAN with visible last-4 satisfies PCI-DSS display requirements
- **Determinism**: Same input always produces same token, enabling join consistency across tables
- **HMAC Simplicity**: No external library dependency; FF3-1 requires pyffx/BPS library integration

### Consequences

- HMAC is one-way (cannot detokenize without a lookup vault)
- Production upgrade to FF3-1 recommended for reversible tokenization use cases
- Encryption key must be stored securely and rotated every 90 days

---

## ADR-003: Databricks Asset Bundles Over Terraform-Only Deployment

**Status**: Accepted
**Date**: 2026-06-28

### Context

Databricks jobs, notebooks, and configurations can be deployed via:

1. Terraform databricks_job resources
2. Databricks REST API + custom scripts
3. Databricks Asset Bundles (DAB)

### Decision

Selected **Databricks Asset Bundles** for pipeline deployment, Terraform for infrastructure.

### Rationale

- **Separation of Concerns**: Infrastructure (VPC, storage, KMS) is long-lived → Terraform. Pipelines (notebooks, jobs) change frequently → DAB
- **Target Isolation**: DAB targets map cleanly to multi-cloud environments (aws_production, azure_dr_standby)
- **Developer Experience**: DAB integrates natively with Databricks CLI, supports `bundle validate` for pre-deploy checks
- **Variable Injection**: Environment-specific values (cluster IDs, secret scopes) injected dynamically without hardcoding

### Consequences

- Two deployment tools (Terraform + DAB) increase operational surface
- DAB workspace state tracked separately from Terraform state
- CI/CD must install both Terraform and Databricks CLI

---

## ADR-004: OIDC Federation Over Static Access Keys

**Status**: Accepted
**Date**: 2026-06-28

### Context

GitHub Actions needs to authenticate to AWS and Azure for deployment. Options:

1. Static IAM access keys stored as GitHub Secrets
2. OIDC Workload Identity Federation

### Decision

Selected **OIDC Federation** using `aws-actions/configure-aws-credentials` and `azure/login`.

### Rationale

- **SOC 2 Compliance**: Static access keys violate SOC 2 CC6.1 (credential management)
- **No Rotation Burden**: OIDC tokens are short-lived (~1 hour), eliminating rotation concerns
- **Blast Radius**: OIDC trust is scoped to specific repo + branch (main only)
- **Auditability**: Every deployment generates a unique session name in CloudTrail

### Consequences

- Requires IAM OIDC provider setup in AWS account
- Requires Azure AD app registration with federated credentials
- Cannot test deployments from forks (OIDC trust is repo-scoped)

---

## ADR-005: VPC Endpoint Restriction Over IP Whitelisting

**Status**: Accepted
**Date**: 2026-06-28

### Context

S3 buckets need access restriction. Options:

1. IP-based access control lists
2. VPC Endpoint-based bucket policies
3. IAM role restriction only

### Decision

Selected **VPC Endpoint-based bucket policies** (`aws:sourceVpce` condition).

### Rationale

- **Zero Public Exposure**: VPC endpoint restriction ensures no internet-routable path to data
- **PCI-DSS**: Network segmentation requirement satisfied at the S3 layer
- **IP Stability**: VPC endpoints don't change IPs; IP whitelists break with NAT rotations
- **Defense in Depth**: Combined with IAM role restriction and CMK encryption

### Consequences

- All S3 access must originate from within the VPC
- Cross-account access requires VPC peering or Transit Gateway
- Breaks S3 access from AWS Console (must use VPN/bastion)

---

## ADR-006: Customer-Managed Keys Over AWS-Managed Keys

**Status**: Accepted
**Date**: 2026-06-28

### Context

Encryption at rest requires key management. Options:

1. AWS-managed keys (SSE-S3)
2. AWS KMS managed keys (SSE-KMS with AWS-managed key)
3. Customer-managed keys (SSE-KMS with CMK)

### Decision

Selected **Customer-Managed Keys** with per-service blast-radius isolation.

### Rationale

- **HIPAA Requirement**: Customer-managed keys provide demonstrable encryption control for audits
- **PCI-DSS 3.4**: Encryption key management must be under customer control
- **Key Rotation**: CMK supports automatic annual rotation; can enforce with AWS Config
- **Blast Radius**: Separate keys for S3 data, Databricks services, and logs limits impact of key compromise

### Consequences

- Key deletion has a 30-day waiting period (cannot be expedited)
- Key policy must explicitly grant access to each service (CloudWatch, CloudTrail, S3, Databricks)
- Cost: ~$1/month per CMK + $0.03 per 10,000 API requests

---

## ADR-007: Direct Connect + VPN Failover Over VPN-Only

**Status**: Accepted
**Date**: 2026-06-28

### Context

Cross-cloud transit between AWS and Azure requires a secure network path.

### Decision

Primary: **AWS Direct Connect ↔ Azure ExpressRoute** via common exchange provider.
Failover: **IPSec VPN tunnel** (IKEv2, AES-256-GCM, SHA-384).

### Rationale

- **Bandwidth**: Direct Connect/ExpressRoute provides 200+ Mbps dedicated bandwidth for data replication
- **Latency**: Private peering eliminates internet routing variability
- **Compliance**: Dedicated connection ensures no public internet traverse (PCI-DSS)
- **Resilience**: VPN failover activates within seconds if Direct Connect fails

### Consequences

- Requires exchange provider coordination (Equinix/Megaport)
- Monthly cost for Direct Connect port + ExpressRoute circuit
- VPN throughput limited compared to dedicated connection
