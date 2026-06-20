# MASTER INTERVIEW PREPARATION GUIDE
## Pushparaj Naik | Lead Cloud Architect | AWS · DevOps · DevSecOps · EKS · Terraform

> **22+ Years of Experience** | AWS SAA & CCP Certified | GCP PCA Certified  
> **Phone:** +91-9972088444 | **Email:** pushparaj.naik@gmail.com | **Location:** Bangalore, India  
> **Current Role:** AWS Cloud Architect @ ITC Infotech (Feb 2025 – Present) — Advantest Cloud Migration

---

## Quick Navigation

| # | Domain | Topics |
|---|--------|--------|
| 1 | [Profile & Positioning](#1-profile--positioning) | STAR answers, strength, leadership style |
| 2 | [AWS Core Architecture](#2-aws-core-architecture) | 3-tier design, HA, Multi-AZ, Multi-Region |
| 3 | [VPC & Advanced Networking](#3-vpc--advanced-networking) | Subnets, TGW, Hub-Spoke, Direct Connect, VPN |
| 4 | [Hub-Spoke + Palo Alto NGFW](#4-hub-spoke--palo-alto-ngfw-deep-dive) | TGW routing, GWLB, GENEVE, Appliance Mode |
| 5 | [Security & Compliance](#5-security--compliance) | IAM, KMS, WAF, GuardDuty, NIST, PCI-DSS |
| 6 | [DevSecOps Pipeline Security](#6-devsecops-pipeline-security) | Gitleaks, SonarCloud, Trivy, OIDC, supply chain |
| 7 | [Infrastructure as Code — Terraform](#7-infrastructure-as-code--terraform) | State, modules, drift, workspaces, CI/CD |
| 8 | [CI/CD & GitHub Actions](#8-cicd--github-actions) | Golden pipeline, GitOps, ArgoCD, DORA |
| 9 | [Kubernetes & EKS](#9-kubernetes--eks) | Architecture, security, autoscaling, upgrades |
| 10 | [Observability & SRE](#10-observability--sre) | SLI/SLO, error budgets, CloudWatch, Datadog |
| 11 | [Cost Optimization & FinOps](#11-cost-optimization--finops) | Savings plans, rightsizing, FinOps framework |
| 12 | [Landing Zones & Multi-Account](#12-landing-zones--multi-account-governance) | Control Tower, SCPs, Organizations |
| 13 | [Disaster Recovery & Backup](#13-disaster-recovery--backup) | RTO/RPO tiers, Aurora Global DB, DR testing |
| 14 | [Migration Strategy](#14-migration-strategy) | 6R framework, MGN, DMS, wave planning |
| 15 | [Containerization & Docker](#15-containerization--docker) | Dockerfile hardening, IRSA, ECR, ECS |
| 16 | [Behavioral & Leadership](#16-behavioral--leadership-questions) | STAR method, conflict, mentorship |
| 17 | [Scenario-Based Troubleshooting](#17-scenario-based-troubleshooting) | Real incidents, RCA, resolutions |
| 18 | [Rapid-Fire Cheat Sheet](#18-rapid-fire-cheat-sheet) | Key facts to remember for every interview |

---

## 1. Profile & Positioning

### Your 90-Second Pitch (Tell Me About Yourself)

> "I'm a Lead Cloud Architect with 22+ years of experience, currently at ITC Infotech where I'm leading the AWS cloud migration for Advantest — a global semiconductor test equipment company. I design enterprise-scale AWS platforms covering network architecture, EKS-based container workloads, Terraform automation, CI/CD pipelines, and security governance aligned to frameworks like HIPAA, PCI-DSS, and GDPR.
>
> Before this, at Wipro I spent 12 years — most recently as AWS Cloud Architect on HPE's K-GPT AI document search platform, where I built a private EKS cluster behind PrivateLink with Azure DevOps CI/CD and Greengrass edge computing on Palo Alto appliances. Earlier at Wipro I also worked on Nokia NetAct's migration to AWS and Cisco DOCSIS integration automation.
>
> I hold the AWS Solutions Architect Associate, AWS Cloud Practitioner, and Google Cloud Professional Cloud Architect certifications. What drives me is solving hard infrastructure problems that make engineering teams move faster and more safely — which is exactly what attracted me to this role."

---

### Why Should We Hire You?

**Answer:** "Three things set me apart:
1. **Depth + breadth.** I have deep hands-on expertise in every layer — from VPC and TGW routing design to Terraform module authoring, EKS cluster hardening, and DevSecOps pipeline building — not just architectural theory.
2. **Proven delivery at scale.** At ITC Infotech I designed the full AWS architecture for Advantest's GLP, FNO, and AOL workloads — multi-tier VPC, ECS containerization, multi-AZ RDS MSSQL migration, Site-to-Site VPN, Route 53 Resolver, and a complete CI/CD pipeline with security gates — all while applying DORA metrics.
3. **Security-first mindset.** From IRSA and OIDC-based keyless auth to Trivy, SonarCloud, and GuardDuty integration, I treat security as a first-class engineering concern embedded in every pipeline and architecture decision."

---

### Greatest Strength (for Architects)

**Answer:** "Pattern recognition across domains. After 22 years I can look at a problem — whether it's latency between spoke VPCs, a Terraform state drift, or an OOMKill on an EKS pod — and quickly connect it to the right layer of the stack. I've seen enough failure modes to design defensively from day one, which saves significant rework. My architectural instinct is backed by operational experience, not just whiteboard diagrams."

---

### Greatest Weakness (Authentic Answer)

**Answer:** "Early in my cloud architecture career, I spent too much time perfecting designs before getting feedback. I've corrected this by adopting a 'working skeleton first' approach — I share a rough architecture diagram within the first day to get alignment, then refine. This cut my cycle time for architecture decisions significantly and the designs actually improved because feedback came earlier."

---

### Leadership Style

**Answer:** "Servant leadership with technical authority. I remove obstacles, set the architectural direction clearly, and then give my team autonomy on implementation. I hold weekly architecture office hours where any engineer can bring a design question. I enforce standards through automation — if our Terraform modules embed the security defaults, teams can't accidentally violate them. Constraints enforced by code are more effective than policies enforced by review."

---

## 2. AWS Core Architecture

### Q: Design a secure, scalable, highly available 3-tier architecture for a mission-critical application.

**Answer:**

```
Internet → Route 53 (failover routing)
              ↓
         CloudFront (CDN + WAF)
              ↓
     ┌────── ALB ──────┐
     AZ-a             AZ-b
      │                │
 ┌────────────────────────────────┐
 │     Web/App Tier (ECS/EKS)    │
 │     Private App Subnets        │
 └────────────────────────────────┘
              ↓
 ┌────────────────────────────────┐
 │     Data Tier                  │
 │  Aurora Multi-AZ (writer AZ-a) │
 │  Aurora Read Replica (AZ-b)    │
 │  ElastiCache Redis (cluster)   │
 │  Private Data Subnets (no IGW) │
 └────────────────────────────────┘
```

| Layer | Choice | Rationale |
|-------|--------|-----------|
| **DNS** | Route 53 failover | Automatic failover to DR region |
| **Edge** | CloudFront + WAF | DDoS protection, OWASP rules, TLS termination |
| **Load Balancer** | ALB (multi-AZ) | Layer 7, path-based routing, sticky sessions |
| **Compute** | ECS Fargate / EKS | No OS management, auto-scaling |
| **Database** | Aurora Multi-AZ | Sub-30s automatic failover |
| **Cache** | ElastiCache Redis | Sub-millisecond read, session management |
| **Secrets** | Secrets Manager | Rotation, audit trail via CloudTrail |
| **Encryption** | KMS CMK everywhere | AES-256 at rest; TLS 1.2+ in transit |

**Key HA Decisions:**
- Auto Scaling Group: `min=2, max=10` across 2 AZs
- Aurora: Multi-AZ + Global Database for cross-region replication
- NAT Gateway: one per AZ (not shared — AZ failure isolation)
- S3 endpoints (Gateway type, free) to avoid NAT charges for S3 traffic

---

### Q: What are Availability Zones and how do you design for HA?

**Answer:**

An AZ is a physically isolated data center (or cluster) within an AWS Region with independent power, cooling, and networking. AZs within a region are connected by low-latency (<2ms) links.

| Resource | HA Strategy | Failover Time |
|----------|------------|---------------|
| EC2 | ASG across 2+ AZs | ~2-3 minutes (new instance launch) |
| ALB | Auto multi-AZ by default | Instant |
| Aurora | Multi-AZ, automatic failover | ~30 seconds |
| ElastiCache | Multi-AZ with replica failover | ~30-60 seconds |
| NAT Gateway | One per AZ | Zonal (isolated) |
| S3 | Replicated across 3+ AZs | N/A (11 nines durability) |
| DynamoDB | 3-AZ replication built-in | N/A |

**Design rule:** Any resource with a single AZ is a single point of failure. Always deploy stateful resources (RDS, ElastiCache) across 2 AZs minimum.

---

### Q: Design a Multi-Region Active-Active architecture.

**Answer:**

| Component | Primary (us-east-1) | Secondary (us-west-2) |
|-----------|---------------------|------------------------|
| DNS | Route 53 latency-based | Route 53 latency-based |
| CDN | CloudFront (global) | — same distribution — |
| Compute | EKS cluster | EKS cluster (identical) |
| Database | Aurora Global DB (writer) | Aurora Global DB (reader, <1s lag) |
| Cache | ElastiCache Global Datastore | Replica |
| Object Storage | S3 + CRR + RTC | S3 destination |
| Secrets | Secrets Manager (replicated) | Secrets Manager (replica) |

**Critical design decisions:**
1. **Data consistency:** Active-active accepts eventual consistency for writes. Use DynamoDB Global Tables if you need multi-master writes.
2. **Failover:** Route 53 failover routing with health checks on ALB. TTL = 30 seconds for fast cutover.
3. **Cost:** Running dual-region ~2x infrastructure cost. Justify with business SLA (e.g., $50K/minute downtime cost vs. $15K/month extra infra).
4. **Testing:** AWS FIS (Fault Injection Simulator) — quarterly regional failover drills.

---

## 3. VPC & Advanced Networking

### Q: Design a production-grade VPC.

**Answer:**

```
VPC: 10.0.0.0/16 (65,536 IPs)
│
├── Public Subnets         (internet-facing)
│   ├── 10.0.0.0/24  AZ-a  → ALB, NAT GW, Bastion
│   └── 10.0.1.0/24  AZ-b  → ALB, NAT GW
│
├── Private App Subnets    (compute)
│   ├── 10.0.10.0/24 AZ-a  → EC2, ECS tasks, EKS nodes
│   └── 10.0.11.0/24 AZ-b  → EC2, ECS tasks, EKS nodes
│
├── Private Data Subnets   (databases — no outbound internet)
│   ├── 10.0.20.0/24 AZ-a  → RDS, ElastiCache, OpenSearch
│   └── 10.0.21.0/24 AZ-b  → RDS, ElastiCache, OpenSearch
│
├── Internet Gateway       (attached to VPC)
├── NAT Gateway x2         (one per AZ — HA)
│
├── Route Tables
│   ├── Public RT:  0.0.0.0/0 → IGW
│   ├── Private RT: 0.0.0.0/0 → NAT GW (same AZ)
│   └── Data RT:    No internet route — isolated
│
└── VPC Endpoints
    ├── S3         (Gateway endpoint — FREE)
    ├── DynamoDB   (Gateway endpoint — FREE)
    └── ECR, STS, Logs, SSM, KMS  (Interface endpoints)
```

**5 reserved IPs per subnet:** AWS reserves the first 4 (.0=network, .1=VPC router, .2=DNS, .3=future) and last (.255=broadcast). A /24 = 256 - 5 = **251 usable IPs**.

---

### Q: Security Groups vs NACLs — explain the difference and when to use each.

**Answer:**

| Feature | Security Group | NACL |
|---------|---------------|------|
| **Level** | Instance / ENI level | Subnet level |
| **Stateful?** | **Stateful** — return traffic auto-allowed | **Stateless** — must define inbound AND outbound |
| **Rules** | Allow only (implicit deny all inbound) | Allow AND Deny |
| **Evaluation** | All rules evaluated, most permissive wins | Rules evaluated in order (lowest number first) |
| **Default** | Deny all inbound, allow all outbound | Allow all inbound and outbound |
| **Use case** | Primary firewall for instances | Subnet-level defense in depth, explicit IP blocking |

**Best practice for EC2 → RDS:**
```
EC2 Security Group (sg-app):
  Inbound: none (no direct internet)
  Outbound: port 5432 to sg-rds

RDS Security Group (sg-rds):
  Inbound: port 5432 FROM sg-app (source = SG, not CIDR)
  Outbound: none needed (stateful — return traffic auto-allowed)
```

Using SG IDs as sources (not CIDRs) means the rule auto-updates when instances are added/removed from the source SG.

---

### Q: Explain Transit Gateway vs VPC Peering. When do you use each?

**Answer:**

**VPC Peering:**
- Direct 1:1 connection between 2 VPCs
- Non-transitive (A↔B and B↔C does NOT enable A↔C)
- No bandwidth limits (no TGW overhead)
- Problem: N VPCs = N*(N-1)/2 connections. 10 VPCs = 45 peering connections!

**Transit Gateway:**
- Hub-and-spoke: all VPCs attach to one central TGW
- Transitive routing: A → TGW → B → TGW → C all reachable
- Supports VPCs, VPNs, Direct Connect in one hub
- TGW Route Tables control inter-spoke isolation

```
WITHOUT TGW (mesh — 6 VPCs = 15 connections):
  VPC-A ── VPC-B ── VPC-C
    ╲   ╲  ╱  ╲  ╱
     VPC-D ── VPC-E ── VPC-F

WITH TGW (hub-spoke — 6 VPCs = 6 attachments):
  VPC-A ─┐
  VPC-B ─┤
  VPC-C ─┼── Transit Gateway ── VPN ── On-Premises
  VPC-D ─┤
  VPN   ─┘
```

| Scenario | Choice | Reason |
|----------|--------|--------|
| 2-3 VPCs, simple | VPC Peering | Simpler, cheaper, no TGW overhead |
| 5+ VPCs, multi-account | TGW | Centralized management, scalable |
| Hybrid (VPN + multiple VPCs) | TGW | Single hub for all connectivity |
| Traffic inspection between VPCs | TGW | Route through firewall appliance (Inspection VPC) |
| Cross-region large throughput | VPC Peering | No bandwidth limit vs TGW 50 Gbps/AZ |

---

### Q: When does Direct Connect beat Site-to-Site VPN?

**Answer:**

| Feature | Direct Connect | Site-to-Site VPN |
|---------|---------------|-------------------|
| **Connection** | Dedicated fiber (private) | Over public internet (encrypted) |
| **Bandwidth** | 1, 10, 100 Gbps | Up to 1.25 Gbps per tunnel |
| **Latency** | Consistent, low | Variable (internet-dependent) |
| **Encryption** | NOT encrypted by default | IPSec encrypted by default |
| **Setup time** | Weeks to months | Minutes (virtual) |
| **Cost** | Port fee + lower data transfer $/GB | Hourly VPN charges |
| **Resilience** | Need 2 connections for HA | 2 tunnels per connection (built-in) |

**DX Encryption options:**
1. **MACsec (IEEE 802.1AE):** Layer 2 AES-256 encryption at line rate. Requires dedicated DX and MACsec-capable router. Preferred for BFSI.
2. **IPSec VPN over DX:** Run IPSec tunnel over the DX Private VIF. Adds encryption overhead but works on hosted DX connections.

**Best practice for enterprise:**
```
Primary:   Direct Connect (10G) with MACsec + BGP routing
Secondary: S2S VPN over internet (IPSec IKEv2) as automatic failover
Both terminate on TGW — BGP preference steers traffic to DX
```

**Use DX when:** large data transfers (DB replication, backups), consistent low-latency, compliance requires traffic off public internet.

---

### Q: Explain Route 53 routing policies.

**Answer:**

| Policy | How It Works | Use Case |
|--------|-------------|----------|
| **Simple** | Returns single record | Single resource |
| **Weighted** | Distributes traffic by % (e.g., 90/10) | Canary deployments, A/B testing |
| **Latency-based** | Routes to lowest-latency region | Multi-region apps |
| **Failover** | Primary/secondary with health checks | Active-passive DR |
| **Geolocation** | Based on user's country/continent | GDPR (EU users → EU servers) |
| **Geoproximity** | Nearest resource with bias | Traffic shifting between regions |
| **Multi-value** | Up to 8 healthy IPs | Simple load balancing + health checks |

**Health checks:** Route 53 can monitor HTTP/HTTPS/TCP endpoints, CloudWatch alarms, or calculated (combination) health checks. Check interval: 10 or 30 seconds.

---

## 4. Hub-Spoke + Palo Alto NGFW Deep Dive

### Q: Explain the Hub-Spoke architecture with centralized traffic inspection on AWS.

**Answer:**

```
OnPrem (IPSec/IKEv2 or DX+MACsec)
           │
           ▼
   ┌──── Transit Gateway (TGW) ────┐
   │  Pre-Inspection RT            │
   │  0.0.0.0/0 → Inspection VPC  │
   └───────────────────────────────┘
           │
           ▼
   ┌──── Inspection VPC ───────────┐
   │  TGW ENI → GWLB Endpoint     │
   │      ↓ (GENEVE/UDP 6081)     │
   │  Gateway Load Balancer (GWLB) │
   │      ↓                        │
   │  Palo Alto VM-Series (ASG)   │
   │  (App-ID, IPS, URL Filter,   │
   │   SSL Decrypt, Wildfire)     │
   │      ↓                        │
   │  Return subnet → TGW          │
   └───────────────────────────────┘
           │
           ▼ (Post-Inspection RT)
   ┌───────────────────────────────┐
   │  Spoke VPC A  │  Spoke VPC B │
   │  (Dev)        │  (Prod)      │
   │  No IGW/NAT   │  No IGW/NAT  │
   └───────────────────────────────┘
```

**Traffic Steering via TGW Route Tables:**

**Pre-Inspection RT** (associated to spoke VPCs + OnPrem VPN/DX):
```
0.0.0.0/0    → Inspection VPC TGW attachment
10.0.0.0/8   → Inspection VPC TGW attachment
```
Every packet from any spoke or OnPrem hits the Inspection VPC FIRST.

**Post-Inspection RT** (associated to Inspection VPC attachment):
```
10.1.0.0/16  → Spoke VPC A attachment
10.2.0.0/16  → Spoke VPC B attachment
0.0.0.0/0    → Egress VPC attachment (internet-bound)
172.16.0.0/12→ VPN/DX attachment (back to OnPrem)
```

---

### Q: What is TGW Appliance Mode and why is it critical for stateful firewalls?

**Answer:**

Without Appliance Mode, TGW load-balances attachments across AZs. For a stateful firewall (Palo Alto), the forward packet might go to Palo Alto instance in AZ-a, but the return packet might go to a Palo Alto instance in AZ-b — breaking stateful inspection because that firewall has no session table entry for the flow.

**Appliance Mode** pins both the forward and return path of the same TCP flow to the **same AZ's attachment**, ensuring the same Palo Alto instance sees both directions.

**Enabling in Terraform:**
```hcl
resource "aws_ec2_transit_gateway_vpc_attachment" "inspection" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = aws_vpc.inspection.id
  subnet_ids         = aws_subnet.inspection_tgw[*].id
  appliance_mode_support = "enable"   # ← CRITICAL for stateful inspection
}
```

---

### Q: What is GWLB and why does it use GENEVE protocol?

**Answer:**

**Gateway Load Balancer (GWLB)** makes transparent firewall insertion possible. It operates at Layer 3 and distributes traffic across a fleet of virtual appliances (Palo Alto instances) while preserving original source/destination IPs.

**Why GENEVE (not VXLAN):** GENEVE wraps the original L3 packet with metadata in a UDP envelope on port 6081. The firewall receives:
- The **original packet** with real client/server IPs unchanged (no SNAT needed)
- GWLB metadata in the GENEVE header for session tracking

After inspection, the firewall returns the packet to GWLB which strips the GENEVE wrapper and forwards the original packet.

**GWLB properties:**
- Session affinity: 5-tuple hash ensures same flow → same firewall instance
- Health checks: unhealthy firewalls auto-removed from rotation
- Scales automatically as you add Palo Alto instances to the ASG

---

### Q: Palo Alto VM-Series vs AWS Network Firewall — when to choose each?

**Answer:**

| Feature | Palo Alto VM-Series | AWS Network Firewall |
|---------|--------------------|-----------------------|
| L7 App-ID | Yes (3000+ app signatures) | No (port-based only) |
| TLS Inspection | Yes | Yes |
| IPS Engine | Palo Alto Threat Prevention | Suricata-compatible rules |
| URL Filtering | PAN-DB (cloud database) | Domain/URL lists |
| User-ID (AD) | Yes | No |
| Wildfire Sandbox | Yes (zero-day) | No |
| DLP | Yes | No |
| Management | Panorama (centralized) | AWS Firewall Manager |
| Cost | Higher (EC2 + licensing) | Lower (per-GB + endpoint) |
| Scaling | GWLB + ASG (self-managed) | AWS auto-managed |

**Choose Palo Alto when:** BFSI, regulated industries, existing Palo Alto on-prem (unified policy via Panorama), advanced L7 needs, User-ID, Wildfire zero-day protection.

**Choose AWS Network Firewall when:** Cost-sensitive, AWS-native preference, basic IPS/domain filtering needed, simpler compliance requirements.

---

### Q: Walk through encryption at every hop in the Hub-Spoke architecture.

**Answer:**

| Hop | Encryption Mechanism |
|-----|----------------------|
| OnPrem → TGW (VPN) | IPSec IKEv2 — AES-256-GCM, SHA-256, DH Group 20 |
| OnPrem → DX Location | MACsec (IEEE 802.1AE) — AES-256 at Layer 2 |
| DX Location → TGW | AWS backbone (private, not public internet) |
| TGW → Inspection VPC | AWS backbone (in-transit encryption) |
| Palo Alto TLS Decrypt | Terminates TLS, inspects plaintext, re-encrypts with internal CA |
| Spoke VPC ↔ Spoke VPC | Application-level TLS 1.2/1.3 (end-to-end) |
| Data at Rest (EBS/S3) | AES-256 via KMS CMK — mandatory |
| Secrets | AWS Secrets Manager + KMS — no plaintext credentials |

> **Key BFSI point:** Even though DX is private (no internet traversal), regulators (RBI, SEBI, PCI-DSS) often require encryption in transit. MACsec satisfies this at Layer 2 without IPSec overhead.

---

## 5. Security & Compliance

### Q: Explain IAM best practices for production.

**Answer:**

**Core principles:**
1. **No root account usage** — MFA on root, use only for account-level operations
2. **No long-lived access keys** — use IAM roles (instance profiles, IRSA, OIDC)
3. **Least privilege** — start with zero permissions, add as needed
4. **MFA everywhere** — console access and sensitive API calls

**IAM Identity Center (SSO) architecture:**
```
Identity Provider (Okta/Azure AD)
     │ (SAML/OIDC Federation)
     ▼
AWS IAM Identity Center
     ├── Permission Set: AdministratorAccess → Management Account (break-glass only)
     ├── Permission Set: PowerUserAccess     → Dev Account
     ├── Permission Set: ReadOnlyAccess      → Production Account
     └── Permission Set: SecurityAudit       → All Accounts
```

**Service-level IAM:**
| Service | IAM Mechanism | Why |
|---------|--------------|-----|
| EC2 | Instance Profile (IAM Role) | No access keys on instance |
| ECS | Task Role | Per-container permissions |
| EKS | IRSA (IAM Roles for Service Accounts) | Per-pod permissions |
| Lambda | Execution Role | Function-level permissions |
| GitHub Actions | OIDC Federation | No stored credentials |

**Permission Boundary pattern (prevent privilege escalation):**
```json
{
  "Effect": "Deny",
  "Action": "iam:CreateRole",
  "Resource": "*",
  "Condition": {
    "StringNotEquals": {
      "iam:PermissionsBoundary": "arn:aws:iam::123456789012:policy/DeveloperBoundary"
    }
  }
}
```

---

### Q: Explain KMS and encryption strategy across AWS services.

**Answer:**

| KMS Key Type | Management | Cost | Use Case |
|-------------|-----------|------|----------|
| AWS Managed Key | AWS manages rotation | Free | S3 default encryption |
| Customer Managed Key (CMK) | You control policy + rotation | $1/month + API calls | Prod databases, sensitive data |
| Imported Key Material | You provide key bits | $1/month | Regulatory key control |

**Encryption coverage:**
| Resource | Encryption | Key |
|----------|-----------|-----|
| S3 | SSE-KMS (bucket default encryption) | CMK per project |
| RDS/Aurora | At-rest encryption (at creation) | CMK |
| EBS | Account-level default encryption | CMK |
| DynamoDB | At-rest (AWS managed or CMK) | CMK for production |
| ElastiCache | At-rest + in-transit | CMK |
| Secrets Manager | Automatic encryption | CMK |
| CloudTrail logs | S3 + KMS encryption | Dedicated CMK |
| EKS etcd (secrets) | KMS envelope encryption | CMK |

**Architecture rule:** One KMS CMK per service per account. Never share CMKs across trust boundaries. Annual automatic key rotation enabled.

---

### Q: How do you implement defense-in-depth from internet to pod?

**Answer:** 12 security layers for a production EKS workload:

| Layer | Component | Protection |
|-------|-----------|-----------|
| 1 | Route 53 + ACM | TLS 1.3, certificate validation |
| 2 | CloudFront + WAF | OWASP Top 10, SQLi, rate limiting (2000 req/5min), geo-blocking |
| 3 | API Gateway | JWT authorization, request throttling |
| 4 | Cognito | User pools, MFA, token revocation |
| 5 | ALB + VPC Link | Private connectivity, health checks |
| 6 | Private subnets | No public IPs on EKS nodes |
| 7 | Private EKS API | `kubectl` only from within VPC |
| 8 | IMDSv2 | Blocks SSRF-based credential theft |
| 9 | KMS | Kubernetes secrets encrypted at rest in etcd |
| 10 | IRSA | Fine-grained IAM per service account |
| 11 | GitHub OIDC | Keyless CI/CD authentication |
| 12 | SonarCloud + Trivy | SAST, SCA, container image scanning |

**Swiss cheese model:** Each layer is independent. Compromising WAF doesn't bypass Cognito. Compromising a pod doesn't give AWS IAM access (IRSA). Holes in individual layers don't align.

---

### Q: How do you map NIST CSF to AWS controls?

**Answer:**

**IDENTIFY:**
- AWS Config: resource inventory across all accounts (org-wide delegated admin)
- Systems Manager Inventory: software on EC2 instances
- Tag Policy via Organizations: mandatory tagging enforcement
- Security Hub: NIST SP 800-53 compliance standard (built-in)

**PROTECT:**
- IAM: least privilege, permission boundaries, no long-lived keys
- SCPs: deny non-approved regions, deny disabling CloudTrail, deny unencrypted S3
- KMS CMK: encryption at rest everywhere, annual rotation
- VPC: private subnets, SGs (deny-by-default), NACLs
- WAF: OWASP Top 10 managed rule groups on CloudFront + ALB
- ACM: TLS everywhere

**DETECT:**
- GuardDuty: ML-based threat detection (org-wide via delegated admin)
- Security Hub: aggregated findings + compliance score
- Macie: PII discovery in S3
- CloudTrail: all API calls, all regions, encrypted, immutable
- VPC Flow Logs → S3 → Athena (network forensics)
- Config Rules: continuous compliance evaluation

**RESPOND:**
- EventBridge + Lambda: automated response (isolate EC2 on GuardDuty finding)
- SSM Automation: runbooks for common incident types
- SNS → PagerDuty/Slack: alert routing

**RECOVER:**
- AWS Backup with cross-account/cross-region copies + Vault Lock (WORM)
- Aurora Global Database failover (<1 min RTO)
- Tested DR runbooks via SSM Automation

---

### Q: How do you enforce encryption standards org-wide using SCPs?

**Answer:**

**Preventive SCP (deny unencrypted S3 puts):**
```json
{
  "Effect": "Deny",
  "Action": ["s3:PutObject"],
  "Resource": "*",
  "Condition": {
    "StringNotEquals": {
      "s3:x-amz-server-side-encryption": ["aws:kms", "AES256"]
    }
  }
}
```

**Additional SCPs:**
- Deny `ec2:CreateVolume` without `Encrypted=true`
- Deny `rds:CreateDBInstance` without `StorageEncrypted=true`
- Deny `kms:CreateKey` without `EnableKeyRotation=true`
- Deny disabling CloudTrail, GuardDuty, Security Hub

**Detective (Config Rules):**
- `s3-bucket-server-side-encryption-enabled`
- `rds-storage-encrypted`
- `ebs-encrypted-volumes`
- `cmk-backing-key-rotation-enabled`
- `rds-instance-public-access-check`

---

### Q: How do you comply with GDPR, PCI-DSS, and HIPAA on AWS?

**Answer:**

| Requirement | AWS Implementation |
|-------------|-------------------|
| **GDPR — Data residency** | Restrict regions via SCP; deploy only to eu-west-1, eu-central-1 |
| **GDPR — Right to erasure** | DynamoDB TTL, S3 lifecycle policies, Lambda-triggered deletion APIs |
| **GDPR — Breach notification (72hr)** | GuardDuty + EventBridge + SNS → automated incident ticket |
| **PCI-DSS — No public database access** | RDS `publicly_accessible = false` enforced in Terraform module + SCP |
| **PCI-DSS — Encryption in transit** | TLS 1.2+ enforced via ACM + ALB policy; DX with MACsec |
| **PCI-DSS — Audit logging** | CloudTrail + VPC Flow Logs (immutable S3, Object Lock) |
| **HIPAA — Access control** | IAM least privilege + IRSA + SSO; no shared accounts |
| **HIPAA — Audit controls** | CloudTrail + CloudWatch + Config Rules |
| **SOC 2 — Change management** | All infra changes via Terraform PR; enforced via branch protection |

**AWS Compliance tools:** AWS Artifact (compliance reports), Audit Manager (automated evidence collection), Security Hub (compliance scores per standard).

---

## 6. DevSecOps Pipeline Security

### Q: Walk through your CI pipeline security stages and explain the order.

**Answer:** Six deliberate stages — ordered by speed and cost:

```
Stage 1: Gitleaks (secrets scan)        ← seconds, runs FIRST
  └── Scans entire git history. Hard-fail on ANY leaked key/token.
      Reason: No point building compromised code.

Stage 2: Compile + Unit Tests + JaCoCo  ← establishes code correctness
  └── Fail if coverage < 80%.

Stage 3: SonarCloud (SAST)              ← minutes
  └── Static Analysis: injection flaws, XSS, null pointers.
      Uses JaCoCo data. sonar.qualitygate.wait=true → blocks pipeline.

Stage 4: OWASP Dependency-Check (SCA)  ← minutes
  └── Scans all Maven/npm dependencies (incl. transitive) against NVD.
      Soft-fail currently (false positives). Prod: fail on CRITICAL CVSS ≥ 9.

Stage 5: Docker Build                   ← only after code passes SAST/SCA
  └── Multi-stage build, non-root user, minimal JRE base image.

Stage 6: Trivy (container image scan)   ← scans built image
  └── OS package + app CVEs. SARIF uploaded to GitHub Security tab.
      Prod: exit-code=1 on CRITICAL/HIGH.
```

**Philosophy:** Hard-fail on things that are always wrong (leaked secrets). Soft-fail on things requiring human judgment (CVE triage). Always capture results as artifacts.

---

### Q: How does GitHub OIDC work for keyless AWS authentication?

**Answer:**

```
GitHub Actions Runner
     │
     │ (1) Requests OIDC JWT from GitHub
     ▼
GitHub OIDC Provider (token.actions.githubusercontent.com)
     │
     │ (2) Issues short-lived JWT (contains repo, branch, workflow claims)
     ▼
AWS STS AssumeRoleWithWebIdentity
     │
     │ (3) Validates JWT against GitHub's OIDC provider
     │     Checks trust policy conditions
     │ (4) Returns temporary credentials (15-60 min)
     ▼
GitHub Actions uses temporary credentials
```

**AWS IAM trust policy (Terraform):**
```hcl
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

resource "aws_iam_role" "github_actions" {
  name = "github-actions-terraform"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          # Only main branch of specific repo can assume this role
          "token.actions.githubusercontent.com:sub" = "repo:myorg/myrepo:ref:refs/heads/main"
        }
      }
    }]
  })
}
```

**Why OIDC over access keys:**
| Feature | Access Keys | OIDC |
|---------|------------|------|
| Credential lifetime | Permanent until rotated | 15-60 min (auto-expires) |
| Storage | GitHub Secrets (exposure risk) | No secrets stored |
| Rotation | Manual | No rotation needed |
| Scope | Any user with key | Only specific repo + branch |

---

### Q: How does ArgoCD GitOps deployment work?

**Answer:**

```
Developer pushes to main
       │
       ▼
CI Pipeline triggers:
  ├── Build + Test + SAST + SCA + Image Scan
  ├── Build Docker image
  ├── Tag with commit SHA (immutable, traceable)
  ├── Push to ECR
  └── Trigger CD workflow (repository_dispatch)

CD Pipeline:
  └── Updates deployment.yaml image tag in manifest repo (via sed)
       │
       ▼
ArgoCD (running inside cluster) detects Git change
  ├── selfHeal: true   → Reverts any manual kubectl changes (drift)
  ├── prune: true      → Deletes orphaned resources removed from Git
  ├── ApplyOutOfSyncOnly: true  → Only touches changed resources
  └── Retry with exponential backoff (5 attempts, 5s → 3min)
```

**Key principle:** CD pipeline NEVER runs `kubectl`. It only modifies Git state. ArgoCD is the single actor touching the cluster — full audit trail, single source of truth.

**Why commit SHA tags (not `latest`):**
- **Immutability:** SHA identifies exact code; can never be overwritten
- **Traceability:** From running pod → exact commit → PR → CI run
- **ArgoCD compatibility:** Tag change detected; `latest` doesn't change even if image content does

---

### Q: What are DORA metrics and how do you measure them?

**Answer:**

| Metric | Elite Target | How We Measure |
|--------|-------------|----------------|
| **Deployment Frequency** | ≥ 1/day | Count GitHub Deployments API entries per week |
| **Lead Time for Changes** | < 1 hour | Commit timestamp → deployment timestamp (recorded in CI) |
| **Change Failure Rate** | < 15% | Failed deployment statuses / total deployments |
| **Mean Time to Recovery** | < 1 hour | Time to close issues labeled `incident` |

**Implementation:** The `dora-report.yml` workflow runs weekly, queries GitHub API, calculates all 4 metrics, and creates a GitHub Issue with the report. Zero extra infrastructure — pure GitHub API.

---

### Q: Explain supply chain security — how do you prevent a SolarWinds-style attack?

**Answer:**

```
CODE  → BUILD  → DEPLOY → RUN
  │        │         │       │
 Sign     Verify    Admit   Monitor
```

1. **CODE:** Signed commits (GPG). Branch protection (no direct pushes). Gitleaks for secrets.

2. **BUILD:**
   - Pin all dependency versions (no `latest`, no `^` ranges in package.json)
   - Generate SBOM (Software Bill of Materials) with Syft at build time
   - OWASP Dependency-Check for CVE scanning
   - Hermetic builds (reproducible; no external network calls during build)

3. **DEPLOY:**
   - Sign container images with Cosign / AWS Signer after Trivy scan passes
   - Kyverno `ClusterPolicy` — reject pods using unsigned images
   - Allow-list: only images from our private ECR allowed
   - SLSA Level 3 provenance attestation

4. **RUN:**
   - Falco: runtime syscall monitoring (shell spawned in container = alert)
   - GuardDuty for EKS: K8s API anomalies, crypto-mining, DNS exfiltration
   - Automated base image patching via Dependabot/Renovate

---

## 7. Infrastructure as Code — Terraform

### Q: Explain Terraform architecture and state management.

**Answer:**

```
terraform init   → Download providers, initialize backend
      │
terraform plan   → Compare desired state (code) vs current state (state file)
      │            → Show what will be created/changed/destroyed
      │
terraform apply  → Execute the plan, modify real infrastructure
      │            → Update state file in S3
      │
terraform destroy → Remove all managed resources
```

**State file (`terraform.tfstate`):** A JSON file mapping Terraform resource names (`aws_vpc.main`) to real-world IDs (`vpc-0abc123`). Contains sensitive data — treat like a secret.

**Remote state best practice:**
```hcl
terraform {
  backend "s3" {
    bucket         = "company-terraform-state"
    key            = "production/networking/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    kms_key_id     = "alias/terraform-state"
    dynamodb_table = "terraform-lock"     # prevents concurrent modifications
  }
}
```

| Best Practice | Why |
|--------------|-----|
| S3 backend (not local) | Team collaboration, 11-nine durability |
| DynamoDB locking | Prevents two simultaneous `terraform apply` corrupting state |
| KMS encryption on S3 | State file contains passwords, private keys |
| S3 versioning | Roll back to previous state if corrupted |
| Separate state per environment | Blast radius isolation |

---

### Q: How do you structure Terraform for a large organization?

**Answer:**

```
terraform/
├── modules/                    # Reusable, versioned modules
│   ├── networking/
│   │   ├── main.tf             # VPC, subnets, route tables, NAT, endpoints
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── versions.tf
│   ├── eks-cluster/
│   ├── rds-aurora/
│   └── security-baseline/
│
├── environments/
│   ├── dev/
│   │   ├── main.tf             # module calls
│   │   ├── terraform.tfvars   # dev-specific values (t3.small, single-AZ)
│   │   ├── backend.tf          # S3 key: "dev/terraform.tfstate"
│   │   └── providers.tf
│   ├── staging/
│   │   └── terraform.tfvars   # staging values (t3.medium, multi-AZ)
│   └── production/
│       └── terraform.tfvars   # prod values (c6i.xlarge, multi-AZ, RI)
│
└── bootstrap/                  # One-time: create S3 + DynamoDB for state
```

**Key principles:**
1. **DRY:** Modules define resources once; environments pass different variables
2. **Separate state per environment** — dev change can't corrupt prod state
3. **Module versioning:** Pin to specific Git tags (`ref = "v2.1.0"`)
4. **Variable validation:**
```hcl
variable "environment" {
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}
```

---

### Q: `count` vs `for_each` — when do you use each?

**Answer:**

| Feature | `count` | `for_each` |
|---------|---------|------------|
| Input | Integer | Map or set of strings |
| Reference | `resource.name[0]` | `resource.name["key"]` |
| Reorder safe? | **NO** — removing element shifts all indices | **YES** — removing a key only affects that resource |

**Problem with `count`:**
```hcl
# If "us-east-1a" is removed from the list, Terraform DESTROYS
# and RECREATES subnet[1] because indices shift!
variable "azs" { default = ["us-east-1a", "us-east-1b"] }
resource "aws_subnet" "private" {
  count             = length(var.azs)
  availability_zone = var.azs[count.index]   # fragile index-based
}
```

**Solution with `for_each`:**
```hcl
variable "subnets" {
  default = {
    "us-east-1a" = "10.0.10.0/24"
    "us-east-1b" = "10.0.11.0/24"
  }
}
resource "aws_subnet" "private" {
  for_each          = var.subnets
  cidr_block        = each.value
  availability_zone = each.key
}
# Reference: aws_subnet.private["us-east-1a"].id
```

**Rule:** Use `for_each` for everything. Only use `count` for simple on/off toggles (`count = var.enable_nat ? 1 : 0`).

---

### Q: How do you detect and handle Terraform state drift?

**Answer:**

**Drift** = actual infrastructure differs from state file. Causes:
1. Manual changes in AWS console
2. Another tool (CloudFormation, CLI) modified the resource
3. AWS auto-remediation (Security Hub auto-fixing)

**Detecting drift:**
```bash
# Nightly scheduled CI/CD job
terraform plan -detailed-exitcode
# Exit code 0: No changes (no drift)
# Exit code 1: Error
# Exit code 2: Changes detected = DRIFT! → alert + create Jira ticket
```

**Handling drift:**
```bash
# Option 1: Accept the manual change (update state to match reality)
terraform apply -refresh-only

# Option 2: Overwrite manual change (enforce IaC as source of truth)
terraform apply   # reverts manual change back to code-defined state

# Option 3: Import manually created resource into state
terraform import aws_security_group.manual sg-0abc123
```

**Prevention:**
- SCPs restrict console access to read-only in production
- All changes via Terraform PR only (enforced via branch protection)
- Nightly drift detection alerts to Slack + creates Jira ticket

---

### Q: You run `terraform apply` and it plans to destroy a production database. What do you do?

**Answer:**

**Step 1: Cancel immediately!** Press Ctrl+C before the destroy executes.

**Step 2: Diagnose the root cause:**
```bash
terraform plan  # Read carefully — it will show WHY

# Common causes:
# a) Resource renamed in code
#    aws_rds_cluster.aurora → aws_rds_cluster.main
#    Fix: terraform state mv aws_rds_cluster.aurora aws_rds_cluster.main

# b) Forced-replacement attribute changed
#    e.g., db_name changed (requires new DB)
#    Fix: revert the attribute change, use lifecycle ignore_changes

# c) State corruption
#    Fix: restore previous state version from S3 versioning
```

**Step 3: Prevention (lifecycle protection):**
```hcl
resource "aws_rds_cluster" "aurora" {
  # ...config...
  lifecycle {
    prevent_destroy       = true   # Error instead of destroying
    ignore_changes        = [master_password]  # Don't track rotation
    create_before_destroy = true   # Zero-downtime for changes that require replacement
  }
}
```

---

## 8. CI/CD & GitHub Actions

### Q: Design a production Terraform CI/CD pipeline.

**Answer:**

```yaml
# .github/workflows/terraform.yml
on:
  pull_request:                   # Plan on every PR
    paths: ['terraform/**']
  push:
    branches: [main]              # Apply only on merge to main
    paths: ['terraform/**']

permissions:
  id-token: write                 # OIDC — no stored secrets
  contents: read
  pull-requests: write            # Comment plan output on PR

jobs:
  security:                       # Job 1: Security scan (runs first)
    steps:
      - uses: bridgecrewio/checkov-action@v12   # Catch misconfigs before plan
      - uses: aquasecurity/tfsec-action@v1.0.3

  plan:                           # Job 2: Plan (on PR only)
    needs: security
    if: github.event_name == 'pull_request'
    steps:
      - name: Configure AWS (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
      - run: terraform init && terraform plan -out=tfplan
      - name: Comment plan on PR    # Reviewers see exact changes
        uses: actions/github-script@v7

  apply:                          # Job 3: Apply (on merge to main)
    needs: security
    if: github.ref == 'refs/heads/main'
    environment: production        # Manual approval gate
    steps:
      - run: terraform apply -auto-approve
```

**Key design decisions:**
| Decision | Why |
|----------|-----|
| OIDC auth (not access keys) | No long-lived secrets; token valid 1 hour |
| Checkov/tfsec before plan | Catch security issues before infra changes |
| Plan on PR, Apply on merge | Review before apply; no direct applies |
| Plan output as PR comment | Reviewers see exactly what will change |
| `environment: production` | Requires manual approval before apply |
| `-out=tfplan` | Ensures exact reviewed plan is what gets applied |

---

### Q: What is GitOps and why is Git the single source of truth?

**Answer:**

**GitOps = all infrastructure and application state is defined in Git. All changes go through pull requests. Automated systems (ArgoCD, Terraform CD) reconcile actual state to match Git state.**

```
Developer makes change
     │
     ▼
Feature branch → Terraform code change
     │
     ▼
Open Pull Request
     ├── Automated: terraform fmt check
     ├── Automated: terraform validate
     ├── Automated: Checkov + tfsec security scan
     ├── Automated: terraform plan (output posted to PR)
     └── Manual: Peer review (1+ approvals)
     │
     ▼
Merge to main
     │
     ▼
Automated: terraform apply (with environment approval gate)
     │
     ▼
State file updated in S3 — Git is source of truth
```

**Benefits:**
1. **Auditability:** Every change has PR, reviewer, timestamp, plan output
2. **Rollback:** `git revert` the commit → pipeline reverts infrastructure
3. **Consistency:** Infrastructure matches what's in Git (no snowflake servers)
4. **Collaboration:** All changes visible, commentable, reviewable

---

### Q: Design a golden CI/CD pipeline for Java microservices.

**Answer:**

```yaml
# Developer's pipeline file — just 5 lines
name: CI/CD
uses: .github/workflows/golden-pipeline-java.yml
with:
  java-version: 17
  deploy-to: production
```

**Golden pipeline internals:**
```
PR Stage (on every PR):
  ├── Gitleaks (secrets scan — hard fail)
  ├── Lint (Checkstyle)
  ├── Unit Tests + JaCoCo (fail if < 80% coverage)
  ├── SonarCloud SAST (quality gate must pass)
  ├── OWASP Dependency-Check SCA (fail on CRITICAL CVEs)
  └── Terraform Plan (if IaC changes exist)

Merge to Main:
  ├── Build JAR
  ├── Build Docker Image (multi-stage, non-root user)
  ├── Trivy Image Scan (fail on CRITICAL)
  ├── Sign Image (Cosign / AWS Signer)
  ├── Push to ECR (tagged with commit SHA)
  ├── Update Helm values / deployment.yaml (image tag)
  └── ArgoCD auto-syncs to dev cluster

Promotion:
  dev → staging (automated integration tests)
  staging → prod (manual approval + canary rollout)
```

---

## 9. Kubernetes & EKS

### Q: Explain Kubernetes architecture. What happens when you `kubectl apply`?

**Answer:**

**Control Plane:**
- **API Server:** Frontend for all K8s operations. All `kubectl` commands hit here. Authenticates via kubeconfig.
- **etcd:** Distributed key-value store for all cluster state (desired + actual).
- **Scheduler:** Assigns unscheduled pods to nodes based on resources, affinity, taints.
- **Controller Manager:** Runs reconciliation loops (Deployment controller, ReplicaSet controller, Node controller).

**Worker Nodes:**
- **kubelet:** Agent on each node. Watches API Server for pod assignments, manages container lifecycle.
- **kube-proxy:** Implements Service abstraction via iptables/IPVS rules.
- **containerd:** Container runtime (CRI) — actually runs containers.

**`kubectl apply -f deployment.yaml` flow:**
1. kubectl sends YAML to API Server (authenticated via kubeconfig)
2. API Server validates + stores desired state in **etcd**
3. Deployment Controller detects new Deployment, creates ReplicaSet
4. ReplicaSet Controller creates Pod objects
5. Scheduler assigns Pods to Nodes (resource fit, affinity, taint toleration)
6. kubelet on assigned Node pulls image via containerd
7. kube-proxy updates iptables rules for Service routing
8. Readiness probe passes → Pod added to Service endpoints → receives traffic

---

### Q: How do you design an EKS platform for multiple teams?

**Answer:**

**Multi-tenancy model:**
- One EKS cluster per environment tier (Dev/QA/Prod) — not one per team
- Namespaces per team: teams get `edit` in their namespace, `view` in others
- RBAC via IAM Identity Mappings (aws-auth ConfigMap or Access Entries)

**Shared platform services (one installation per cluster):**
```
Platform Layer:
├── AWS Load Balancer Controller   (ALB/NLB automatic provisioning)
├── External DNS                   (Route 53 record management)
├── Cert Manager                   (ACM / Let's Encrypt TLS)
├── Karpenter                      (right-sized node provisioning)
├── AWS EBS/EFS CSI Drivers        (persistent volumes)
├── External Secrets Operator      (sync Secrets Manager → K8s secrets)
├── Kyverno                        (admission policy enforcement)
├── Prometheus + Grafana           (metrics + dashboards)
├── Fluent Bit → CloudWatch Logs   (log aggregation)
└── AWS Distro for OpenTelemetry   (traces → X-Ray)
```

**Kyverno policies (enforced for all teams):**
- Require resource requests/limits on all containers
- Require labels: `team`, `app`, `environment` on all resources
- Deny privileged containers, hostPath mounts, hostNetwork
- Require non-root user in container spec
- Images only from approved ECR registry

---

### Q: Explain IRSA (IAM Roles for Service Accounts) and why it matters.

**Answer:**

IRSA maps a Kubernetes ServiceAccount to an AWS IAM Role. Instead of giving the entire EC2 node IAM permissions (which all pods share), each pod gets only the permissions for its specific ServiceAccount.

**How it works:**
1. Create IAM Role with trust policy for EKS OIDC provider
2. Annotate K8s ServiceAccount: `eks.amazonaws.com/role-arn: arn:aws:iam::123:role/my-role`
3. EKS Pod Identity webhook injects temporary AWS credentials into the pod

**Example in Terraform:**
```hcl
resource "aws_iam_role" "app_role" {
  name = "my-app-role"
  assume_role_policy = jsonencode({
    Statement = [{
      Effect = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.eks.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${aws_iam_openid_connect_provider.eks.url}:sub" =
            "system:serviceaccount:production:my-app-sa"
        }
      }
    }]
  })
}
```

**Without IRSA:** All pods on a node share the node's IAM role → a compromised app pod can access ECR, S3, or other AWS services it shouldn't.

**With IRSA:** Fine-grained permissions per pod. ALB controller gets only `elasticloadbalancing:*`. App pods get only `secretsmanager:GetSecretValue` for their specific secrets. Compromise of one pod doesn't compromise others.

---

### Q: CrashLoopBackOff — systematic debugging.

**Answer:**

```bash
# Step 1: Get pod status and events
kubectl describe pod <name> -n <namespace>
# Look at: Events section, Last State, Exit Code, Reason

# Step 2: Check previous container logs
kubectl logs <pod> -n <namespace> --previous

# Step 3: Interpret exit codes
# Exit 137 = OOMKilled   → increase resources.limits.memory
# Exit 1   = App error   → read logs carefully
# Exit 143 = SIGTERM     → graceful shutdown failed (check terminationGracePeriod)
# Exit 0   = Completed   → check restartPolicy (should be Never for Jobs)

# Step 4: If container dies too fast for logs
kubectl run debug-pod --image=<same-image> --command -- sleep 3600
kubectl exec -it debug-pod -- /bin/sh
# Manually run the entrypoint to see startup errors

# Step 5: Check resource consumption
kubectl top pod <name> -n <namespace>

# Step 6: Check ConfigMaps/Secrets exist
kubectl get configmap,secret -n <namespace>

# Step 7: Check image pull failures
kubectl get events -n <namespace> --sort-by='.lastTimestamp' | tail -20
```

**Most common causes (in order of frequency):**
1. OOMKilled (memory limit too low) → increase `resources.limits.memory`
2. Missing env var / config → check ConfigMap/Secret references in deployment
3. DB connection failure → check NetworkPolicy, SG, credentials, endpoint DNS
4. Readiness probe too aggressive → increase `initialDelaySeconds`
5. Image pull failure → check tag, ECR auth, IAM role for nodes

---

### Q: How do you implement zero-downtime deployments in Kubernetes?

**Answer:**

All five mechanisms must be in place simultaneously:

```yaml
# 1. Rolling update strategy
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1           # 1 extra pod during rollout (capacity)
    maxUnavailable: 0     # Never drop below desired replica count

# 2. Readiness probe — new pod ONLY receives traffic after health check passes
readinessProbe:
  httpGet:
    path: /actuator/health
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10

# 3. Graceful shutdown — allows in-flight requests to complete
terminationGracePeriodSeconds: 30
lifecycle:
  preStop:
    exec:
      command: ["/bin/sh", "-c", "sleep 5"]
# sleep 5 allows kube-proxy to update iptables before container stops
# Without this: 502 errors during rolling deployment

# 4. Pod Disruption Budget — prevents voluntary disruptions removing all pods
apiVersion: policy/v1
kind: PodDisruptionBudget
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: my-service

# 5. Topology spread — pods across AZs so rolling update hits one AZ at a time
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: DoNotSchedule
```

---

### Q: HPA vs VPA vs Karpenter — when do you use each?

**Answer:**

| Autoscaler | What it scales | Trigger | Use case |
|------------|---------------|---------|----------|
| **HPA** | Pod replicas (horizontal) | CPU/memory/custom metric | Stateless apps |
| **VPA** | Pod resource requests (vertical) | Historical usage | Stateful apps, batch |
| **Karpenter** | EC2 nodes (right-sized) | Pending unschedulable pods | Replace Cluster Autoscaler |

**HPA example (scale on CPU):**
```yaml
metrics:
- type: Resource
  resource:
    name: cpu
    target:
      type: Utilization
      averageUtilization: 70   # Add pods when avg CPU > 70%
```

**Karpenter vs Cluster Autoscaler:**
| Feature | Cluster Autoscaler | Karpenter |
|---------|-------------------|-----------|
| Granularity | Node Group level | Individual nodes |
| Instance selection | Fixed type per group | Auto-selects cheapest fit |
| Scale-up speed | 2-5 minutes | 30-60 seconds |
| Spot support | Manual ASG config | Built-in + consolidation |

**HPA + Karpenter flow:**
```
Load increases → HPA adds pods → Pods go Pending (no node capacity)
→ Karpenter provisions right-sized node in 60s → Pods scheduled

Load decreases → HPA removes pods → Nodes underutilized
→ Karpenter consolidates (moves pods, terminates node) → Cost savings
```

---

### Q: How do you implement Pod Security in Kubernetes 1.25+?

**Answer:**

PodSecurityPolicy was removed in K8s 1.25. Replaced by **Pod Security Admission (PSA)**:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted   # BLOCKS non-compliant pods
    pod-security.kubernetes.io/audit: restricted      # LOGS violations
    pod-security.kubernetes.io/warn: restricted       # WARNS on admission
```

**Restricted profile enforces:**
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop: ["ALL"]
  seccompProfile:
    type: RuntimeDefault
```

**For more granular control — Kyverno ClusterPolicy:**
```yaml
# Require all images from our ECR only
rules:
- name: require-ecr-registry
  match:
    resources:
      kinds: [Pod]
  validate:
    message: "Images must come from approved ECR registry"
    pattern:
      spec:
        containers:
        - image: "123456789012.dkr.ecr.us-east-1.amazonaws.com/*"
```

---

## 10. Observability & SRE

### Q: Explain SLIs, SLOs, SLAs, and Error Budgets with a real example.

**Answer:**

**SLI (Service Level Indicator):** A quantitative measure of service behavior.
- `successful_requests / total_requests` = availability SLI
- `requests_served_under_300ms / total_requests` = latency SLI

**SLO (Service Level Objective):** A target for an SLI.
- "99.9% of requests succeed over a 30-day rolling window"
- "95% of requests complete in < 300ms"

**SLA (Service Level Agreement):** A contract with financial consequences.
- "If availability drops below 99.5%, customer gets a 10% bill credit"
- SLA is always LESS strict than internal SLO (buffer to avoid breach)

**Error Budget:** Inverse of SLO — how much unreliability you're allowed.
| SLO | Error Budget | Monthly downtime allowed |
|-----|-------------|--------------------------|
| 99% | 1% | 7.3 hours |
| 99.9% | 0.1% | 43.8 minutes |
| 99.95% | 0.05% | 21.6 minutes |
| 99.99% | 0.01% | 4.3 minutes |

**How to use error budgets operationally:**
- Budget > 50%: Ship features aggressively, take risks
- Budget 20-50%: Ship carefully, increase testing
- Budget < 20%: Freeze feature releases, focus on reliability work
- Budget exhausted: All engineering shifts to reliability — no new features

---

### Q: SLO-based alerting — how do you avoid alert fatigue?

**Answer:**

**Multi-window, multi-burn-rate alerting** (Google SRE approach):

| Window | Burn Rate | Meaning | Action |
|--------|-----------|---------|--------|
| 1 hour | 14.4x | Budget consumed in 2 hours | Page immediately (SEV1) |
| 6 hours | 6x | Budget consumed in 5 days | Page (SEV2) |
| 3 days | 1x | On-schedule consumption | Ticket (investigate) |

**Why this beats threshold alerts:** A 30-second spike won't page. Sustained elevated errors that threaten the monthly budget will.

**Prometheus example:**
```yaml
- alert: HighErrorBudgetBurnRate
  expr: |
    (sum(rate(http_requests_total{status=~"5.."}[1h]))
    / sum(rate(http_requests_total[1h]))) > (14.4 * 0.001)
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "Error budget burning 14.4x faster than allowed"
    runbook: "https://wiki/runbooks/high-error-rate"
```

**Google's alerting rules:**
1. Every alert must be **actionable** — if you can't do anything, don't alert
2. Every alert must be **urgent** — if it can wait until morning, it's not a page
3. Every alert must have a **runbook link** — on-call shouldn't guess
4. **Alert on symptoms, not causes** — "users seeing errors" not "CPU is high"

---

### Q: Describe your incident response process.

**Answer:**

**Phase 1: Detection (0-5 min)**
- Alert fires (PagerDuty/OpsGenie) → on-call acknowledges
- Severity classification:
  - **SEV1:** Customer-facing outage, revenue impact → all-hands war room
  - **SEV2:** Degraded performance, partial outage → primary + backup on-call
  - **SEV3:** Non-critical → handle during business hours

**Phase 2: Mitigation (5-30 min)**
- **Mitigate first, debug later.** Goal: restore service, not find root cause
- Common actions: rollback deployment, scale up, failover to DR, toggle feature flag, restart pods
- Communicate: Status page update, Slack every 15 min

**Phase 3: Resolution**
- Apply permanent fix once mitigation stabilizes
- Verify via monitoring that SLIs return to baseline

**Phase 4: Blameless Postmortem (within 48 hours)**
```markdown
## Incident: Auth Service Timeout — 2026-06-15
### Impact: 45 min downtime, 12,000 users, 8% of monthly error budget consumed
### Timeline
14:00 — Deploy v2.3.1 | 14:05 — Error rate spike 0.1% → 15%
14:08 — Alert fires   | 14:18 — Root cause: DB migration locked table
14:22 — Rollback      | 14:30 — Service restored
### Root Cause
ALTER TABLE ran on hot table without pt-online-schema-change → lock contention
### Contributing Factors
No pre-prod load test with migration; checklist lacked lock-impact check
### Action Items
- [ ] Add lock-impact check to migration review (Owner: @alice, Due: June 20)
- [ ] Implement pt-online-schema-change for all DDL (Owner: @bob, Due: June 25)
- [ ] Add DB lock duration CloudWatch alert (Owner: @carol, Due: June 18)
```

**Target MTTR:** < 30 minutes for SEV1. MTTR matters more than MTBF — failures are inevitable, slow recovery is optional.

---

### Q: How do you monitor a Java application on EKS?

**Answer:** Three pillars (metrics, logs, traces):

**Metrics (Prometheus scraping via annotations):**
```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
  prometheus.io/path: "/actuator/metrics"
```
Spring Boot Actuator exposes: JVM heap, GC pause times, thread pools, HTTP request latency, DB connection pool, custom business metrics.

**Logs:** Application → stdout → Container runtime → Fluent Bit DaemonSet → CloudWatch Logs Insights. Structured JSON logging with correlation IDs for request tracing.

**Traces:** AWS Distro for OpenTelemetry → X-Ray. Distributed tracing across all microservices with service map and latency breakdown per dependency.

**Alerting:** CloudWatch Alarms → SNS → PagerDuty/Slack:
- CPU > 80% for 5 minutes
- 5xx error rate > 1% for 5 minutes
- Pod restart count > 3 in 15 minutes
- Memory utilization > 85%

---

## 11. Cost Optimization & FinOps

### Q: Design a cost optimization strategy for AWS.

**Answer:**

**FinOps framework: INFORM → OPTIMIZE → OPERATE**

**INFORM (Visibility):**
- Tag everything: `Project`, `Team`, `Environment`, `CostCenter` (enforce via SCP or AWS Config)
- Centralized cost dashboard: per-team, per-service, per-environment via Cost Explorer
- Anomaly detection: alert when daily spend deviates > 20% from 30-day baseline
- Showback/chargeback: weekly reports per team

**OPTIMIZE (Action):**

| Strategy | Savings | Best For | Effort |
|----------|---------|----------|--------|
| Right-sizing (Compute Optimizer) | 20-40% | Oversized EC2/RDS | Low |
| Reserved Instances (1yr) | 30-40% | Steady-state RDS, ElastiCache | Medium |
| Savings Plans (1yr) | 20-30% | Variable EC2, Fargate, Lambda | Medium |
| Spot Instances | 60-90% | Batch, CI runners, dev/test | Medium |
| Graviton (ARM) | 20% | EC2, RDS, ElastiCache | Low |
| S3 Lifecycle policies | 50-80% | S3 storage | Low |
| Dev/staging shutdown | 65% compute | Non-prod instances | Low |

**Quick wins checklist:**
```
✅ Unattached EBS volumes ($0.10/GB/month) — delete or snapshot
✅ Idle Elastic IPs ($3.65/month each) — release unused
✅ Old snapshots — implement retention policy
✅ Unused NAT Gateways ($32/month + $0.045/GB) — remove
✅ S3 Gateway endpoints (FREE) — replace NAT for S3 traffic
✅ EC2 dev instances — EventBridge + Lambda to stop at 7 PM, start at 8 AM
```

**OPERATE (Culture):**
- Monthly FinOps reviews with engineering leads
- Cost as a non-functional requirement in every architecture review
- "Unit economics" thinking: cost per transaction, cost per user
- Engineering teams own their cloud spend

---

## 12. Landing Zones & Multi-Account Governance

### Q: How do you design a landing zone for a large enterprise?

**Answer:**

**Account structure (AWS Control Tower + Organizations):**
```
Management Account (billing, SCPs, no workloads)
│
├── Security OU
│   ├── Log Archive Account      (centralized CloudTrail, VPC Flow Logs — S3 Object Lock)
│   └── Security Tooling Account (GuardDuty delegated admin, Security Hub aggregator)
│
├── Infrastructure OU
│   └── Network Hub Account      (Transit Gateway, DX, DNS Route 53 Resolver)
│       └── Shared Services VPC  (CI/CD, ECR, Artifactory, internal tooling)
│
├── Workloads OU
│   ├── Dev Account     → Dev VPC attached to TGW
│   ├── Staging Account → Staging VPC attached to TGW
│   └── Production Account → Prod VPC attached to TGW
│
└── Sandbox OU (experimentation, auto-cleanup, no TGW access)
```

**Why separate accounts (not just separate VPCs)?**
- Blast radius isolation — dev misconfiguration can't affect prod
- Hard security boundary (SCPs enforced at account level, cannot be overridden by IAM)
- Independent billing + cost attribution
- Easier compliance scoping (PCI workloads in dedicated account)

**Guardrails:**
- **Preventive SCPs:** deny non-approved regions, deny disabling CloudTrail, deny creating unencrypted RDS
- **Detective Config Rules:** tagging compliance, public SG check, public S3 check
- All controls codified in Terraform using AWS Landing Zone Accelerator patterns

---

### Q: Multi-account networking — how do you connect 4 AWS accounts with on-premises?

**Answer:**

```
Network Hub Account:
  Transit Gateway (TGW) ← shared via RAM to all accounts
       │
       ├── Direct Connect Gateway (10G + MACsec)
       │     └── On-Premises DC
       │
       ├── S2S VPN (backup for DX)
       │
       ├── Inspection VPC (Palo Alto / Network Firewall)
       │
       ├── Dev Account VPC   (10.1.0.0/16) ← TGW attachment
       ├── Staging Account VPC (10.2.0.0/16) ← TGW attachment
       └── Production Account VPC (10.3.0.0/16) ← TGW attachment
```

**TGW route table design:**
- Pre-Inspection RT (all spoke + OnPrem): `0.0.0.0/0 → Inspection VPC`
- Post-Inspection RT (Inspection VPC): routes to each spoke VPC by CIDR
- No spoke-to-spoke direct routes → Dev cannot talk to Prod without going through firewall

**Centralized services:**
- Route 53 Resolver rules shared via RAM → consistent DNS across all accounts
- One Elastic IP pool for outbound internet (predictable IPs for partner whitelisting)
- Centralized VPC Flow Logs → Log Archive account S3 (immutable)

---

## 13. Disaster Recovery & Backup

### Q: Design a DR strategy for a 3-tier application.

**Answer:**

**Step 1: Define tiers with the business (cost vs. SLA):**
| Tier | RTO | RPO | Pattern | Cost |
|------|-----|-----|---------|------|
| Critical | < 15 min | < 5 min | Active-Active | $$$$$ |
| Important | < 2 hrs | < 1 hr | Pilot Light | $$$ |
| Standard | < 8 hrs | < 4 hrs | Warm Standby | $$ |
| Batch/Dev | < 24 hrs | < 24 hrs | Backup & Restore | $ |

**Pilot Light implementation (typical choice):**
| Component | Primary (us-east-1) | DR (us-west-2) |
|-----------|---------------------|----------------|
| DNS | Route 53 primary | Route 53 failover record |
| CDN | CloudFront (global) | Same distribution |
| Compute | EKS (3 AZs active) | ASG = 0 (pre-baked AMIs) |
| Database | Aurora Multi-AZ (writer) | Aurora Global DB read replica |
| Cache | ElastiCache cluster | ElastiCache Global Datastore |
| Storage | S3 + CRR + RTC | S3 destination bucket |
| Secrets | Secrets Manager | Secrets Manager (replicated) |

**Automated failover runbook (SSM Automation):**
1. Route 53 health check detects primary ALB failure
2. Promote Aurora Global DB in DR region (< 1 minute)
3. SSM Automation: scale ASG → update target groups → update Secrets Manager endpoint
4. Route 53 automatic DNS failover to DR ALB (TTL = 30 seconds)
5. Synthetic canary validates functionality

**DR testing schedule:**
- **Weekly:** AWS FIS experiment (AZ failure simulation)
- **Monthly:** Data restore test from AWS Backup
- **Quarterly:** Full DR failover test — actually fail traffic to DR region, measure RTO, fix gaps

---

### Q: How do you implement AWS Backup governance?

**Answer:**

**Centralized backup via AWS Backup + Organizations:**

```
Backup Plans (by tier):
  Tier 1 (Critical): Daily (35-day retention) + Monthly (12-month) + Yearly (7-year)
  Tier 2 (Important): Daily (14-day) + Monthly (3-month)
  Tier 3 (Standard): Weekly (4-week retention)

Backup Vault (per account):
  ├── AWS Backup Vault Lock (WORM) → prevents deletion even by root
  ├── KMS CMK encryption
  └── Cross-account/cross-region copy for Tier 1

Tag-based assignment: resource tag `backup-tier=1` → auto-enrolled in Tier 1 plan
```

**Compliance monitoring:**
- AWS Backup Audit Manager: automated compliance reports
- Config rule: `backup-plan-exists` for all RDS instances
- **Monthly automated restore test:** restore RDS snapshot to isolated VPC → run smoke test → delete

---

## 14. Migration Strategy

### Q: How do you approach migrating 500+ applications to AWS?

**Answer:**

**6R Framework (categorize every application):**
| R | Strategy | When | Example |
|---|----------|------|---------|
| **Retire** | Decommission | No business value | Legacy reporting nobody uses |
| **Retain** | Keep on-prem | Too risky to move now | Mainframe with 30-year COBOL |
| **Rehost** | Lift-and-shift | Quick win, low risk | Stateless web server → EC2 |
| **Replatform** | Lift-and-optimize | Minor changes for cloud benefit | MySQL → RDS (managed) |
| **Refactor** | Re-architect | High value, needs modernization | Monolith → microservices on EKS |
| **Repurchase** | Replace with SaaS | Better commercial option exists | On-prem email → Office 365 |

**Wave planning:**
```
Wave 1 (Month 1-2): 10-20 low-risk, non-critical apps
  → Build confidence, prove process, train team
  → Tools: AWS MGN (server migration), AWS DMS (database migration)

Wave 2 (Month 3-4): 30-50 medium-complexity apps
  → Includes database migrations (DMS for heterogeneous)

Wave 3 (Month 5-8): 50-100 core business apps
  → High-value, careful planning, parallel-run testing

Wave 4 (Month 9-12): Complex/legacy apps
  → May require refactoring, hybrid approaches, or Retain decision
```

**Migration factory model:**
- Standardized runbooks per migration pattern
- Dedicated team per wave (2 architects, 4 engineers, 1 PM)
- Automated testing framework (verify app works on AWS before cutover)
- War room for each cutover weekend

---

## 15. Containerization & Docker

### Q: Walk through Dockerfile security best practices.

**Answer:**

```dockerfile
# Stage 1: Builder (Maven + JDK — 800MB) — NEVER reaches production
FROM maven:3.9-eclipse-temurin-17 AS builder
WORKDIR /build
COPY pom.xml .
RUN mvn dependency:go-offline   # Cache dependencies BEFORE source (layer cache)
COPY src ./src
RUN mvn package -DskipTests

# Stage 2: Runtime (JRE only — 200MB)
FROM eclipse-temurin:17-jre-jammy

# Non-root user (prevents container escape gaining root)
RUN groupadd -r appgroup && useradd -r -g appgroup appuser

WORKDIR /app
COPY --from=builder /build/target/*.jar app.jar

# Health check (Docker-level, independent of K8s probes)
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

USER appuser    # Switch to non-root LAST (after COPY)

ENTRYPOINT ["java",
  "-XX:+UseContainerSupport",       # JVM respects cgroup limits
  "-XX:MaxRAMPercentage=75.0",      # Dynamic — 75% of container limit
  "-Djava.security.egd=file:/dev/./urandom",  # Fast entropy
  "-jar", "app.jar"]
```

**Why `MaxRAMPercentage` not `-Xmx`:** `-Xmx512m` is fixed. If container limit changes from 512Mi to 1Gi, you must update both the K8s manifest AND the Dockerfile. `MaxRAMPercentage=75.0` is dynamic — JVM auto-calculates based on container limit. 75% leaves 25% for non-heap (metaspace, thread stacks, native memory, GC).

**Why multi-stage:** Build tools (Maven, npm, compiler) never reach the production image. Source code, build cache, and dev dependencies stay in the builder stage only.

---

### Q: How do you manage secrets for containerized workloads?

**Answer:**

**Problem:** Kubernetes Secrets are only base64-encoded (not encrypted) in etcd by default.

**Solution (layered):**

1. **Encrypt etcd at rest:** EKS encrypts etcd with AWS KMS by default when you enable envelope encryption.

2. **External Secrets Operator (ESO) — preferred:**
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-credentials
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: db-credentials        # Creates this K8s Secret
  data:
  - secretKey: password
    remoteRef:
      key: prod/myapp/db        # Secrets Manager secret name
      property: password        # JSON field within the secret
```

3. **IRSA:** Pod-level IAM — pods get temporary credentials scoped only to their required Secrets Manager paths.

4. **RBAC:** Restrict `kubectl get secret` — most developers shouldn't have this access in production.

**Why ESO over ASCP (CSI Driver):** ESO gives better control over sync intervals, works natively with GitOps patterns, and the secret appears as a standard K8s Secret (compatible with all frameworks).

---

## 16. Behavioral & Leadership Questions

### Q: Tell me about a complex architecture you designed and the trade-offs.

**Answer (STAR):**

"At ITC Infotech, I was responsible for the AWS cloud architecture for Advantest's semiconductor test equipment migration — three product lines: GLP (Global License Platform), FNO (Feature Node Ordering), and AOL (Advanced Order Lifecycle). The challenge was that these systems had strict compliance requirements, needed offline processing capability at customer sites (edge), and required zero-downtime migration from on-premises.

**Architecture I designed:**
- Multi-tier VPC with public, private, application, and data subnets
- Multi-AZ RDS MSSQL migration using AWS DMS (heterogeneous migration with schema conversion)
- AWS ECS for containerized workloads (enabling fast autoscaling during license processing peaks)
- AWS IoT Core + Greengrass for edge nodes at customer sites — enabling offline license processing with telemetry buffering when connectivity is lost
- Site-to-Site VPN + Route 53 Resolver for hybrid DNS resolution
- Complete CI/CD pipeline using CodePipeline + CodeBuild + GitHub Actions with Trivy, SonarCloud, and JaCoCo

**Trade-offs I made:**
1. **ECS vs EKS:** Chose ECS for faster time-to-market. Trade-off: less flexibility for multi-cloud in future. Justified because Advantest is AWS-exclusive for this workload.
2. **Greengrass over Lambda@Edge:** Greengrass needed for offline processing. Trade-off: higher operational complexity for edge device fleet management. Justified by the core requirement of offline capability.
3. **DMS vs manual migration:** DMS for speed. Trade-off: schema conversion tool requires validation of every transformed object. We spent 2 weeks on DMS validation tasks.

**Result:** Migration completed on schedule with zero data loss, 40% reduction in infra costs vs on-premises, and successful PCI compliance audit."

---

### Q: How do you handle a disagreement with a senior stakeholder over an architectural decision?

**Answer:** "My approach is 'data, not opinions':

1. **Listen fully first** — understand their constraint. Often their resistance comes from valid organizational context I'm not aware of (budget, contractual obligations, existing vendor relationships).

2. **Validate their concern** — 'You're right that migrating the core banking database is high-risk. Let me address that specifically.'

3. **Present evidence** — industry benchmarks, AWS reference architectures, case studies from similar clients, TCO analysis showing 5-year cost comparison.

4. **Propose a low-risk pilot** — instead of 'let's re-architect everything,' propose: 'Let's take one non-critical service, containerize it, build the CI/CD pipeline, and measure the results in 4 weeks.'

5. **Document decisions as ADRs** — even when I go with their approach, the decision and rationale are documented. If it doesn't work out later, the ADR provides context for revisiting.

**Red line:** I will not compromise on security controls that violate compliance requirements. If a stakeholder wants to use hardcoded credentials or skip encryption, I escalate to their CISO with documented risk exposure — that's a professional obligation, not a personal disagreement."

---

### Q: How do you drive technical upskilling in your team?

**Answer:**

1. **Architecture Katas:** Monthly workshops — engineers design systems for realistic scenarios, present to peers, get feedback. Builds architecture thinking breadth across the team.

2. **Certification support:** I sponsor and actively coach team members for AWS certifications. I created study groups with weekly sessions and share exam tips from my own SAA, CCP, and GCP-PCA journeys.

3. **Innovation sprints (20% time):** One sprint per quarter for engineers to explore new technologies. Examples from my teams: evaluating Karpenter vs Cluster Autoscaler, building a FinOps dashboard with CUR + Athena + QuickSight, testing Terraform 1.5 import blocks.

4. **Internal tech talks:** Bi-weekly 30-minute sessions. Everyone presents at least once per quarter. Topics: deep dives on AWS services, lessons from incidents, new technology evaluations.

5. **Office hours:** Weekly open 30-minute session — any engineer brings design questions before they build the wrong thing.

---

## 17. Scenario-Based Troubleshooting

### Q: EC2 in private subnet cannot connect to RDS. How do you troubleshoot?

**Answer (layer by layer):**

```
Step 1: Security Group Check
  RDS SG → Inbound: port 5432/3306 allowed FROM EC2 SG?
  EC2 SG → Outbound: port 5432/3306 allowed TO RDS SG?
  Fix: Add inbound to RDS SG:
    Type: PostgreSQL | Port: 5432 | Source: sg-ec2-id (SG reference, not CIDR)

Step 2: NACL Check (stateless — must check both directions)
  EC2 subnet NACL → Outbound: port 5432 allowed?
  RDS subnet NACL → Inbound: port 5432 allowed?
  RDS subnet NACL → Outbound: ephemeral ports 1024-65535 allowed? (return traffic)
  EC2 subnet NACL → Inbound: ephemeral ports 1024-65535 allowed?

Step 3: Route Table Check
  EC2 subnet RT → Has route to RDS subnet CIDR? (should be "local")
  If different VPC → Need VPC peering or TGW route + appropriate SGs

Step 4: RDS Configuration
  Is RDS in same VPC? Is publicly_accessible = false? (good)
  Is RDS DB subnet group using correct private data subnets?

Step 5: DNS Resolution
  From EC2: nslookup mydb.cluster-xxx.us-east-1.rds.amazonaws.com
  VPC DNS resolution enabled? enableDnsSupport = true on VPC

Step 6: IAM Auth (if using RDS IAM authentication)
  Does EC2 instance role have rds-db:connect permission?
  Is IAM authentication enabled on RDS instance?

Step 7: Connectivity test (from EC2)
  nc -zv <rds-endpoint> 5432
  telnet <rds-endpoint> 5432
```

---

### Q: A production RDS instance has `PubliclyAccessible = true`. How do you respond?

**Answer:**

**Immediate (0-4 hours):**
1. Verify via AWS Config: is `PubliclyAccessible = true` AND does the SG allow 0.0.0.0/0 on port 3306/5432?
2. If SG allows public access: **immediately restrict SG** to remove the public rule → blast radius containment
3. Check CloudTrail: any external connections to this endpoint in last 30 days?
4. Notify CISO, open incident ticket — material security finding regardless of breach confirmation

**Short-term (1-2 weeks):**
1. Modify RDS: `publicly_accessible = false` → update Terraform state (`terraform import`)
2. Root cause: misconfigured Terraform module? manual change? gap in standards?
3. Add SCP: deny `rds:ModifyDBInstance` with `PubliclyAccessible = true`
4. Add Config Rule: `rds-instance-public-access-check` with Lambda auto-remediation

**Long-term (architecture fix):**
1. All DB access via application layer only — no direct DB access from developer machines
2. DBA access via SSM Session Manager port-forwarding or RDS Proxy
3. Terraform RDS module: hardcode `publicly_accessible = false` — not a variable (cannot be overridden)

---

### Q: Terraform state file is corrupted. How do you recover?

**Answer:**

```bash
# Step 1: Check S3 versioning (this is why versioning is MANDATORY)
aws s3api list-object-versions \
  --bucket company-terraform-state \
  --prefix production/terraform.tfstate

# Step 2: Download the last known good version
aws s3api get-object \
  --bucket company-terraform-state \
  --key production/terraform.tfstate \
  --version-id "vXXXXXXXXXXXXXXXX" \
  state-backup.tfstate

# Step 3: Restore
aws s3 cp state-backup.tfstate \
  s3://company-terraform-state/production/terraform.tfstate

# Step 4: Verify
terraform plan
# Should show: No changes. Infrastructure is up-to-date.

# If no good version exists — rebuild state from scratch:
terraform import aws_vpc.main vpc-0abc123
terraform import aws_subnet.private_a subnet-0def456
# Import every resource one by one
# Then: terraform plan should show No changes
```

**Prevention:**
- S3 versioning: **always enabled** on state bucket
- DynamoDB locking: **always enabled**
- MFA delete on state bucket: enabled (even root cannot delete without MFA)
- Never manually edit `.tfstate` files

---

### Q: How do you handle an EKS cluster upgrade (e.g., 1.29 → 1.31)?

**Answer:**

**Phase 1: Pre-upgrade validation**
```bash
# Check API deprecations (critical step)
kubectl convert --list-resource-types   # or use pluto
pluto detect-helm -o wide              # Lists deprecated API versions in use

# Check node group compatibility
aws eks describe-addon-versions --kubernetes-version 1.31

# Review cluster addons compatibility
kubectl get addons -A
```

**Phase 2: Upgrade sequence (always in order)**
```
1. Control plane: 1.29 → 1.30 → 1.31 (one minor version at a time — skip not supported)
   aws eks update-cluster-version --name my-cluster --kubernetes-version 1.30

2. Core add-ons AFTER control plane:
   - kube-proxy
   - CoreDNS
   - VPC CNI (aws-node)
   Wait for all add-on pods to be Running before proceeding

3. Node groups (rolling replacement):
   - Update launch template AMI (EKS Optimized AMI for 1.30)
   - Set maxUnavailable = 1 (or 25% for large clusters)
   - Monitor: kubectl get nodes -w
   
4. Repeat: 1.30 → 1.31 (same sequence)
```

**Phase 3: Post-upgrade validation**
```bash
kubectl get nodes                          # All nodes on 1.31
kubectl get pods -A | grep -v Running      # Any non-Running pods?
kubectl get events -A | grep Warning       # Any warnings?
# Run smoke tests for all critical workloads
```

**Key pitfalls:**
- Never skip minor versions (e.g., 1.29 → 1.31 directly is unsupported)
- Upgrade control plane BEFORE node groups — backwards compatible, not forwards
- Check PodSecurityPolicy removals (removed in 1.25), PSP → PSA migration required
- EKS managed node groups: AWS drains and replaces nodes automatically; self-managed: manual drain

---

### Q: How do you troubleshoot high latency in a microservices architecture?

**Answer:**

```
Step 1: Identify the affected layer
  → CloudWatch Container Insights: which service has high p99 latency?
  → AWS X-Ray service map: trace the request path, find the bottleneck segment

Step 2: Narrow down
  → Database: check RDS Performance Insights → slow query logs → missing index?
  → Network: VPC Flow Logs → packet loss? → check NACL, SG, MTU issues
  → Application: heap dumps, thread dumps → GC pressure? thread pool saturation?
  → External dependency: API timeout → circuit breaker tripping?

Step 3: Common causes and fixes
  DB connection pool exhausted:
    → Symptom: DB latency low, app latency high
    → Fix: increase HikariCP maxPoolSize, add RDS Proxy (connection multiplexing)
  
  Cold start (Lambda or ECS Fargate):
    → Fix: provisioned concurrency (Lambda), ECS warm pool, readiness probes
  
  Memory pressure + GC:
    → Symptom: latency spikes every N seconds
    → Fix: increase memory limit, tune G1GC, check for memory leaks
  
  DNS resolution delays:
    → Symptom: first request to a new host is slow
    → Fix: CoreDNS NodeLocal caching, increase ndots configuration

Step 4: Implement circuit breaker (prevent cascade failures)
  → Resilience4j for Java, or Istio/Linkerd service mesh at L7
```

---

## 18. Rapid-Fire Cheat Sheet

### AWS Service Quick Reference

| Question | Answer |
|----------|--------|
| EBS vs EFS vs S3 | EBS: block, single EC2 attach; EFS: POSIX, shared NFS, multi-attach; S3: object, global, unlimited |
| SQS vs SNS vs EventBridge | SQS: queue (pull, decoupling); SNS: fan-out pub/sub; EventBridge: event routing with rules |
| Aurora vs RDS | Aurora: cluster (writer+readers), faster failover (<30s), 5x MySQL throughput, Global DB for cross-region |
| CloudFront vs Global Accelerator | CF: CDN (caches HTTP/S content at edge); GA: TCP/UDP routing, static IPs, any protocol |
| ACM vs IAM certificates | ACM: free, auto-renew, used with ALB/CloudFront; IAM: self-managed, used for older services |
| Secrets Manager vs Parameter Store | SM: auto-rotation, higher cost; SSM PS: cheaper, no auto-rotation, SecureString via KMS |
| NLB vs ALB | NLB: Layer 4 (TCP/UDP), static IP, ultra-low latency; ALB: Layer 7 (HTTP), path/host routing |
| ElastiCache Redis vs Memcached | Redis: persistence, pub/sub, data structures, replication; Memcached: simpler, multi-threaded |
| Kinesis vs SQS | Kinesis: real-time streaming, ordered, replay, 7-day retention; SQS: queuing, at-least-once delivery |

---

### Terraform Quick Reference

| Concept | Key Fact |
|---------|---------|
| State locking | DynamoDB table with LockID. `terraform force-unlock <LOCK_ID>` if stuck |
| Sensitive outputs | `sensitive = true` — hides value from CLI but still exists in state |
| `depends_on` | Explicit dependency when Terraform can't infer. Use sparingly. |
| `lifecycle prevent_destroy` | Throws error instead of destroying. Required for stateful resources. |
| `terraform taint` | Marks resource for recreation. Deprecated in 1.x — use `terraform apply -replace` |
| Data sources | Read-only reference to existing resources. `data "aws_vpc" "existing"` |
| Moved blocks | Rename resources without destroy/recreate: `moved { from = aws_vpc.old to = aws_vpc.new }` |

---

### Kubernetes Quick Reference

| Concept | Key Fact |
|---------|---------|
| `kubectl get pods -A` | All pods across all namespaces |
| `kubectl describe pod` | Events, resource limits, probe status — FIRST debugging command |
| `kubectl logs --previous` | Logs from crashed container (CrashLoopBackOff) |
| Requests vs Limits | Request = guaranteed minimum (used for scheduling); Limit = maximum (enforced) |
| Guaranteed QoS | request == limit → last to be evicted |
| BestEffort QoS | No requests/limits set → first to be evicted. Never use in production. |
| ResourceQuota | Namespace-level cap (total CPU/memory/pods). Prevents noisy neighbor. |
| LimitRange | Per-container defaults. Catches pods with missing resource specs. |
| PDB | PodDisruptionBudget. Prevents too many pods being disrupted at once. |
| etcd | All cluster state stored here. Backup etcd = backup your cluster. |

---

### Security Quick Reference

| Topic | Key Fact |
|-------|---------|
| IMDSv2 | Requires PUT to get session token — blocks SSRF-based metadata theft. `http_tokens = "required"` |
| MACsec | Layer 2 encryption on Direct Connect. Not internet-based — hardware level. |
| GuardDuty finding → action | EventBridge rule → Lambda → isolate EC2 (detach from ASG, apply deny-all SG) |
| CloudTrail | API calls logged globally. Enabled org-wide via Organizations. Stored in Log Archive account. |
| Permission Boundary | IAM policy that limits maximum permissions a role/user can have. Prevents privilege escalation. |
| SCP | Service Control Policy. Applies to ALL principals in an OU/account including root. |
| AWS Config | Tracks resource configuration history. Config Rules = continuous compliance checks. |
| Macie | ML-based PII discovery in S3. Finds SSNs, credit card numbers, API keys in buckets. |
| Inspector | Vulnerability scanning for EC2 AMIs, ECR images, Lambda functions. |

---

### Behavioral Answer Frameworks

| Situation | Framework |
|-----------|-----------|
| Any behavioral question | **STAR** (Situation → Task → Action → Result) |
| "Tell me about yourself" | **Present → Past → Future** (90-120 seconds) |
| Under pressure | **Stabilize → Prioritize → Communicate** |
| Weakness questions | Real weakness + active improvement + measurable result |
| Conflict with stakeholder | Empathy → Data → Pilot → Document (ADR) |
| Failure questions | Own it → Root cause analysis → System change → Prevent recurrence |
| Tight deadline | Scope audit → Critical path → Parallelize → Communicate risk early |

---

### DORA Metrics Targets (Elite)

| Metric | Elite | High | Medium | Low |
|--------|-------|------|--------|-----|
| Deployment Frequency | ≥ 1/day | 1/week–1/day | 1/month–1/week | < 1/month |
| Lead Time | < 1 hour | 1 day–1 week | 1 week–1 month | > 1 month |
| Change Failure Rate | < 15% | 16-30% | 16-30% | > 30% |
| MTTR | < 1 hour | 1-24 hours | 1-7 days | > 1 week |

---

### Your Certifications to Mention

| Cert | Year | Relevance |
|------|------|-----------|
| AWS Certified Solutions Architect – Associate | 2023 | Core AWS architecture credibility |
| AWS Certified Cloud Practitioner | 2023 | Foundational AWS breadth |
| Google Cloud Professional Cloud Architect | 2023 | Multi-cloud positioning |

---

## Appendix: Key Projects to Reference

### ITC Infotech — Advantest Cloud Migration (Feb 2025 – Present)
- **Architecture:** Enterprise AWS with multi-tier VPC, ECS containerization, multi-AZ RDS MSSQL, Site-to-Site VPN, Route 53 Resolver
- **DevOps:** Terraform IaC, CodePipeline + CodeBuild + GitHub Actions, Trivy + SonarCloud + JaCoCo security gates
- **Edge:** AWS IoT Core + Greengrass — offline license processing at customer sites
- **Security:** IAM, WAF, GuardDuty, Security Hub, automated compliance validation

### Wipro — HPE K-GPT AI Document Search (May 2021 – Feb 2025)
- **Architecture:** Private EKS cluster behind NLB + PrivateLink; API Gateway + Route 53 ingress; Greengrass edge on Palo Alto appliances
- **IaC:** Terraform for all infra; Azure DevOps for CI/CD
- **Compliance:** HIPAA, SOX, PCI-DSS, GDPR alignment
- **Monitoring:** CloudWatch, CloudTrail, Splunk integration

### Wipro — Nokia NetAct Migration (May 2019 – Apr 2021)
- **Migration:** Legacy systems → AWS using Terraform + Ansible
- **CI/CD:** Jenkins + Maven + Docker pipelines
- **Workloads:** EC2, Lambda, S3, RDS, ELB, Auto Scaling

---

*Document consolidated from all interview prep sources in this folder.*  
*Last updated: June 2026 | Pushparaj Naik | pushparaj.naik@gmail.com*
