# Multi-Cloud & DevOps Architect — Interview Q&A (Part 1)

> **Role:** Multi-Cloud & DevOps Architect | **Experience:** 12+ Years (5+ in Architect Role)  
> **Focus:** Multi-Cloud Strategy, Landing Zones, Terraform/IaC, Networking, Kubernetes Platforms  
> **Primary Cloud:** AWS | **Secondary:** Azure & GCP

---

## Table of Contents

- [Section 1: Multi-Cloud Strategy & Architecture (Q1–Q8)](#section-1)
- [Section 2: Landing Zones & Account/Subscription Structures (Q9–Q14)](#section-2)
- [Section 3: Terraform & Infrastructure-as-Code at Scale (Q15–Q22)](#section-3)
- [Section 4: Multi-Cloud Networking Deep Dive (Q23–Q30)](#section-4)
- [Section 5: Kubernetes Platform Engineering (Q31–Q38)](#section-5)

---

## Section 1: Multi-Cloud Strategy & Architecture {#section-1}

---

### Q1. Why would an enterprise choose multi-cloud over a single cloud provider? What are the real trade-offs?

**Answer:**

**Business drivers for multi-cloud:**

| Driver | Explanation |
|--------|-------------|
| Vendor lock-in avoidance | Avoid dependency on one vendor's pricing or roadmap |
| Best-of-breed services | Azure AD for identity, AWS for ML/AI (SageMaker), GCP for BigQuery analytics |
| Regulatory/data residency | Some regulators require cloud diversity or specific regional availability |
| Mergers & acquisitions | Acquired company runs Azure; parent runs AWS |
| Disaster recovery | True blast radius isolation across providers |
| Negotiation leverage | Committed spends across providers for better pricing |

**Real trade-offs I always surface upfront:**

| Trade-off | Impact |
|-----------|--------|
| **Operational complexity** | 3× the IAM models, 3× the networking primitives, 3× the monitoring toolchains |
| **Skill dilution** | Engineers need breadth across all clouds; deep expertise is hard to maintain |
| **Cost of abstraction** | Unified tooling (Terraform, Crossplane) adds its own complexity layer |
| **Data transfer costs (egress)** | Moving data between clouds incurs significant egress fees — often underestimated |
| **Security consistency** | Enforcing consistent posture across three IAM models is hard |

**My honest recommendation:**

> **Start single-cloud until you have a specific reason for multi-cloud.** Then adopt a "primary + secondary" model: AWS as primary for 80% of workloads, Azure for M365/AD integration, GCP for big data — rather than distributing evenly across three clouds. Forced multi-cloud without a business driver is just complexity tax.

---

### Q2. How do you design a reference architecture for a multi-cloud platform? Walk us through your approach

**Answer:**

**My 6-layer architecture model:**

```
┌─────────────────────────────────────────────────────────────┐
│ Layer 6: Applications & Workloads                           │
│ (Microservices, serverless, data workloads)                 │
├─────────────────────────────────────────────────────────────┤
│ Layer 5: Developer Platform (Internal Developer Portal)     │
│ (Backstage, self-service, golden paths, CI/CD)              │
├─────────────────────────────────────────────────────────────┤
│ Layer 4: Kubernetes Platform                                │
│ (EKS / AKS / GKE, Helm, GitOps, service mesh)              │
├─────────────────────────────────────────────────────────────┤
│ Layer 3: Observability & Security                           │
│ (Prometheus, Grafana, Loki, OTel, Falco, Vault)             │
├─────────────────────────────────────────────────────────────┤
│ Layer 2: Networking & Connectivity                          │
│ (VPC/VNet, peering, transit gateway, private DNS)           │
├─────────────────────────────────────────────────────────────┤
│ Layer 1: Foundation (Landing Zone)                          │
│ (Accounts/subscriptions, IAM, logging, billing, guardrails) │
└─────────────────────────────────────────────────────────────┘
```

**Design principles I embed in every reference architecture:**

1. **Immutable infrastructure** — Servers/nodes are never patched in place; replaced
2. **GitOps everywhere** — Cluster state, app config, and infrastructure all live in Git
3. **Zero-trust networking** — No implicit trust based on network location; mTLS + workload identity
4. **Shift-left security** — Security gates in CI, not just in production scanning
5. **Policy as code** — OPA/Sentinel/SCPs enforce guardrails without manual review
6. **Observable by default** — Every service emits logs, metrics, traces from day one; no retrofitting

**Architecture Decision Records (ADRs)** I always write for multi-cloud:

- ADR-001: Choice of primary cloud provider and rationale
- ADR-002: IaC tool selection (Terraform vs Pulumi vs CDK)
- ADR-003: Inter-cloud connectivity approach (VPN vs Direct Connect + ExpressRoute)
- ADR-004: Container registry strategy (one per cloud vs. centralized with replication)
- ADR-005: Secrets management strategy (Vault vs cloud-native KMS)

---

### Q3. Compare AWS, Azure, and GCP across compute, networking, identity, and managed data services. Where does each shine?

**Answer:**

**Compute comparison:**

| Capability | AWS | Azure | GCP |
|-----------|-----|-------|-----|
| VM flagship | EC2 (hundreds of types) | Azure VMs (Dv5, Ev5, Lv3) | Compute Engine (N2, C2, T2D) |
| Spot/preemptible | Spot Instances (2-min notice) | Spot VMs (30-sec notice) | Spot VMs (30-sec notice) |
| Serverless containers | ECS Fargate | Azure Container Apps | Cloud Run |
| Managed Kubernetes | EKS | AKS | GKE (Autopilot most mature) |
| GPU/ML | SageMaker, Trainium, Inferentia | Azure ML, ND-series | Vertex AI, TPUs |

**Networking comparison:**

| Capability | AWS | Azure | GCP |
|-----------|-----|-------|-----|
| Core network unit | VPC | VNet | VPC (global by default) |
| Multi-region connectivity | Transit Gateway | Virtual WAN | VPC (auto spans regions) |
| Private connectivity | PrivateLink | Private Link | Private Service Connect |
| CDN | CloudFront | Azure CDN / Front Door | Cloud CDN |
| DNS | Route 53 | Azure DNS | Cloud DNS |

> **Key difference:** GCP VPCs are **global** — a single VPC spans all regions. AWS and Azure VPCs/VNets are **regional** — you need Transit Gateway or Virtual WAN to connect them.

**Identity comparison:**

| Capability | AWS | Azure | GCP |
|-----------|-----|-------|-----|
| Core identity | IAM (flat; no groups for services) | Azure AD (Entra ID) | Cloud IAM + Workload Identity |
| Workload identity | IAM roles + instance profiles + OIDC | Managed Identity | Workload Identity Federation |
| SSO integration | IAM Identity Center (SSO) | Azure AD B2C / Entra ID | Cloud Identity + GCIP |
| Best for | Fine-grained resource policies | Enterprise identity (AD-native) | Developer-friendly bindings |

**Managed data services:**

| Use Case | AWS | Azure | GCP |
|---------|-----|-------|-----|
| Relational DB | RDS / Aurora | Azure SQL / Flexible Server | Cloud SQL / AlloyDB |
| NoSQL | DynamoDB | Cosmos DB | Firestore / Bigtable |
| Data warehouse | Redshift | Azure Synapse | BigQuery (best-in-class) |
| Streaming | Kinesis | Event Hubs | Pub/Sub |
| Object storage | S3 | Azure Blob Storage | Cloud Storage |

**Where each shines:**

- **AWS:** Breadth of services (230+), most mature ecosystem, best for enterprises starting cloud journey
- **Azure:** M365/Active Directory integration, hybrid (Arc), enterprise compliance (most certifications)
- **GCP:** Data analytics (BigQuery), Kubernetes (GKE Autopilot), networking performance, ML (TPUs, Vertex)

---

### Q4. How do you handle IAM across three clouds from a single identity plane?

**Answer:**

**The problem:** AWS IAM, Azure Entra ID, and GCP IAM are fundamentally different models.

```
AWS IAM:    Resource-based + Identity-based policies; no "groups" for services
Azure AD:   RBAC on top of directory objects; roles, not policies
GCP IAM:    Binding = (member, role, resource); very clean hierarchy
```

**My unified identity strategy:**

**1. Federate to a single IdP (Identity Provider)**

```
Corporate IdP (Azure AD / Okta / Ping)
       │
       ├── AWS: IAM Identity Center (SSO) ──── Permission Sets ──► IAM Roles
       ├── Azure: Entra ID natively integrated
       └── GCP: Cloud Identity / Workforce Identity Federation
```

**2. Workload identity (service-to-service):**

| Cloud | Preferred Mechanism |
|-------|-------------------|
| AWS | IAM Roles for Service Accounts (IRSA) on EKS; no static keys |
| Azure | Managed Identity (system or user assigned) |
| GCP | Workload Identity Federation (bind K8s SA → Google SA) |

**3. Unified secrets management with HashiCorp Vault:**

```
Vault acts as the central secrets broker across all clouds:
- AWS: Vault dynamic secrets → generates short-lived IAM credentials
- Azure: Vault Azure Secrets Engine → generates short-lived SP credentials  
- GCP: Vault GCP Secrets Engine → generates short-lived service account keys
```

**4. Guardrails via IaC:**

```hcl
# Enforce no wildcard in IAM across all clouds via OPA/Sentinel policy
deny[msg] {
  input.resource.type == "aws_iam_policy"
  statement := input.resource.attributes.statement[_]
  statement.actions[_] == "*"
  msg := "Wildcard actions (*) are not allowed in IAM policies"
}
```

---

### Q5. An organization is running 70% AWS, 20% Azure, and 10% GCP. How do you establish a unified observability platform?

**Answer:**

**Strategy: OpenTelemetry as the abstraction layer + Grafana stack for visualization**

```
                    ┌──────────────────────────────────┐
                    │     Grafana (Unified UI)         │
                    │  Dashboards / Alerts / Explore   │
                    └──────┬─────────────┬─────────────┘
                           │             │
               ┌───────────▼──┐   ┌──────▼───────────┐
               │  Prometheus  │   │    Loki (Logs)    │
               │  (Metrics)   │   │  + Tempo (Traces) │
               └──────┬───────┘   └──────┬────────────┘
                      │                  │
         ┌────────────▼──────────────────▼──────────┐
         │        OpenTelemetry Collector            │
         │   (Deployed as DaemonSet on EKS/AKS/GKE)│
         └───────┬──────────────┬───────────────────┘
                 │              │
    ┌────────────▼──┐   ┌───────▼────────────────┐
    │  AWS Sources  │   │  Azure / GCP Sources   │
    │ CloudWatch    │   │  Azure Monitor          │
    │ X-Ray         │   │  Cloud Logging          │
    │ EKS metrics   │   │  GKE metrics            │
    └───────────────┘   └────────────────────────┘
```

**Implementation decisions:**

1. **OTel SDK in all applications** — Language-specific SDKs emit traces, metrics, logs to OTel Collector endpoints (no cloud-specific SDK dependency)

2. **OTel Collector per cluster** — Receives telemetry, applies processors (sampling, filtering, enrichment), fans out to:
   - Prometheus remote_write for metrics
   - Loki for logs
   - Tempo for traces

3. **Cloud-native forwarding** — Use OTel receivers for native cloud telemetry:
   - `awscloudwatchreceiver` for CloudWatch Logs/Metrics
   - `azuremonitorreceiver` for Azure Monitor
   - `googlecloudreceiver` for Cloud Logging

4. **Grafana as single pane of glass** — All data sources connected; cross-cloud correlation via trace IDs propagated in headers

5. **SLO/SLI tracking** — Define SLOs in Grafana SLO plugin against Prometheus metrics regardless of cloud

---

### Q6. How do you handle cloud cost transparency across AWS, Azure, and GCP?

**Answer:**

**FinOps maturity model I follow:**

```
Phase 1: Inform    → Tag everything, export costs to central data lake
Phase 2: Optimize  → Rightsizing, reserved capacity, eliminate waste
Phase 3: Operate   → Chargeback/showback, engineering teams own costs
```

**Architecture for multi-cloud cost visibility:**

```
AWS Cost Explorer ──────────────────────────┐
Azure Cost Management ───────────────────── ► S3/GCS data lake (Parquet)
GCP Billing Export to BigQuery ─────────────┘        │
                                              ┌───────▼─────────┐
                                              │ dbt / Databricks │
                                              │ (normalization)  │
                                              └───────┬─────────┘
                                                      │
                                              ┌───────▼─────────┐
                                              │   Grafana /     │
                                              │   QuickSight /  │
                                              │   Looker Studio │
                                              └─────────────────┘
```

**Mandatory tagging strategy:**

```
Required tags (enforced via SCPs/Policy/OPA):
  - Environment:    prod | staging | dev | sandbox
  - Team:           platform | payments | identity | data
  - Product:        checkout | auth | analytics
  - CostCenter:     CC-1001 | CC-1002
  - ManagedBy:      terraform | manual
  - Version:        1.2.3 (application version)
```

**AWS-specific FinOps actions:**

- Savings Plans (Compute) + Reserved Instances for RDS/ElastiCache
- AWS Compute Optimizer for rightsizing recommendations
- S3 Intelligent-Tiering for data at rest
- Auto-shutdown of dev environments with Lambda + EventBridge

**Chargeback implementation:**

- Tag-based cost allocation → monthly reports to each team
- Engineering teams see their cloud bill in Slack (#cloud-costs-team-X)
- Budget alerts via SNS/email at 80% and 100% of monthly budget

---

### Q7. Walk us through a real architecture decision you made between using managed services vs. building on Kubernetes

**Answer:**

**Scenario:** A streaming data pipeline team wanted to self-host Kafka on EKS for "full control."

**Decision framework I applied:**

| Consideration | Self-hosted Kafka on EKS | Amazon MSK (Managed Kafka) |
|--------------|--------------------------|---------------------------|
| Operational burden | High (upgrade, monitoring, rebalancing, ZK/KRaft) | Low (AWS manages broker patching) |
| Cost (3-year, 3 brokers, r5.2xlarge) | ~$18K/yr compute + 30% ops overhead | ~$22K/yr but zero ops |
| Flexibility | Full (any plugin, version, tuning) | Partial (approved configs, limited versions) |
| Security | Manual TLS, mTLS ACLs | Built-in mTLS, IAM auth, VPC-native |
| Disaster recovery | Manual cross-AZ, replication scripts | Multi-AZ native, MirrorMaker2 built-in |
| Team expertise | Strong Kafka admins needed | Any engineer can operate |

**My recommendation:** Use MSK — the 20% cost premium is recovered in 2 engineers' time saved per year.

**The trade-off I acknowledged:** If the team needed Kafka features MSK doesn't support (e.g., specific connectors, Kafka Streams on custom JVM settings), then self-hosted on EKS with Strimzi operator would be the right answer. **Never managed-service-for-managed-service's-sake.**

**ADR outcome:**

- Used MSK for production streaming
- Used Strimzi on EKS for teams needing connector flexibility
- Documented the trade-off and revisited 6 months later (MSK caught up with connector support — migrated Strimzi workloads too)

---

### Q8. How do you architect for blast radius containment in a multi-cloud environment?

**Answer:**

**Blast radius = the maximum damage caused by a single failure event.**

**Five layers of containment I design:**

**Layer 1: Account/Subscription isolation (broadest)**

```
Production accounts are completely separate AWS accounts.
No shared VPCs between prod and non-prod.
AWS Organizations SCPs prevent cross-account escalation.
```

**Layer 2: Network segmentation**

```
Production VPC → isolated, no peering to dev/staging
All cross-account access → PrivateLink endpoints only (no VPC peering for prod data)
Security groups: least-privilege, no 0.0.0.0/0 inbound
```

**Layer 3: IAM least privilege**

```
Deployment roles: write access limited to single service/namespace
No admin roles attached to CI/CD pipelines
Break-glass roles: MFA required + session recording + CloudTrail alert
```

**Layer 4: Kubernetes namespace isolation**

```
One namespace per team (not one cluster per team — too expensive)
NetworkPolicy: deny all ingress/egress by default, explicitly allow
ResourceQuotas per namespace to prevent noisy-neighbor
OPA Gatekeeper: enforce image registry allowlist, no privileged containers
```

**Layer 5: Progressive delivery**

```
All production changes: Canary → 5% → 25% → 100%
Automated rollback on error rate spike (Argo Rollouts + Prometheus)
Feature flags for application-level blast radius containment
```

---

## Section 2: Landing Zones & Account/Subscription Structures {#section-2}

---

### Q9. Design a multi-cloud landing zone for an enterprise with 200+ engineering teams. What's your account/subscription structure?

**Answer:**

**AWS Organizations structure:**

```
Root
├── Security OU
│   ├── Log Archive Account (all CloudTrail, Config, GuardDuty logs)
│   └── Security Tooling Account (SIEM, GuardDuty admin, Security Hub)
├── Infrastructure OU
│   ├── Shared Services Account (DNS, Transit Gateway, Container Registry)
│   └── Network Account (Transit Gateway Hub, Direct Connect)
├── Workloads OU
│   ├── Production OU
│   │   ├── Payments Prod Account
│   │   ├── Identity Prod Account
│   │   └── Analytics Prod Account
│   ├── Non-Production OU
│   │   ├── Payments Dev Account
│   │   └── Payments Staging Account
│   └── Sandbox OU (engineers can experiment freely here)
└── Management Account (billing, AWS Control Tower only — no workloads)
```

**Key principles:**

- **Management account**: Billing + Control Tower ONLY. No workloads. Ever.
- **Log archive**: Immutable — no one can delete logs except the CISO account
- **Sandbox OU**: Hard budget cap of $500/month/account; auto-nuke after 30 days
- **One account per environment per product** — prevents dev from blasting prod

**Azure equivalent:**

```
Management Group: Root
├── Platform Management Group
│   ├── Identity Subscription (Azure AD DS, Key Vault central)
│   ├── Management Subscription (Log Analytics, Sentinel)
│   └── Connectivity Subscription (Virtual WAN Hub, ExpressRoute)
├── Landing Zones Management Group
│   ├── Production Management Group
│   │   └── [Product]-Prod Subscriptions
│   └── Non-Production Management Group
│       └── [Product]-Dev/Stage Subscriptions
└── Sandbox Management Group
```

**GCP equivalent:**

```
Organization: company.com
├── folders/platform
│   ├── projects/shared-vpc-host
│   └── projects/logging-central
├── folders/production
│   └── projects/[product]-prod
└── folders/sandbox
```

---

### Q10. How do you enforce guardrails in a landing zone without becoming a bottleneck?

**Answer:**

**The principle:** Guardrails should be **automated and preventive**, not **manual and detective**. If security says "no" at the end of a process, you're already too late.

**Three categories of controls:**

| Type | Tool | Examples |
|------|------|---------|
| **Preventive** (hard stop) | SCPs (AWS), Azure Policy, Org Policy (GCP) | Deny public S3 buckets, deny unapproved regions, require CMK encryption |
| **Detective** (alert + remediate) | AWS Config Rules, Security Hub, Defender for Cloud | Alert on missing tags, auto-remediate open security groups |
| **Proactive** (catch before deploy) | OPA in CI/CD, Terraform Sentinel, Checkov | Block Terraform plan if it creates an open security group |

**AWS SCP examples I always implement:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyRootAccount",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "*",
      "Condition": {
        "StringLike": { "aws:PrincipalArn": "arn:aws:iam::*:root" }
      }
    },
    {
      "Sid": "DenyLeavingOrganization",
      "Effect": "Deny",
      "Action": "organizations:LeaveOrganization",
      "Resource": "*"
    },
    {
      "Sid": "DenyPublicS3",
      "Effect": "Deny",
      "Action": [
        "s3:PutBucketPublicAccessBlock",
        "s3:DeletePublicAccessBlock"
      ],
      "Resource": "*"
    }
  ]
}
```

**Terraform + OPA (Conftest) in CI:**

```python
# policy/aws_security.rego
package main

deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_security_group_rule"
  resource.change.after.cidr_blocks[_] == "0.0.0.0/0"
  resource.change.after.from_port == 22
  msg := sprintf("Security group rule '%s' allows SSH from 0.0.0.0/0", [resource.address])
}
```

```yaml
# In GitHub Actions CI
- name: Run OPA Policy Checks
  run: |
    terraform plan -out=tfplan.binary
    terraform show -json tfplan.binary > tfplan.json
    conftest test tfplan.json --policy policies/
```

---

### Q11. What is AWS Control Tower and when would you use it vs. rolling your own landing zone?

**Answer:**

**AWS Control Tower** is AWS's managed service for setting up and governing a multi-account environment.

**What it gives you out of the box:**

- Automated account vending (Account Factory)
- Pre-built guardrails (~350 proactive + detective controls)
- CloudTrail + Config enabled in all accounts by default
- Log Archive and Audit accounts pre-configured
- IAM Identity Center (SSO) pre-integrated
- Drift detection and remediation

**When to use Control Tower:**

| Scenario | Recommendation |
|---------|---------------|
| Greenfield enterprise setup | ✅ Use Control Tower |
| Existing AWS Organizations with custom structure | ⚠️ Complex migration; evaluate carefully |
| Need full customization of SCP hierarchy | ⚠️ Control Tower limits some SCP flexibility |
| < 20 accounts, small team | Consider custom Terraform + AWS Organizations |
| Regulated industry with specific controls | ✅ Use Control Tower + Account Factory for Terraform (AFT) |

**Control Tower + AFT (Account Factory for Terraform) — my preferred approach:**

```
Account Factory for Terraform = IaC wrapper around Control Tower
→ Version-controlled account vending
→ Custom account templates (e.g., data-team template includes Glue, S3 prebuilt)
→ Customizations applied after account creation via Lambda hooks
```

**Limitations I always flag:**

- Control Tower is AWS-only; for Azure/GCP you need separate mechanisms
- Updates to Control Tower guardrails can drift from your custom Terraform
- Landing Zone Accelerator (LZA) is the recommended path for highly regulated environments (HIPAA, FedRAMP)

---

### Q12. How do you automate account vending for 200+ teams without becoming a bottleneck?

**Answer:**

**Self-service account vending pipeline:**

```
Developer Portal (Backstage/ServiceNow)
        │
        ▼
Pull Request to Account Request Repo
(account-requests/payments-team-prod.yaml)
        │
        ▼
GitHub Actions: Validate request
(team name, environment, budget, compliance profile)
        │
        ▼
Terraform Apply: AWS AFT triggers
  → Create AWS Account via Organizations
  → Apply baseline: logging, GuardDuty, Config, SecurityHub
  → Apply team-specific customization (compliance profile)
  → Attach correct SCPs
  → Create Terraform backend (S3 bucket + DynamoDB)
  → Bootstrap IAM roles for team's CI/CD
        │
        ▼
Notification: Slack + email with account ID and access instructions
```

**Account request YAML:**

```yaml
# account-requests/payments-team-prod.yaml
account_name: "payments-prod"
account_email: "aws-payments-prod@company.com"
ou: "production/payments"
compliance_profile: "pci-dss"
cost_center: "CC-1050"
team: "payments-engineering"
budget_monthly_usd: 15000
contact_email: "payments-lead@company.com"
```

**Time from request to ready account:** ~45 minutes (fully automated).

---

### Q13. How do you design hybrid connectivity between on-premises and three clouds?

**Answer:**

**Connectivity topology:**

```
On-Premises Data Center
     │
     ├── AWS Direct Connect (10Gbps dedicated)
     │        └── Direct Connect Gateway → multiple VPCs/regions
     │
     ├── Azure ExpressRoute (10Gbps dedicated)
     │        └── ExpressRoute Gateway → Virtual WAN Hub
     │
     └── GCP Cloud Interconnect (10Gbps dedicated)
              └── Cloud Router (BGP peering)

All three: BGP over private circuits; no traffic over public internet.
Failover: IPSec VPN as backup for each circuit.
```

**SD-WAN for branch offices (if applicable):**

```
Branch Office → SD-WAN appliance (VMware VeloCloud / Cisco Meraki)
  → Intelligent routing: AWS Direct Connect for AWS-destined traffic
  → ExpressRoute for Azure-destined traffic
  → Internet breakout for GCP (if Cloud Interconnect not cost-justified)
```

**Critical design decisions:**

1. **Transitive routing via AWS Transit Gateway:**
   - Attach all VPCs to TGW
   - Connect Direct Connect Gateway to TGW
   - Route tables control which VPCs can reach on-premises
   - Cost: $0.02/GB processed through TGW

2. **DNS resolution across clouds:**

   ```
   Central DNS: Route 53 Resolver (private hosted zones)
   → Conditional forwarders to Azure Private DNS zones
   → Conditional forwarders to GCP Cloud DNS
   → On-prem DNS forwards *.aws.internal to Route 53 Resolver inbound endpoint
   ```

3. **Avoid VPC peering for large-scale connectivity:**
   - VPC peering = N×(N-1)/2 connections (doesn't scale)
   - Transit Gateway = hub-and-spoke (scales to thousands of VPCs)

---

### Q14. Compare AWS Transit Gateway vs. Azure Virtual WAN vs. GCP VPC Peering for enterprise networking

**Answer:**

| Feature | AWS Transit Gateway | Azure Virtual WAN | GCP VPC Peering |
|---------|--------------------|--------------------|-----------------|
| **Model** | Hub-and-spoke; explicit route tables | Managed SD-WAN backbone | Direct peering between VPCs |
| **Transitive routing** | ✅ Yes (explicit) | ✅ Yes (any-to-any in hub) | ❌ No (non-transitive) |
| **Scale** | Up to 5,000 attachments | Global scale, Microsoft managed | Up to 25 peering connections per VPC |
| **Cross-region** | TGW peering (manual setup) | Built-in (Standard SKU) | Not applicable (GCP VPCs are global) |
| **Direct Connect / ExpressRoute** | Direct Connect Gateway → TGW | Built-in to vWAN hub | Cloud Interconnect |
| **Pricing** | $0.05/hr/attachment + $0.02/GB | $0.25/hr per hub + data processing | Free (pay only for data transfer) |
| **Routing control** | Granular route tables per attachment | Less granular; Microsoft manages | Limited; must avoid CIDR overlap |

**My recommendation by scenario:**

- **Large AWS deployment (50+ VPCs):** Always Transit Gateway. The operational cost of managing VPC peering at scale is prohibitive.
- **Azure hybrid (branches + cloud):** Virtual WAN Standard tier. Built-in VPN/ExpressRoute integration.
- **GCP:** VPC is global by default — often you don't need peering at all. Use Shared VPC (host/service project model) for team isolation.

---

## Section 3: Terraform & Infrastructure-as-Code at Scale {#section-3}

---

### Q15. How do you structure Terraform code for a large organization with 50+ teams and multiple clouds?

**Answer:**

**Repository strategy — I use a 3-repo model:**

```
terraform-modules/          (shared library; versioned)
├── aws/
│   ├── vpc/
│   ├── eks/
│   ├── rds-aurora/
│   └── ...
├── azure/
│   ├── vnet/
│   ├── aks/
│   └── ...
└── gcp/
    ├── gke/
    └── ...

terraform-platform/         (platform team infrastructure)
├── environments/
│   ├── prod/
│   │   ├── networking/
│   │   ├── eks-clusters/
│   │   └── shared-services/
│   └── staging/
└── modules/ (platform-specific composition modules)

terraform-workloads/        (per-team, per-product infrastructure)
├── payments/
│   ├── prod/
│   └── staging/
└── analytics/
    ├── prod/
    └── staging/
```

**Module versioning strategy:**

```hcl
# teams reference pinned versions — never "latest"
module "eks" {
  source  = "git::https://github.com/org/terraform-modules.git//aws/eks?ref=v3.2.1"
  
  cluster_name    = "payments-prod"
  cluster_version = "1.31"
  # ...
}
```

**Why pinned versions?**

- A module change doesn't accidentally break 50 teams
- Release notes document breaking changes
- Teams opt-in to upgrades on their own schedule

**Directory structure within a module:**

```
modules/aws/eks/
├── main.tf           # Resources
├── variables.tf      # Input variables (typed, with descriptions)
├── outputs.tf        # Outputs for consumers
├── versions.tf       # Required providers + versions
├── README.md         # Usage examples (terraform-docs generated)
└── examples/
    ├── basic/
    └── production/   # Tests as examples
```

---

### Q16. Explain your Terraform remote state strategy. How do you handle state sharing between modules?

**Answer:**

**State architecture:**

```
State Backend: S3 + DynamoDB (AWS) / Azure Blob + Cosmos DB lock / GCS (GCP)

State Organization:
s3://company-tfstate/
├── platform/
│   ├── networking/prod/terraform.tfstate
│   ├── eks/prod/terraform.tfstate
│   └── shared-services/prod/terraform.tfstate
└── workloads/
    ├── payments/prod/terraform.tfstate
    └── analytics/prod/terraform.tfstate
```

**State isolation principles:**

1. **One state file per blast radius** — Networking state separate from application state. A bug in app Terraform can't destroy your VPC.

2. **Never share state files between teams** — Concurrent applies → state lock conflicts

3. **Cross-state references via `terraform_remote_state`:**

```hcl
# In workloads/payments/prod/main.tf
# Reference networking outputs without coupling state files
data "terraform_remote_state" "networking" {
  backend = "s3"
  config = {
    bucket = "company-tfstate"
    key    = "platform/networking/prod/terraform.tfstate"
    region = "us-east-1"
  }
}

resource "aws_db_subnet_group" "payments" {
  subnet_ids = data.terraform_remote_state.networking.outputs.private_subnet_ids
}
```

1. **Better alternative — SSM Parameter Store or outputs:** For loose coupling between teams:

```hcl
# Platform team writes outputs to SSM
resource "aws_ssm_parameter" "private_subnet_ids" {
  name  = "/platform/networking/prod/private_subnet_ids"
  type  = "StringList"
  value = join(",", aws_subnet.private[*].id)
}

# Workload team reads from SSM (no state dependency)
data "aws_ssm_parameter" "private_subnet_ids" {
  name = "/platform/networking/prod/private_subnet_ids"
}
```

**S3 backend configuration with all security best practices:**

```hcl
terraform {
  backend "s3" {
    bucket         = "company-tfstate-prod"
    key            = "platform/eks/prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true                      # Server-side encryption
    kms_key_id     = "arn:aws:kms:us-east-1:123456789:key/abc"
    dynamodb_table = "company-tfstate-locks"   # DynamoDB for state locking
    
    # Prevent accidental state deletion
    versioning     = true
  }
}
```

---

### Q17. How do you implement Terraform workspaces and when do you prefer workspaces vs. separate state files?

**Answer:**

**Terraform workspaces** create separate state files within the same backend key prefix.

```
terraform workspace new staging
terraform workspace new prod
terraform workspace select prod
terraform apply
```

**When workspaces make sense:**

| Scenario | Workspaces? |
|---------|------------|
| Identical infrastructure in dev/staging/prod (same config, different vars) | ✅ Yes |
| Temporary feature branch environments (Atlantis PR environments) | ✅ Yes |
| Fundamentally different infrastructure per environment (prod has extra security, different sizing) | ❌ Use separate directories |
| More than ~10 workspaces (operational complexity) | ❌ Consider separate state files |

**The problem with workspaces at scale:**

```bash
# With 50 teams and 3 environments each = 150 workspaces
# terraform workspace list → overwhelming
# No per-workspace access control (all share same backend config)
# Easy to accidentally apply to wrong workspace
```

**My recommendation:** For environments (dev/staging/prod), use **separate directories with separate state files**. Reserve workspaces for **ephemeral environments** (PR-based preview environments with Atlantis).

**Atlantis for PR-based environments:**

```yaml
# atlantis.yaml
projects:
- name: payments-prod
  dir: workloads/payments/prod
  workspace: default
  autoplan:
    when_modified: ["*.tf", "../../../modules/**/*.tf"]
```

```
Developer opens PR → Atlantis posts: "terraform plan output"
Reviewer approves plan → Merge PR → Atlantis applies
Ephemeral PR environment: workspace = pr-{number}
```

---

### Q18. How do you implement policy-as-code in Terraform? Compare OPA/Conftest vs. Sentinel vs. Checkov

**Answer:**

**Three tools, three integration points:**

```
Code Commit
    │
    ▼
[Checkov] ──────────── Static analysis of .tf files (pre-plan)
    │
    ▼
[OPA/Conftest] ──────── Validates terraform plan JSON (post-plan)
    │
    ▼
[Sentinel] (HCP/TFE) ── Policy-as-code in Terraform Enterprise (post-plan, pre-apply)
```

**1. Checkov (static analysis):**

```yaml
# .github/workflows/terraform.yml
- name: Run Checkov
  uses: bridgecrewio/checkov-action@master
  with:
    directory: .
    framework: terraform
    output_format: sarif
    check: CKV_AWS_18,CKV_AWS_19   # Specific checks
    skip_check: CKV_AWS_50         # Skip with justification in comment
```

Checkov detects: missing encryption, public exposure, missing logging, weak security group rules — before `terraform plan`.

**2. OPA/Conftest (plan validation):**

```python
# policies/required_tags.rego
package main

required_tags := {"Environment", "Team", "CostCenter"}

deny[msg] {
  resource := input.resource_changes[_]
  resource.change.after != null  # Resource being created/updated
  missing := required_tags - {tag | resource.change.after.tags[tag]}
  count(missing) > 0
  msg := sprintf(
    "Resource '%s' missing required tags: %v",
    [resource.address, missing]
  )
}
```

```bash
terraform plan -out=plan.binary
terraform show -json plan.binary | conftest test - --policy policies/
```

**3. Sentinel (Terraform Enterprise/Cloud):**

```python
# sentinel/require-module-version.sentinel
import "tfplan/v2" as tfplan

# All module calls must reference a version tag
main = rule {
  all tfplan.module_calls as _, call {
    call.source matches "^git::"
    call.version_constraint != ""
  }
}
```

**Comparison:**

| Feature | Checkov | OPA/Conftest | Sentinel |
|---------|---------|--------------|---------|
| **Where it runs** | Pre-plan (static) | Post-plan | Post-plan (TFE/TFC only) |
| **Language** | Python (rules built-in) | Rego | Sentinel DSL |
| **Cost** | Free (OSS) | Free (OSS) | TFE/TFC license |
| **Community rules** | 1000+ built-in | Write your own | Hashicorp-provided |
| **Best for** | Quick security scan, CI gate | Complex custom policies | Enterprise TFE environments |

**My stack:** Checkov in CI pre-plan + OPA/Conftest post-plan for custom policies. Sentinel only if customer uses Terraform Enterprise.

---

### Q19. How do you handle Terraform drift detection and remediation in production?

**Answer:**

**Drift = the gap between what Terraform thinks exists and what actually exists in the cloud.**

**Causes of drift:**

- Manual console changes ("I'll just quickly fix this in the console...")
- Cloud provider changes (AWS patches a security group automatically)
- Other automation (Lambda auto-remediation fighting with Terraform)
- Terraform state corruption

**Drift detection strategy:**

```bash
# 1. Scheduled terraform plan in CI (every 6 hours)
terraform plan -detailed-exitcode
# Exit code 0 = no changes
# Exit code 1 = error
# Exit code 2 = changes detected (drift)
```

**GitHub Actions scheduled drift detection:**

```yaml
name: Drift Detection
on:
  schedule:
    - cron: '0 */6 * * *'  # Every 6 hours

jobs:
  detect-drift:
    runs-on: ubuntu-latest
    steps:
      - name: Terraform Plan
        id: plan
        run: terraform plan -detailed-exitcode
        continue-on-error: true
        
      - name: Alert on Drift
        if: steps.plan.outputs.exitcode == '2'
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "⚠️ Terraform drift detected in prod/networking",
              "attachments": [{"text": "${{ steps.plan.outputs.stdout }}"}]
            }
```

**Remediation options:**

| Scenario | Action |
|---------|--------|
| Expected drift (safe manual change) | `terraform import` to bring resource into state, commit |
| Unauthorized drift (security issue) | Immediate incident; use `terraform apply` to restore known good state |
| Drift from cloud-provider changes | Update Terraform code to reflect the new reality, apply |
| Stale state (resource deleted outside TF) | `terraform state rm` to remove from state |

**Tools:**

- **driftctl** (OSS): Comprehensive drift detection with coverage percentage
- **Atlantis**: Drift detection + auto-remediation via PRs
- **Spacelift / env0**: Drift detection with approval workflows

---

### Q20. What is your strategy for managing Terraform module upgrades across 50 teams?

**Answer:**

**The problem:** You release `modules/aws/eks` v4.0.0 with breaking changes. 50 teams reference it. You can't force-upgrade everyone at once.

**Module versioning + upgrade workflow:**

```
1. Semantic versioning: MAJOR.MINOR.PATCH
   - MAJOR: Breaking changes (variable renamed, resource replaced)
   - MINOR: New features, backward compatible
   - PATCH: Bug fixes

2. CHANGELOG.md: Document every change with migration guide

3. Deprecation policy:
   - Support current + 2 previous major versions
   - 90-day deprecation window: teams notified
   - After 90 days: CI warns if team uses deprecated version
   - After 180 days: CI blocks if team uses unsupported version
```

**Automated dependency scanning:**

```python
# .github/workflows/module-version-check.yml
- name: Check module versions
  run: |
    # Find all module references and check against minimum version
    grep -r 'source.*terraform-modules' --include="*.tf" | \
    python scripts/check_module_versions.py --min-versions modules-policy.yaml
```

**Migration support:**

1. Write migration guide in CHANGELOG
2. Provide a migration script where possible
3. Offer office hours for teams hitting upgrade issues
4. Track compliance on a dashboard (which teams on which versions)

---

### Q21. How do you implement Terraform in a regulated environment (HIPAA/PCI/SOC2)?

**Answer:**

**Compliance-as-code approach:**

**1. Custom compliance module library:**

```hcl
# modules/aws/s3-hipaa/main.tf — pre-built compliant S3 bucket
resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn  # Customer-managed KMS key
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "this" {
  bucket        = aws_s3_bucket.this.id
  target_bucket = var.access_log_bucket
  target_prefix = "${var.bucket_name}/"
}
```

Teams use `modules/aws/s3-hipaa` and compliance is guaranteed by the module itself.

**2. Mandatory compliance tags enforced in CI:**

```python
# OPA policy: HIPAA data assets must have data-classification tag
deny[msg] {
  resource := input.resource_changes[_]
  resource.type in {"aws_s3_bucket", "aws_rds_cluster", "aws_dynamodb_table"}
  not resource.change.after.tags["DataClassification"]
  msg := sprintf("HIPAA resource '%s' requires DataClassification tag", [resource.address])
}
```

**3. Audit trail:**

```hcl
# All Terraform runs produce a signed audit log
# Terraform Cloud / Atlantis logs who ran apply, what changed, when
# CloudTrail captures the actual API calls

# Immutable state versioning in S3
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration { status = "Enabled" }
}

# MFA delete protection on state bucket
resource "aws_s3_bucket_versioning" "tfstate_mfa" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status     = "Enabled"
    mfa_delete = "Enabled"  # Requires MFA to delete versions
  }
}
```

---

### Q22. What is your approach to Terraform testing?

**Answer:**

**Terraform testing pyramid:**

```
         ┌──────────────────┐
         │   E2E Tests      │  ← Real cloud resources, slow/expensive
         │  (Terratest)     │    Run nightly or pre-release
         ├──────────────────┤
         │ Integration Tests │  ← Real resources, scoped
         │ (Terraform test) │    Run per PR for affected modules
         ├──────────────────┤
         │   Unit Tests     │  ← No cloud calls; validate logic
         │ (OPA, Checkov,   │    Run on every commit
         │  terraform validate) │
         └──────────────────┘
```

**1. Static validation (always):**

```bash
terraform fmt -check          # Formatting
terraform validate            # Syntax + provider validation
checkov --directory .         # Security policy
conftest test tfplan.json     # Custom OPA policies
```

**2. Terraform native tests (`.tftest.hcl`):**

```hcl
# modules/aws/eks/tests/basic.tftest.hcl
variables {
  cluster_name    = "test-cluster"
  cluster_version = "1.31"
  vpc_id          = "vpc-test"
}

run "verify_cluster_name" {
  command = plan
  assert {
    condition     = aws_eks_cluster.this.name == "test-cluster"
    error_message = "Cluster name does not match expected value"
  }
}

run "verify_encryption_enabled" {
  command = plan
  assert {
    condition     = aws_eks_cluster.this.encryption_config[0].resources[0] == "secrets"
    error_message = "EKS secrets encryption must be enabled"
  }
}
```

**3. Terratest (Go-based, real resources):**

```go
// test/eks_test.go
func TestEKSCluster(t *testing.T) {
  terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
    TerraformDir: "../examples/production",
    Vars: map[string]interface{}{
      "cluster_name": "test-" + random.UniqueId(),
    },
  })
  
  defer terraform.Destroy(t, terraformOptions)  // Always clean up
  terraform.InitAndApply(t, terraformOptions)
  
  clusterName := terraform.Output(t, terraformOptions, "cluster_name")
  assert.NotEmpty(t, clusterName)
  
  // Verify cluster is ACTIVE in AWS
  cluster := aws.GetEksCluster(t, clusterName, "us-east-1")
  assert.Equal(t, "ACTIVE", *cluster.Status)
}
```

---

## Section 4: Multi-Cloud Networking Deep Dive {#section-4}

---

### Q23. Explain how you design a zero-trust network architecture across AWS and Azure

**Answer:**

**Zero-trust principle:** Never trust, always verify — regardless of network location.

**Traditional (perimeter-based) vs Zero-trust:**

```
Traditional:
  Internet → Firewall → Trusted Zone (everything inside can talk to everything)

Zero-trust:
  Internet → Firewall → Identity Verification → Per-request authorization
  Even internal traffic requires authentication + authorization
```

**AWS zero-trust implementation:**

```
Layer 1: Network level
- Private subnets for all workloads (no public IPs on EC2/EKS nodes)
- Security groups: Deny all by default; allow only specific ports/protocols
- NACLs: Subnet-level stateless firewall for additional segmentation
- VPC Flow Logs: All traffic logged for analysis

Layer 2: Workload identity (mTLS)
- AWS Certificate Manager (ACM) + ACM Private CA for internal certificates
- Service mesh (Istio/App Mesh): mTLS between all services
- Each workload has a SPIFFE identity (SVID) automatically rotated

Layer 3: Application level
- IAM authentication for all AWS API calls (no hardcoded credentials)
- Amazon Verified Permissions for fine-grained authorization
- JWT token validation at API Gateway for external requests

Layer 4: Data level
- Encryption at rest (KMS CMKs, not AWS-managed keys for sensitive data)
- Encryption in transit (TLS 1.2 minimum, TLS 1.3 preferred)
- Field-level encryption for PII in DynamoDB
```

**AWS + Azure zero-trust integration:**

```
AWS Workload (EKS)  ←──── mTLS (Istio) ────►  Azure Workload (AKS)
       │                                              │
       ▼                                              ▼
AWS IAM (IRSA)                              Azure Managed Identity
       │                                              │
       └──────────── Shared HashiCorp Vault ──────────┘
                     (Unified secrets + PKI)
```

---

### Q24. How do you handle DNS in a multi-cloud environment with both public and private resolution?

**Answer:**

**DNS architecture:**

```
                    Internet
                       │
                    Route 53
                 (Public Hosted Zones)
               api.company.com → ALB
               
                   ┌─────────────────────────────────────┐
                   │         Private DNS Resolution      │
                   │                                     │
    AWS VPCs:      │   Route 53 Private Hosted Zones     │
    *.aws.internal │   Resolver Inbound Endpoint         │
                   │   Resolver Outbound Endpoint        │
                   │                                     │
    Azure VNets:   │   Azure Private DNS Zones           │
    *.azure.internal│  *.privatelink.*.core.windows.net  │
                   │                                     │
    On-Premises:   │   BIND/AD DNS                       │
    *.corp.internal│   Forwarders                        │
                   └─────────────────────────────────────┘
```

**Cross-cloud DNS resolution:**

```hcl
# AWS: Forward azure.internal queries to Azure DNS resolver
resource "aws_route53_resolver_rule" "azure_dns" {
  domain_name          = "azure.internal"
  rule_type            = "FORWARD"
  resolver_endpoint_id = aws_route53_resolver_endpoint.outbound.id
  
  target_ip {
    ip   = "10.100.0.4"   # Azure DNS resolver (always 168.63.129.16 or custom)
    port = 53
  }
}

# Azure: Forward aws.internal queries to Route 53 resolver
# Azure Private DNS Resolver → Forwarding Rule for *.aws.internal → Route 53 inbound (10.0.0.4)
```

**Split-horizon DNS:**

```
Public: api.company.com → Public ALB (203.0.113.10)
Private: api.company.com → Internal ALB (10.1.100.50)

Same name, different answer based on where you query from.
AWS: Route 53 Private Hosted Zone overrides public for VPC-associated queries.
```

---

### Q25. Explain VPC peering vs. Transit Gateway vs. PrivateLink. When do you use each?

**Answer:**

**Mental model:**

```
VPC Peering   = Direct cable between two VPCs (1:1, non-transitive)
Transit Gateway = Airport hub (many VPCs connect to hub, route between them)
PrivateLink    = Service endpoint (consume a service without full network access)
```

**Detailed comparison:**

| Feature | VPC Peering | Transit Gateway | PrivateLink |
|---------|-------------|-----------------|-------------|
| **Topology** | 1:1 | Hub-and-spoke (N:M) | Service-consumer model |
| **Transitive routing** | ❌ No | ✅ Yes | N/A |
| **Cross-region** | ✅ (Inter-region peering) | ✅ (TGW peering) | ✅ (AWS services) |
| **Cross-account** | ✅ (requires accept) | ✅ | ✅ |
| **Scale** | ~125 connections/VPC limit | 5,000 attachments | Scales to millions of connections |
| **Cost** | Free + data transfer | $0.05/hr/attachment + $0.02/GB | $0.01/hr/endpoint + $0.01/GB |
| **Use case** | 2-5 VPCs, simple | 5+ VPCs, full mesh | Expose service to consumers |
| **Security** | Full VPC access | Full VPC access | Only specific service/port |

**Decision tree:**

```
Are you connecting > 5 VPCs?
  └── YES → Use Transit Gateway
  └── NO → Are you connecting same region?
               └── YES → VPC Peering (cheaper, simpler)
               └── NO → TGW inter-region peering (better routing control)

Do you want to expose a service to another team/account securely?
  └── YES → PrivateLink (most secure — service consumer has no network access)
  └── NO → Peering or TGW
```

**PrivateLink for internal services:**

```hcl
# Team A: Expose payment service via PrivateLink
resource "aws_vpc_endpoint_service" "payments" {
  acceptance_required        = false
  network_load_balancer_arns = [aws_lb.payments_nlb.arn]
  
  allowed_principals = [
    "arn:aws:iam::${var.checkout_account_id}:root"
  ]
}

# Team B: Consume via endpoint (no routing, no peering needed)
resource "aws_vpc_endpoint" "payments" {
  service_name       = "com.amazonaws.vpce.us-east-1.vpce-svc-xxx"
  vpc_id             = var.vpc_id
  subnet_ids         = var.private_subnet_ids
  security_group_ids = [aws_security_group.payments_endpoint.id]
  vpc_endpoint_type  = "Interface"
}
```

---

### Q26. How do you design network security for EKS in a production environment?

**Answer:**

**Defense-in-depth for EKS networking:**

```
Internet
   │
   ▼
Route 53 (DNS + DDoS via Shield Advanced)
   │
   ▼
AWS WAF (Layer 7 rules: SQL injection, XSS, rate limiting)
   │
   ▼
Application Load Balancer (in public subnets)
   │
   ▼
Ingress Controller (nginx/AWS LBC — in private subnets)
   │
   ▼
Kubernetes Service → Pod (in private subnets)
                        │
              Istio sidecar (mTLS within cluster)
```

**Critical EKS security configurations:**

```hcl
# 1. API server: private endpoint only
resource "aws_eks_cluster" "prod" {
  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = false  # No public kubectl access
    public_access_cidrs     = []
  }
}

# 2. Node groups in private subnets only
resource "aws_eks_node_group" "workers" {
  subnet_ids = var.private_subnet_ids  # Never public subnets
}
```

**Kubernetes NetworkPolicy (Calico/Cilium):**

```yaml
# Default deny all ingress/egress in production namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: payments
spec:
  podSelector: {}  # Applies to all pods in namespace
  policyTypes:
  - Ingress
  - Egress

---
# Allow specific communication
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-payments-api
  namespace: payments
spec:
  podSelector:
    matchLabels:
      app: payments-api
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: checkout  # Only from checkout namespace
    ports:
    - protocol: TCP
      port: 8080
```

**Security group for pods (EKS native, not Calico):**

```hcl
# Associate specific security groups with pods (not nodes)
resource "aws_eks_pod_identity_association" "payments_db" {
  cluster_name    = aws_eks_cluster.prod.name
  namespace       = "payments"
  service_account = "payments-api"
  role_arn        = aws_iam_role.payments_db_access.arn
}
```

---

### Q27. How do you troubleshoot a production network outage in AWS?

**Answer:**

**Structured troubleshooting approach — OSI model top-down:**

```
Symptom: Service unreachable from external clients

Step 1: Verify DNS (Layer 7 prerequisite)
  → nslookup api.company.com → Expected IP?
  → Route 53 health checks: is the record healthy?
  → ALB health check: are targets healthy?

Step 2: Verify Layer 4 connectivity
  → ALB access logs: are requests reaching ALB? 4xx? 5xx?
  → Target Group: are all targets healthy?
  → curl -v http://alb-dns-name → Does it respond?

Step 3: Verify security groups
  → Security group on ALB: allows 443 from 0.0.0.0/0?
  → Security group on EC2/Node: allows ALB SG as source on application port?
  → Security group on RDS/ElastiCache: allows node SG?

Step 4: Verify routing
  → Route table on public subnet: 0.0.0.0/0 → IGW?
  → Route table on private subnet: 0.0.0.0/0 → NAT Gateway?
  → NAT Gateway: has Elastic IP? Is it active?

Step 5: VPC Flow Logs (ground truth)
  → Filter: destination = ALB IP, action = REJECT
  → This will show exactly where packets are being dropped

Step 6: Reachability Analyzer (AWS tool)
  → Source: Internet (or specific IP)
  → Destination: ALB / EC2 instance
  → Shows exact hop-by-hop path and where traffic is blocked
```

**AWS Reachability Analyzer CLI:**

```bash
aws ec2 create-network-insights-path \
  --source eni-abc123 \
  --destination eni-def456 \
  --protocol tcp \
  --destination-port 443

aws ec2 start-network-insights-analysis \
  --network-insights-path-id nip-xxx
```

**Common production outage causes I've seen:**

1. NAT Gateway failure → All outbound traffic from private subnets fails
2. Security group rule accidentally removed during Terraform apply
3. Route table detached from subnet after VPC modification
4. ALB target group health check misconfigured → all targets unhealthy
5. EKS node group scaled to 0 (cost saving gone wrong)

---

## Section 5: Kubernetes Platform Engineering {#section-5}

---

### Q28. Design an enterprise-grade EKS cluster architecture from scratch

**Answer:**

**Complete EKS reference architecture:**

```
┌──────────────────────────────────────────────────────────────┐
│                    EKS Control Plane                         │
│         (AWS-managed, multi-AZ, private endpoint)            │
└──────────────────────────────────────────────────────────────┘
                            │
              ┌─────────────┼─────────────┐
              │             │             │
        AZ-1 Private  AZ-2 Private  AZ-3 Private
        Subnets       Subnets       Subnets
              │             │             │
        ┌─────▼─────┐ ┌─────▼─────┐ ┌─────▼─────┐
        │ System    │ │ System    │ │ System    │
        │ Node      │ │ Node      │ │ Node      │
        │ Group     │ │ Group     │ │ Group     │
        │(c6i.xlg)  │ │(c6i.xlg)  │ │(c6i.xlg) │
        └───────────┘ └───────────┘ └───────────┘
        ┌─────────────────────────────────────────┐
        │          Application Node Groups        │
        │  On-Demand: m6i.2xlarge (baseline)     │
        │  Spot:      m6i.2xlarge, m5.2xlarge    │
        │             (interruptible workloads)  │
        └─────────────────────────────────────────┘
```

**Terraform: Production EKS with all security controls:**

```hcl
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "company-prod"
  cluster_version = "1.31"

  # Private API server
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = false

  # Envelope encryption for Kubernetes secrets
  cluster_encryption_config = {
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }

  # Enable all control plane logging
  cluster_enabled_log_types = [
    "api", "audit", "authenticator", "controllerManager", "scheduler"
  ]

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Node groups
  eks_managed_node_groups = {
    system = {
      name           = "system"
      instance_types = ["c6i.xlarge"]
      min_size       = 3
      max_size       = 6
      desired_size   = 3
      
      # Taint system nodes to prevent workload pods landing here
      taints = [{
        key    = "CriticalAddonsOnly"
        value  = "true"
        effect = "NO_SCHEDULE"
      }]
      
      labels = { role = "system" }
    }
    
    application = {
      name           = "application"
      instance_types = ["m6i.2xlarge", "m5.2xlarge", "m5a.2xlarge"]
      capacity_type  = "SPOT"
      min_size       = 3
      max_size       = 100
      desired_size   = 10
    }
  }
}
```

**Add-ons I always install:**

| Add-on | Purpose |
|--------|---------|
| AWS Load Balancer Controller | Provision ALB/NLB from Ingress/Service objects |
| Cluster Autoscaler or Karpenter | Auto-scale nodes based on pending pods |
| ExternalDNS | Auto-create Route53 records for Services/Ingress |
| External Secrets Operator | Sync Secrets Manager / Parameter Store → K8s Secrets |
| Cert-Manager | Automate TLS certificates (Let's Encrypt / ACM) |
| Kube-proxy (managed) | Network proxy; keep updated |
| CoreDNS (managed) | Cluster DNS |
| VPC CNI (managed) | AWS native pod networking |
| Istio (service mesh) | mTLS, traffic management, observability |
| Karpenter | Modern node provisioner (replacing Cluster Autoscaler) |

---

### Q29. Compare EKS, AKS, and GKE. When would you choose each for a greenfield multi-cloud project?

**Answer:**

**Feature comparison:**

| Feature | EKS | AKS | GKE |
|---------|-----|-----|-----|
| **Control plane cost** | $0.10/hr/cluster | Free | Free (Standard); $0.10/hr (Enterprise) |
| **Managed add-ons** | Limited (EKS Add-ons) | More integrated | Most integrated (Autopilot) |
| **Autopilot/Automatic** | Fargate (limited) | No equivalent | GKE Autopilot (serverless nodes) |
| **Upgrade experience** | Manual (managed node groups can auto) | Auto-upgrade available | Best-in-class auto-upgrade |
| **Networking** | VPC CNI (complex); Cilium option | Azure CNI / kubenet | Dataplane V2 (eBPF, Cilium-based) |
| **GPU support** | ✅ Strong | ✅ Strong | ✅ TPU support unique |
| **Multi-region** | Manual federation | Manual federation | GKE Fleet (best multi-cluster) |
| **Security hardening** | Manual CIS hardening | Defender for Containers built-in | Binary Authorization, SLSA built-in |
| **IAM integration** | IRSA (complex but powerful) | Managed Identity (clean) | Workload Identity (cleanest) |

**When to choose each:**

```
EKS:  When AWS is primary cloud; deep AWS ecosystem integration required;
      using RDS, ElastiCache, S3 extensively; existing AWS expertise in team

AKS:  Azure AD + Active Directory critical; M365/Intune integration;
      Windows containers needed; Azure Data Factory / Synapse integration

GKE:  Best Kubernetes experience overall; BigQuery/Pub/Sub heavy workloads;
      ML/AI on TPUs; want lowest operational overhead (Autopilot)
      For a "best Kubernetes" greenfield choice, GKE Autopilot wins on ops burden
```

---

### Q30. How do you implement GitOps with ArgoCD on EKS at scale (100+ applications)?

**Answer:**

**GitOps at scale — App of Apps pattern:**

```
Git Repository Structure:
argocd/
├── projects/              # ArgoCD Projects (team isolation)
│   ├── payments.yaml
│   └── identity.yaml
├── applications/          # ArgoCD Application manifests
│   ├── root-app.yaml      # The "app of apps" — manages all others
│   ├── payments/
│   │   ├── payments-api.yaml
│   │   └── payments-worker.yaml
│   └── identity/
│       └── identity-service.yaml
└── applicationsets/       # Template for generating apps from directories
    └── workloads.yaml
```

**ApplicationSet for auto-generating applications:**

```yaml
# applicationsets/workloads.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: workloads
  namespace: argocd
spec:
  generators:
  - git:
      repoURL: https://github.com/company/k8s-manifests
      revision: HEAD
      directories:
      - path: workloads/*/*  # workloads/payments/prod, workloads/identity/prod
  template:
    metadata:
      name: '{{path.basenameNormalized}}'
    spec:
      project: '{{path[1]}}'  # Team name from directory
      source:
        repoURL: https://github.com/company/k8s-manifests
        targetRevision: HEAD
        path: '{{path}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{path[1]}}'  # payments, identity, etc.
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        retry:
          limit: 5
          backoff:
            duration: 5s
            maxDuration: 3m
            factor: 2
```

**Multi-cluster ArgoCD management:**

```yaml
# Register multiple clusters in ArgoCD
apiVersion: v1
kind: Secret
metadata:
  name: eks-prod-us-east
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
stringData:
  name: eks-prod-us-east
  server: https://eks-endpoint.us-east-1.amazonaws.com
  config: |
    {
      "bearerToken": "<token>",
      "tlsClientConfig": {"caData": "<ca>"}
    }
```

**Progressive delivery with Argo Rollouts:**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: payments-api
spec:
  strategy:
    canary:
      steps:
      - setWeight: 5    # 5% traffic to new version
      - pause: {duration: 5m}
      - analysis:
          templates:
          - templateName: payments-error-rate  # Check Prometheus metrics
      - setWeight: 25
      - pause: {duration: 10m}
      - setWeight: 100
      
      canaryMetadata:
        labels:
          track: canary
      stableMetadata:
        labels:
          track: stable
```

---

### Q31. How do you configure Karpenter for cost-efficient node provisioning on EKS?

**Answer:**

**Karpenter vs. Cluster Autoscaler:**

| Feature | Karpenter | Cluster Autoscaler |
|---------|-----------|-------------------|
| **Provisioning speed** | < 60 seconds | 3-5 minutes |
| **Node selection** | Picks best instance from 100s of types | Scales predefined ASGs |
| **Spot diversification** | Automatic (diversifies across types) | Manual ASG config |
| **Bin packing** | ✅ (consolidation built-in) | Limited |
| **Custom node configs** | NodeClass (fine-grained) | Launch templates only |
| **Cost optimization** | ✅ Consolidation removes underutilized nodes | ✅ But less efficient |

**Karpenter configuration:**

```yaml
# NodePool: Define what nodes Karpenter can provision
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: general
spec:
  template:
    spec:
      requirements:
      - key: karpenter.sh/capacity-type
        operator: In
        values: ["spot", "on-demand"]
      - key: node.kubernetes.io/instance-type
        operator: In
        values:
        - m6i.xlarge
        - m6i.2xlarge
        - m5.xlarge
        - m5.2xlarge
        - m5a.xlarge
        - m5a.2xlarge  # Many types = better spot availability
      - key: kubernetes.io/arch
        operator: In
        values: ["amd64"]
      nodeClassRef:
        apiVersion: karpenter.k8s.aws/v1
        kind: EC2NodeClass
        name: default
  limits:
    cpu: 1000           # Max 1000 vCPUs in this NodePool
  disruption:
    consolidationPolicy: WhenUnderutilized  # Consolidate idle nodes
    consolidateAfter: 30s
    
---
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  amiFamily: AL2023
  role: KarpenterNodeRole-company-prod
  subnetSelectorTerms:
  - tags:
      karpenter.sh/discovery: company-prod
  securityGroupSelectorTerms:
  - tags:
      karpenter.sh/discovery: company-prod
  blockDeviceMappings:
  - deviceName: /dev/xvda
    ebs:
      volumeSize: 100Gi
      volumeType: gp3
      encrypted: true
      kmsKeyID: arn:aws:kms:us-east-1:xxx:key/yyy
```

---

### Q32. How do you manage Kubernetes cluster upgrades across EKS, AKS, and GKE with zero downtime?

**Answer:**

**Cluster upgrade strategy — never in-place big-bang upgrades:**

**Blue-green cluster upgrade (preferred for major version changes):**

```
1. Provision new cluster (new-eks-v1-31) alongside old (old-eks-v1-29)
2. Deploy all workloads to new cluster (GitOps makes this easy — point ArgoCD to new cluster)
3. Migrate traffic: weighted Route53 / GSLB → 5% → 25% → 100% to new cluster
4. Monitor error rates, latency (30 min at each step)
5. Decommission old cluster
```

**In-place rolling upgrade (for minor/patch versions):**

```bash
# EKS: Update control plane first, then node groups
aws eks update-cluster-version \
  --name company-prod \
  --kubernetes-version 1.31

# Wait for control plane to complete
aws eks wait cluster-active --name company-prod

# Update managed node groups (rolling with max-unavailable=1)
aws eks update-nodegroup-version \
  --cluster-name company-prod \
  --nodegroup-name application \
  --kubernetes-version 1.31 \
  --force  # Evicts pods that don't respect PDB

# Verify add-ons are compatible with new version
aws eks describe-addon-versions --kubernetes-version 1.31
```

**Pre-upgrade checklist I follow:**

```
□ Test in non-production environment first (staging matches prod)
□ Review deprecated APIs in target K8s version (use kubent tool)
□ Update all add-ons to versions compatible with target K8s version
□ Ensure PodDisruptionBudgets are set for all critical services
□ Verify topologySpreadConstraints across AZs for critical pods
□ Freeze deployments during upgrade window
□ Run e2e smoke tests after control plane upgrade before node group upgrade
□ Have rollback plan documented (restore from snapshot for GKE)
```

**API deprecation check:**

```bash
# kubent: Kubernetes No Trouble
kubent --target-version 1.31
# Output: List of manifests using deprecated/removed APIs
# e.g., policy/v1beta1 PodSecurityPolicy removed in 1.25
```

---

### Q33. How do you implement service mesh with Istio for a production EKS cluster?

**Answer:**

**Istio deployment architecture:**

```
istio-system namespace:
  istiod (control plane — Pilot + Citadel + Galley merged)
  
Application namespace (sidecar injection enabled):
  [App Pod] + [Envoy Sidecar] ← Istio auto-injects on namespace label
```

**Installation with Helm:**

```bash
helm repo add istio https://istio-release.storage.googleapis.com/charts

# Install base CRDs
helm install istio-base istio/base -n istio-system --create-namespace

# Install istiod
helm install istiod istio/istiod -n istio-system \
  --set pilot.resources.requests.cpu=500m \
  --set pilot.resources.requests.memory=2Gi \
  --set meshConfig.enableTracing=true \
  --set meshConfig.defaultConfig.tracing.zipkin.address=jaeger-collector.observability:9411

# Enable sidecar injection for namespace
kubectl label namespace payments istio-injection=enabled
```

**mTLS enforcement:**

```yaml
# Enforce STRICT mTLS across the mesh
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system  # Applies mesh-wide
spec:
  mtls:
    mode: STRICT  # Reject any non-mTLS traffic
```

**Traffic management (canary):**

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: payments-api
spec:
  hosts:
  - payments-api
  http:
  - match:
    - headers:
        x-canary:
          exact: "true"
    route:
    - destination:
        host: payments-api
        subset: v2
  - route:
    - destination:
        host: payments-api
        subset: v1
      weight: 95
    - destination:
        host: payments-api
        subset: v2
      weight: 5
```

**Observability from Istio:**

- Metrics: Golden signals (request rate, error rate, latency) auto-exported to Prometheus
- Tracing: Distributed traces via Jaeger/Zipkin (inject headers in app)
- Access logs: Every request logged with source/destination identity, response code, latency

---

### Q34. How do you implement RBAC in Kubernetes for a multi-team environment?

**Answer:**

**RBAC design — namespace-per-team model:**

```
ClusterRole: view-only     → Bound to all-engineers SA (read all namespaces)
ClusterRole: cluster-admin → Bound to platform-team SA (break-glass only)

Namespace: payments
  Role: payments-developer → deploy, exec into pods, view logs
  Role: payments-readonly  → describe, get, list only
  RoleBinding: payments-engineers → payments-developer
  RoleBinding: auditors → payments-readonly
```

**RBAC YAML for team developer role:**

```yaml
# Role: allows CI/CD deploy operations in a namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer
  namespace: payments
rules:
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets", "statefulsets"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
- apiGroups: [""]
  resources: ["pods", "pods/log", "pods/exec", "services", "configmaps"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]  # No create/update on secrets (ESO handles it)
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: payments-developers
  namespace: payments
subjects:
- kind: Group
  name: payments-engineers  # Mapped from AWS SSO / OIDC group
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: developer
  apiGroup: rbac.authorization.k8s.io
```

**AWS EKS — mapping IAM to Kubernetes RBAC:**

```yaml
# aws-auth ConfigMap (or EKS Access Entries — new approach)
mapRoles:
- rolearn: arn:aws:iam::123456789:role/payments-cicd-role
  username: payments-cicd
  groups:
  - payments-deployers

mapUsers:
- userarn: arn:aws:iam::123456789:user/john.doe
  username: john.doe
  groups:
  - payments-engineers
```

**Newer approach — EKS Access Entries (no more aws-auth ConfigMap):**

```hcl
resource "aws_eks_access_entry" "payments_cicd" {
  cluster_name      = aws_eks_cluster.prod.name
  principal_arn     = aws_iam_role.payments_cicd.arn
  kubernetes_groups = ["payments-deployers"]
}
```

---

### Q35. How do you size and set resource requests/limits for containers? Explain the impact of getting this wrong

**Answer:**

**Resource model:**

```
Request: What the scheduler uses to place the pod on a node
Limit:   Hard maximum the container can use before being throttled/OOMKilled

CPU:
  Request: Guaranteed CPU time
  Limit:   Throttled (not killed) when exceeded; causes latency

Memory:
  Request: Memory reserved for the pod
  Limit:   OOMKilled when exceeded; process killed
```

**Impact of misconfiguration:**

| Misconfiguration | Consequence |
|-----------------|-------------|
| No requests set | Pods get scheduled randomly; noisy neighbor problem; QoS = BestEffort (evicted first) |
| Request = Limit (Guaranteed) | Good for latency-sensitive; prevents noisy neighbor |
| Requests >> actual usage | Wasted capacity; poor bin packing; cost waste |
| Limits too low | Legitimate requests cause OOMKilled; CPU throttling causes latency |
| No limits at all | One bad pod can starve an entire node |

**Sizing methodology I use:**

```bash
# Step 1: Run without limits (safe in dev/staging), collect metrics
# VPA recommendation mode
kubectl apply -f - <<EOF
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: payments-api-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: payments-api
  updatePolicy:
    updateMode: "Off"  # Recommendation only, don't auto-update
EOF

# Step 2: After 24-48 hours of real traffic
kubectl describe vpa payments-api-vpa
# Target CPU: 250m, Target Memory: 512Mi

# Step 3: Set requests at p50, limits at p99 + 20% buffer
resources:
  requests:
    cpu: "250m"
    memory: "512Mi"
  limits:
    cpu: "1000m"   # Allow burst; CPU throttling is better than OOMKill
    memory: "768Mi" # 50% buffer over p99 memory to handle GC spikes
```

**LimitRange to enforce defaults in namespaces:**

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: payments
spec:
  limits:
  - type: Container
    default:
      cpu: "500m"
      memory: "256Mi"
    defaultRequest:
      cpu: "100m"
      memory: "128Mi"
    max:
      cpu: "4"
      memory: "4Gi"
```

---

### Q36. How do you implement autoscaling at both the pod and node level?

**Answer:**

**Three layers of autoscaling:**

```
Layer 3: KEDA (event-driven scaling — queue depth, custom metrics)
Layer 2: HPA (Horizontal Pod Autoscaler — CPU/memory/custom metrics)
Layer 1: Karpenter/CA (Node autoscaling — based on pending pods)
```

**HPA with custom metrics:**

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: payments-api
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: payments-api
  minReplicas: 3
  maxReplicas: 50
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70  # Scale when avg CPU > 70%
  - type: Pods
    pods:
      metric:
        name: http_requests_per_second  # Custom Prometheus metric
      target:
        type: AverageValue
        averageValue: "1000"  # 1000 RPS per pod
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300  # Wait 5 min before scaling down
      policies:
      - type: Percent
        value: 10           # Remove max 10% pods per 60s
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0    # Scale up immediately
      policies:
      - type: Percent
        value: 100          # Double pods every 15s if needed
        periodSeconds: 15
```

**KEDA for SQS-driven scaling:**

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: payments-worker
spec:
  scaleTargetRef:
    name: payments-worker
  minReplicaCount: 1
  maxReplicaCount: 100
  triggers:
  - type: aws-sqs-queue
    authenticationRef:
      name: keda-trigger-auth-aws-credentials
    metadata:
      queueURL: https://sqs.us-east-1.amazonaws.com/123/payments-queue
      queueLength: "50"    # 1 pod per 50 messages
      awsRegion: us-east-1
```

---

### Q37. Explain how you would debug a CrashLoopBackOff pod in production

**Answer:**

**Structured debugging approach:**

```bash
# Step 1: Get basic info
kubectl get pod payments-api-7d8f9b-xxx -n payments
# Check: STATUS, RESTARTS count, AGE

# Step 2: Describe for events and exit codes
kubectl describe pod payments-api-7d8f9b-xxx -n payments
# Look for:
# - Exit code: 1 (app error), 137 (OOMKilled), 143 (SIGTERM), 255 (crash)
# - Events: OOMKilled, Liveness probe failed, Failed to pull image
# - Last State: shows previous container's exit code

# Step 3: Previous container logs (since current container is crashing)
kubectl logs payments-api-7d8f9b-xxx -n payments --previous
# This shows the log from the last crash — critical for finding root cause

# Step 4: If it's a startup issue, temporarily override entrypoint
kubectl debug payments-api-7d8f9b-xxx \
  -it --image=busybox --copy-to=debug-pod --share-processes \
  -- sh

# Step 5: Check resource limits
kubectl top pod payments-api-7d8f9b-xxx -n payments
# OOMKilled = memory limit too low or memory leak
```

**Exit code decoder:**

| Exit Code | Cause | Action |
|-----------|-------|--------|
| 1 | Application error | Check app logs |
| 137 (128+9) | OOMKilled | Increase memory limit or fix memory leak |
| 139 (128+11) | Segfault | Application bug |
| 143 (128+15) | SIGTERM not handled | Check graceful shutdown handling |
| 2 | Misuse of shell command | Check entrypoint/CMD |
| 255 | Container runtime crash | Check kubelet logs on node |

---

### Q38. How do you implement multi-cluster federation and disaster recovery for Kubernetes?

**Answer:**

**Multi-cluster DR strategy:**

**Active-Passive (simpler, lower cost):**

```
Primary: EKS us-east-1 (100% traffic)
Standby: EKS us-west-2 (warm standby — ArgoCD synced, 0 traffic)
         
Failover:
  1. Route53 health check detects primary unhealthy
  2. Weighted routing → 100% to us-west-2
  3. RTO: 5-10 minutes; RPO: depends on DB replication lag
```

**Active-Active (higher cost, better RTO):**

```
us-east-1 (50% traffic) ◄──── Route53 Latency Policy ────► us-west-2 (50% traffic)
      │                                                              │
      └──── Aurora Global Cluster ────────────────────────────────┘
            (Primary: us-east-1, Replica: us-west-2, ~100ms lag)
```

**GitOps-based multi-cluster management:**

```yaml
# ArgoCD ApplicationSet targeting multiple clusters
spec:
  generators:
  - clusters:
      selector:
        matchLabels:
          environment: production  # Targets all prod clusters
  template:
    spec:
      destination:
        server: '{{server}}'  # Each cluster's API server URL
        namespace: payments
```

**DR runbook automation:**

```python
# scripts/failover.py — triggered by PagerDuty webhook
def failover_to_secondary(region: str):
    # 1. Verify secondary cluster is healthy
    check_cluster_health(f"eks-prod-{region}")
    
    # 2. Scale up secondary (if active-passive)
    scale_node_groups(f"eks-prod-{region}", desired=20)
    
    # 3. Promote Aurora replica to primary
    promote_aurora_replica(region)
    
    # 4. Update Route53 to point to secondary ALB
    update_route53_weights(primary_weight=0, secondary_weight=100)
    
    # 5. Notify via PagerDuty + Slack
    send_notifications(f"Failover to {region} complete")
```

---

*End of Part 1 — See Part 2 for: CI/CD & DevSecOps, Observability & SRE, FinOps, Cloud Security, Migration & Modernization, Leadership & Soft Skills*

---

> **Quick Reference: Key Comparisons**

| Topic | AWS | Azure | GCP |
|-------|-----|-------|-----|
| Kubernetes | EKS | AKS | GKE (best managed) |
| Multi-account | Organizations + Control Tower | Management Groups + Blueprints | Resource Hierarchy + Folders |
| Transit networking | Transit Gateway | Virtual WAN | Shared VPC (global) |
| GitOps | ArgoCD / Flux on EKS | ArgoCD / Flux on AKS | ArgoCD / Anthos Config Mgmt |
| IaC | Terraform + CloudFormation | Terraform + Bicep | Terraform + Deployment Manager |
| Secrets | Secrets Manager + Parameter Store | Key Vault | Secret Manager |
| Service mesh | Istio / App Mesh | Istio / Open Service Mesh | Istio / Anthos Service Mesh |
| Node autoscaling | Karpenter | VMSS + Cluster Autoscaler | GKE Autopilot |
