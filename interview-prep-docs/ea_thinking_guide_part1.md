# Enterprise Architect Thinking Guide — Cloud Migration Strategy

**Author:** Pushparaj Naik  
**Purpose:** Interview preparation — Enterprise Architect mindset for cloud strategy, migration, and execution  
**Key Principle:** *An Enterprise Architect doesn't think in tools — they think in business outcomes, risk, and trade-offs.*

---

## Question 1: How Do You Decide Which Cloud Is Best Suited for Deployment/Migration?

### The EA Mindset

An Enterprise Architect never says "I prefer AWS" or "We should use GCP." Instead, they say:

> *"The right cloud depends on the workload profile, organizational capabilities, regulatory constraints, and total cost of ownership. Let me walk you through how I evaluate this systematically."*

---

### Framework: Cloud Selection Decision Matrix

I use a **weighted scoring model** across 12 dimensions, scored by a cross-functional team (Architecture, Security, Finance, Operations, Development):

| # | Dimension | Weight | AWS | GCP | Azure | Scoring Criteria |
|---|-----------|--------|-----|-----|-------|-----------------|
| 1 | **Workload Fit** | 15% | 9 | 8 | 9 | Does the cloud have native services for our workload type? |
| 2 | **Existing Skills** | 12% | Score based on team assessment | | | How many engineers are certified/experienced? |
| 3 | **Enterprise Readiness** | 12% | 9 | 7 | 9 | Multi-account governance, IAM maturity, enterprise support |
| 4 | **Security & Compliance** | 12% | 9 | 8 | 9 | Compliance certifications, security tooling depth |
| 5 | **TCO (3-year)** | 10% | Based on pricing calculator | | | Compute + storage + network + support + licensing |
| 6 | **Data Residency** | 10% | 8 | 7 | 8 | Region availability in required geographies |
| 7 | **Ecosystem & Marketplace** | 8% | 9 | 7 | 8 | ISV integrations, marketplace maturity |
| 8 | **Hybrid/Multi-cloud** | 6% | 7 | 8 | 9 | On-prem connectivity (Outposts, Anthos, Arc) |
| 9 | **Data & Analytics** | 5% | 8 | 9 | 8 | Data platform services (Redshift vs BigQuery vs Synapse) |
| 10 | **AI/ML Capabilities** | 4% | 8 | 9 | 8 | ML platform maturity (SageMaker vs Vertex AI vs Azure ML) |
| 11 | **Container/K8s** | 3% | 9 | 9 | 8 | Managed Kubernetes maturity |
| 12 | **Vendor Relationship** | 3% | Score based on existing contracts | | | Existing EDP, credits, account team engagement |

**Scoring:** 1-10 per dimension. Final score = Σ (Weight × Score)

---

### When Each Cloud Wins — Industry Patterns

Based on Gartner Magic Quadrant 2024-2025, Flexera State of the Cloud Report 2025, and Forrester Wave analysis:

| Scenario | Best Fit | Why |
|----------|----------|-----|
| **Enterprise with large Windows/.NET estate** | Azure | Native AD integration, SQL Server licensing benefits, Hybrid via Arc |
| **Startup / Cloud-native, container-first** | AWS or GCP | EKS/GKE maturity, serverless depth, developer experience |
| **Heavy data analytics / ML-first** | GCP | BigQuery is best-in-class for analytics, Vertex AI for ML pipelines |
| **Banking / Financial Services** | AWS | Deepest compliance portfolio (PCI-DSS, SOX), most regions, largest enterprise customer base |
| **Government / Public Sector (India)** | AWS | GovCloud equivalent, RBI compliance, 2 India regions (Mumbai, Hyderabad) |
| **Multi-cloud strategy (mandated)** | GCP (Anthos) or Azure (Arc) | Best multi-cloud management planes |
| **SAP migration** | AWS or Azure | Both have certified SAP partnerships; Azure has tighter SAP integration |
| **IoT / Edge** | AWS | IoT Core + Greengrass — most mature IoT platform |
| **Media / Content delivery** | AWS | CloudFront + MediaLive + S3 — largest CDN |

---

### Supporting Research & Artifacts

**1. Gartner Magic Quadrant for Cloud Infrastructure & Platform Services (2024)**

- AWS: Leader (furthest right for completeness of vision)
- Azure: Leader (close second, strongest hybrid story)
- GCP: Leader (strongest in data/AI, gaining enterprise traction)

**2. Flexera 2025 State of the Cloud Report (key data points):**

- 89% of enterprises have a multi-cloud strategy
- AWS leads in enterprise adoption (73%), Azure close (72%), GCP growing (38%)
- Top cloud challenge: managing cloud spend (82% of respondents)
- Top cloud initiative: migrating more workloads (65%)

**3. Forrester Total Economic Impact Studies:**

- AWS Migration: 3-year ROI of 241%, payback in < 6 months (Forrester TEI 2023)
- Average infrastructure cost reduction: 31% after migration
- Average downtime reduction: 69% after migration

**4. IDC Cloud Pulse Survey 2024:**

- 76% of enterprises cite security as top cloud selection criterion
- 68% cite total cost of ownership
- 54% cite existing team skills

---

### Decision Tree (How I Present to Stakeholders)

```
START: What's the primary workload?
│
├── Windows/.NET/SQL Server heavy?
│   └── Azure (licensing benefits via AHUB, native AD integration)
│
├── Data Analytics / ML first?
│   └── GCP (BigQuery + Vertex AI — best price-performance for analytics)
│
├── General enterprise / Microservices / IoT?
│   └── AWS (broadest service portfolio, deepest enterprise governance)
│
├── Regulatory mandate (data residency)?
│   └── Which cloud has regions in required geography?
│       ├── India only → AWS (2 regions) or Azure (3 regions)
│       └── Global → All three qualify
│
└── Multi-cloud mandated?
    └── Primary + secondary strategy
        └── Pick primary based on workload fit, secondary for specific use cases
```

---

### How I'd Answer in an Interview

> *"I don't pick a cloud based on personal preference. I run a structured evaluation with a weighted scoring model involving Architecture, Security, Finance, and Ops stakeholders. The evaluation covers 12 dimensions — workload fit, existing skills, compliance requirements, TCO, and ecosystem maturity.*
>
> *In my experience, AWS wins for general enterprise workloads and regulated industries because of its service breadth, compliance depth, and enterprise governance tooling. But if a client has a heavy .NET estate, Azure's licensing advantages make it the clear choice. And for data-first organizations, GCP's BigQuery is genuinely best-in-class.*
>
> *The key EA principle: the cloud is a business decision, not a technology decision. I present trade-offs with data, and let the business decide."*

---

## Question 2: How Do You Convince Your CTO? Assessment Strategy for Migrating 1000 Servers

### The EA Mindset

The CTO cares about three things:

1. **Risk:** "Will this break anything?"
2. **Cost:** "How much will it cost, and when do we see ROI?"
3. **Timeline:** "How long will this take?"

Your job as EA is to answer all three with **data, not opinions.**

---

### Phase 1: Discovery & Assessment (Weeks 1-6)

**Tooling:**

- **AWS Migration Hub + Application Discovery Service** — agent-based discovery of all 1000 servers
- **TSO Logic / Migration Evaluator** (free AWS tool) — generates TCO comparison

**What We Discover:**

| Data Point | Why It Matters |
|---|---|
| Server specs (CPU, RAM, disk, OS) | Right-sizing recommendations |
| Network dependencies (server-to-server communication) | Migration wave grouping |
| Application mapping (which servers form an application) | Prevents breaking app dependencies |
| Utilization data (30-day average CPU/memory) | Right-sizing — most servers are 20-30% utilized |
| License inventory (Oracle, SQL Server, SAP, etc.) | Licensing strategy — BYOL vs included vs replace |
| Data volumes and growth rate | Storage and transfer cost estimation |

**Output: Migration Portfolio Analysis**

```
1000 Servers Assessed:
├── 300 servers (30%) — Retire/Decommission
│   └── Unused, redundant, or end-of-life — immediate savings
├── 400 servers (40%) — Rehost (Lift & Shift)
│   └── Move to EC2 with minimal changes — fastest migration
├── 200 servers (20%) — Replatform
│   └── Move to managed services (RDS, ECS, ElastiCache)
├── 80 servers (8%) — Refactor
│   └── Modernize to containers/serverless — highest long-term value
└── 20 servers (2%) — Retain
    └── Regulatory or technical constraints — stay on-prem
```

---

### Phase 2: CTO Presentation — The Business Case

**Slide 1: Current State Pain Points**

| Pain Point | Cost/Impact |
|---|---|
| Data center lease renewal (18 months out) | $2.4M/year |
| Hardware refresh cycle needed | $3.5M capital expenditure |
| Average provisioning time | 6-8 weeks (vs. minutes in cloud) |
| Last year's downtime | 47 hours (costing ~$500K in lost productivity) |
| DR capability | Backup only, no tested DR — RTO = 72+ hours |

**Slide 2: TCO Comparison (3-Year)**

| Item | On-Premises (3yr) | AWS (3yr) | Savings |
|---|---|---|---|
| Compute (700 servers after retire) | $4.2M | $2.1M (right-sized + Savings Plans) | 50% |
| Storage | $1.8M | $0.6M (S3 tiering + EBS optimization) | 67% |
| Networking | $0.9M | $0.4M | 56% |
| Licensing (SQL Server, Windows) | $2.1M | $1.4M (AHUB-equivalent, Aurora migration) | 33% |
| Data center / Facilities | $7.2M | $0 | 100% |
| Staff (reduced ops overhead) | $3.6M | $2.4M (automation reduces headcount needs) | 33% |
| **Migration cost (one-time)** | $0 | **$1.8M** | — |
| **Total** | **$19.8M** | **$8.7M** | **56% savings** |
| **3-Year Net Savings** | — | — | **$11.1M** |

**Slide 3: Risk-Adjusted Timeline**

```
Month 1-2:  Foundation (Landing Zone, networking, security baseline)
Month 3-4:  Wave 1 — Non-critical apps (50 servers) — build confidence
Month 5-8:  Wave 2 — Business apps (200 servers) — validated patterns
Month 9-14: Wave 3 — Core systems (350 servers) — highest risk, most prep
Month 15-16: Wave 4 — Database migrations (100 servers) — DMS + cutover
Month 16-18: Decommission on-prem, optimize cloud
```

**Total: 18 months for 1000 servers (including 300 retirements)**

---

### Migration Wave Strategy (The Key to Cost Control)

**Wave Grouping Criteria:**

| Factor | How It Affects Waves |
|---|---|
| **Application dependencies** | Servers that talk to each other move together |
| **Business criticality** | Low-risk first, critical last (build confidence) |
| **Complexity** | Simple rehost first, complex refactor last |
| **Business calendar** | Avoid moves during peak business periods |
| **Team capacity** | 50-80 servers per wave (manageable batch size) |

**Cost Control Levers:**

1. **Retire 30% upfront** — saves $0 migration cost for 300 servers
2. **Right-size everything** — most servers are over-provisioned; average 40% cost reduction
3. **Reserved Instances / Savings Plans** — commit after Wave 1 for proven workloads (30-40% savings)
4. **Managed services** — replace 200 self-managed databases with RDS (reduce DBA effort by 60%)
5. **Automation** — invest in Terraform + CI/CD upfront; pay off by Wave 2
6. **AWS Migration Credits** — apply for MAP program (up to $100K-500K in credits for large migrations)

---

### How to Convince the CTO

**Don't lead with technology. Lead with business risk:**

> *"We have an 18-month window before our data center lease renewal. If we don't act, we're committing to another 5-year, $12M lease plus a $3.5M hardware refresh. Cloud migration costs $1.8M one-time and saves us $11M over 3 years. The risk of NOT migrating is greater than the risk of migrating."*

**Then address their fears:**

| CTO Fear | Your Response |
|---|---|
| "What if it costs more than expected?" | "We'll run a 50-server pilot wave first. If unit costs are > 10% above estimate, we pause and re-baseline." |
| "What about downtime during migration?" | "We use AWS DMS with CDC for databases — zero downtime cutover. Applications use blue-green DNS switch." |
| "Do we have the skills?" | "We'll embed an AWS Professional Services architect for Wave 1. By Wave 2, our team is self-sufficient." |
| "What if cloud is MORE expensive long-term?" | "Our TCO includes Savings Plans, right-sizing, and managed services. I'll set up monthly FinOps reviews to track actuals vs. forecast." |

---
