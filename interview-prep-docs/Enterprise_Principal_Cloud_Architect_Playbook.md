# Enterprise / Principal Cloud Architect Playbook

## How an Architect Thinks: From Customer Requirement to Project Closure

> **Author:** Pushparaj Naik
> **Scope:** AWS Cloud Projects — Greenfield, Migration & Modernization — End-to-End Lifecycle
> **Audience:** Enterprise Architects, Principal Cloud Architects, Solution Architects aspiring to senior roles

---

## Table of Contents

- [Part 1 — The Architect's Mindset](#part-1--the-architects-mindset)
- [Part 2 — Phase 0: Pre-Engagement & Customer Discovery](#part-2--phase-0-pre-engagement--customer-discovery)
- [Part 3 — Phase 1: Assess — Understand What You Have (Migration Track)](#part-3--phase-1-assess--understand-what-you-have-migration-track)
- [Part 3B — Greenfield Cloud-Native: From Zero to Production](#part-3b--greenfield-cloud-native-from-zero-to-production)
- [Part 4 — Phase 2: Mobilize — Prepare the Foundation](#part-4--phase-2-mobilize--prepare-the-foundation)
- [Part 5 — Phase 3: Migrate & Modernize — Execute in Waves](#part-5--phase-3-migrate--modernize--execute-in-waves)
- [Part 6 — Phase 4: Go-Live Readiness & Cutover](#part-6--phase-4-go-live-readiness--cutover)
- [Part 7 — Phase 5: Hypercare & Stabilization](#part-7--phase-5-hypercare--stabilization)
- [Part 8 — Phase 6: Project Closure & Transition to BAU](#part-8--phase-6-project-closure--transition-to-bau)
- [Part 9 — AWS Frameworks & References](#part-9--aws-frameworks--references)
- [Part 10 — Anti-Patterns & Hard Lessons](#part-10--anti-patterns--hard-lessons)

---

## Part 1 — The Architect's Mindset

### 1.1 First Principles — How a Principal Architect Thinks

A Principal/Enterprise Architect does **not** think in services or configurations. They think in **outcomes, constraints, risks, and trade-offs**. Before touching any technology, they ask five fundamental questions:

```
1. What BUSINESS OUTCOME is the customer trying to achieve?
   (Cost reduction? Agility? Compliance? Global expansion? M&A integration? New product launch?)

2. What are the NON-NEGOTIABLE CONSTRAINTS?
   (Regulatory, latency, data residency, budget ceiling, timeline, existing contracts)

3. What is the RISK APPETITE of this organization?
   (Startup vs. bank vs. government — entirely different risk postures)

4. What is the ORGANIZATIONAL READINESS?
   (Skills, culture, change management, executive sponsorship)

5. What does SUCCESS look like, and how will we MEASURE it?
   (KPIs, not vague goals — "reduce TCO by 30%" not "save money")

6. Is this MIGRATION, MODERNIZATION, or GREENFIELD?
   (Moving existing systems? Rearchitecting them? Building something entirely new?)
```

### 1.2 The Architect's Role vs. Other Roles

| Role | Thinks About | Horizon |
|------|-------------|---------|
| **Developer** | Features, code quality, sprint delivery | Days–Weeks |
| **DevOps Engineer** | Pipelines, automation, reliability | Weeks–Months |
| **Solutions Architect** | Technical design for a specific workload | Months |
| **Enterprise/Principal Architect** | Organization-wide strategy, standards, guardrails, long-term vision, trade-off decisions | **1–5 Years** |

### 1.3 The Three Lenses of an Enterprise Architect

Every decision is evaluated through three lenses simultaneously:

```
                    ┌─────────────┐
                    │  BUSINESS   │
                    │  Value, ROI │
                    │  Timeline   │
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              │                         │
       ┌──────▼──────┐          ┌──────▼──────┐
       │  TECHNOLOGY │          │  PEOPLE &   │
       │  Fit, Risk  │          │  PROCESS    │
       │  Debt, Scale│          │  Skills,    │
       └─────────────┘          │  Culture,   │
                                │  Change Mgmt│
                                └─────────────┘
```

**Critical Rule:** If you solve the technology problem but ignore the people/process problem, the project will fail. The #1 reason cloud projects fail — whether migration or greenfield — is **organizational readiness**, not technology.

### 1.4 Decision-Making Framework — RAPID

For every significant architectural decision, use a clear ownership model:

| Role | Meaning | Who |
|------|---------|-----|
| **R** — Recommend | Proposes the decision | Solution Architect / Tech Lead |
| **A** — Agree | Must agree (has veto) | Security, Compliance, Finance |
| **P** — Perform | Executes the decision | Engineering team |
| **I** — Input | Provides input but no veto | Stakeholders, SMEs |
| **D** — Decide | Makes the final call | **Enterprise/Principal Architect** or CTO |

### 1.5 The Architect's Communication Cadence

| Audience | Frequency | Content | Format |
|----------|-----------|---------|--------|
| **C-Suite / VP** | Bi-weekly / Monthly | Progress, risks, budget, business outcomes | Executive dashboard, 3-slide summary |
| **Program Manager** | Weekly | Milestone tracking, dependencies, blockers | Status report, RAID log |
| **Engineering Leads** | Weekly | Technical decisions, standards, patterns | ADRs, architecture diagrams |
| **Engineering Teams** | On-demand | Guidance, reviews, unblocking | Design reviews, office hours |
| **Security & Compliance** | Bi-weekly | Control implementation, audit readiness | Compliance matrix, evidence pack |

---

## Part 2 — Phase 0: Pre-Engagement & Customer Discovery

### 2.0 First — Classify the Engagement Type

Before diving into discovery, the architect must classify the engagement. This fundamentally changes the approach, tools, team composition, and timeline:

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                     THREE ENGAGEMENT TYPES                                  │
│                                                                              │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────────────┐   │
│  │  🟢 GREENFIELD   │  │  🟡 MIGRATION    │  │  🔴 MODERNIZATION        │   │
│  │                  │  │                  │  │                          │   │
│  │ No existing      │  │ Existing apps    │  │ Existing apps on cloud   │   │
│  │ system. Build    │  │ on-prem/colo.    │  │ or on-prem. Re-architect │   │
│  │ cloud-native     │  │ Move them to     │  │ for agility, scale,      │   │
│  │ from scratch.    │  │ AWS as-is or     │  │ cost, or new business    │   │
│  │                  │  │ with minimal     │  │ capabilities.            │   │
│  │ Examples:        │  │ changes.         │  │                          │   │
│  │ - New SaaS       │  │                  │  │ Examples:                │   │
│  │   product        │  │ Examples:        │  │ - Monolith → microsvcs   │   │
│  │ - New AI/ML      │  │ - DC exit        │  │ - Oracle → Aurora        │   │
│  │   platform       │  │ - Lease expiry   │  │ - VMs → containers       │   │
│  │ - New mobile     │  │ - M&A            │  │ - Add AI/ML to existing  │   │
│  │   backend        │  │ - DR to cloud    │  │   platform               │   │
│  │ - IoT platform   │  │                  │  │ - Multi-region expansion │   │
│  └──────────────────┘  └──────────────────┘  └──────────────────────────┘   │
│                                                                              │
│  KEY DIFFERENCE IN ARCHITECT'S APPROACH:                                     │
│                                                                              │
│  Greenfield:     Requirements → Architecture → Build → Ship                 │
│  Migration:      Discover → Assess → Mobilize → Migrate → Optimize         │
│  Modernization:  Assess current → Target design → Strangler/Refactor → Ship │
│                                                                              │
│  Greenfield is HARDER than migration because there's no existing system      │
│  to benchmark. Every decision is a design decision. Every pattern choice     │
│  has 10-year consequences.                                                   │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 2.1 When You First Hear the Customer Requirement

The very first conversation with the customer is the most critical. An Enterprise Architect **listens 80%, talks 20%**. You are not selling technology — you are understanding the problem.

#### What to Listen For

```
SIGNALS TO DETECT IN THE FIRST MEETING:

✅ GOOD SIGNALS                          ❌ RED FLAGS
─────────────────────────────────────    ─────────────────────────────────────
"We want to reduce time-to-market"       "Just move everything to the cloud"
"Our CTO is sponsoring this"             "No executive sponsor yet"
"We have compliance requirements"        "We'll figure out compliance later"
"We've tried PoCs already"               "We've never touched cloud"
"Budget is approved for 18 months"       "Can we do this in 3 months?"
"We want to modernize incrementally"     "Rewrite everything from scratch"

GREENFIELD-SPECIFIC SIGNALS:
✅ GOOD SIGNALS                          ❌ RED FLAGS
─────────────────────────────────────    ─────────────────────────────────────
"We have product requirements defined"   "We don't know what we want yet"
"Target users are identified"            "Build it and they will come"
"We understand cloud-native patterns"    "Can we just deploy a VM?"
"We've done competitive analysis"        "Nobody else does this"
"MVP first, then iterate"                "We need all features for launch"
"We have a product owner"                "Engineering will figure it out"
```

#### The Discovery Question Framework

Use this structured questioning approach in the first 2-3 meetings:

**Business Context** (All engagement types)

- What is driving this initiative? (Cost? Agility? Compliance? End-of-life hardware? New market opportunity?)
- Who is the executive sponsor? What is their success metric?
- What is the approved budget and timeline?
- Are there any contractual obligations (data center leases, vendor contracts)?

**Current State (As-Is)** (Migration/Modernization)

- How many applications are in scope? (10? 100? 1000?)
- What is the current infrastructure landscape? (On-prem? Colo? Hybrid? Multi-cloud?)
- What databases are in use? (Oracle? SQL Server? PostgreSQL? Mainframe?)
- What are the current SLAs and RPO/RTO requirements?
- What compliance/regulatory frameworks apply? (HIPAA, PCI-DSS, SOX, GDPR, FedRAMP?)

**Product & Requirements** (Greenfield)

- What problem does this product/platform solve? Who are the target users?
- What are the non-functional requirements? (Latency, throughput, availability SLAs)
- What is the expected traffic profile? (Steady, bursty, seasonal, unpredictable?)
- What is the data strategy? (Volume, velocity, variety, retention, sovereignty)
- Are there integration requirements with existing systems? (APIs, data feeds, SSO)
- What compliance frameworks apply from Day 1? (Not "we'll add later")
- What is the go-to-market timeline? (MVP date, GA date)
- Is there an existing competitive product we're replacing or competing with?

**Desired State (To-Be)** (All engagement types)

- What does "done" look like for you?
- Which workloads are highest priority? Why?
- Are there specific AWS services already in mind?
- Is there appetite for refactoring/modernizing or strictly lift-and-shift?
- (Greenfield) What does the 1-year, 3-year, and 5-year vision look like?

**Organizational Readiness** (All engagement types)

- What is the team's current cloud skills level?
- Do you have a Cloud Center of Excellence (CCoE)?
- What is the change management process?
- How are teams currently deploying software?
- (Greenfield) Do you have product management, UX design, and DevOps capabilities?

### 2.2 Mapping Business Drivers to Technical Strategy

After discovery, the architect maps business drivers to technical approach:

| Business Driver | Architect's Translation | Type | Likely Strategy |
|-----------------|-----------------------|------|------------------|
| "Reduce data center costs — lease expiring in 14 months" | Hard timeline constraint, lift-and-shift first, optimize later | Migration | **Rehost (7 R's)** with post-migration optimization wave |
| "We need to ship features faster" | Modernization play — break monoliths, adopt CI/CD | Modernization | **Refactor/Re-architect** to microservices + containers |
| "We're acquiring a company and need to integrate" | M&A integration — multi-account strategy, network connectivity | Migration | **Landing Zone** + network transit architecture |
| "Regulators require us to encrypt everything" | Compliance-driven — security-first architecture | All | **Compliance-first Landing Zone** with SCPs, KMS, CloudTrail |
| "We want AI/ML capabilities" | Data platform modernization — data lake, ML pipelines | Modernization | **Replatform** databases + build data/ML platform |
| "Disaster recovery for our on-prem systems" | Hybrid architecture — pilot light or warm standby in AWS | Migration | **DR architecture** with cross-region replication |
| "We're launching a new SaaS product" | Cloud-native from Day 1 — no legacy baggage, design for scale | **Greenfield** | Cloud-native architecture (EKS/Serverless + managed services) |
| "We need an IoT platform for our factories" | Edge + cloud, real-time ingestion, time-series analytics | **Greenfield** | IoT Core + Greengrass + Timestream + S3 Data Lake |
| "Build an AI-powered customer support system" | LLM + RAG + real-time channel integration | **Greenfield** | Bedrock + OpenSearch/pgvector + EKS + WebSocket API |
| "We want a data platform for analytics" | Data lake/lakehouse, ETL pipelines, BI integration | **Greenfield** | S3 Data Lake + Glue + Athena + Redshift + QuickSight |
| "Build a mobile backend for 10M users" | High-scale API, auth, push notifications, global CDN | **Greenfield** | API Gateway + Lambda/ECS + Cognito + DynamoDB + CloudFront |
| "We need a multi-tenant platform" | Tenant isolation, noisy neighbor prevention, billing per tenant | **Greenfield** | Account-per-tenant or namespace isolation + SaaS control plane |

### 2.3 Deliverables from Phase 0

| Deliverable | Owner | Description |
|-------------|-------|-------------|
| **Engagement Charter** | Principal Architect | Problem statement, scope, success criteria, RACI, timeline |
| **Stakeholder Map** | Enterprise Architect | Decision-makers, influencers, blockers, champions |
| **Initial Risk Register** | Principal Architect | Top 10 risks with probability, impact, mitigation |
| **High-Level Approach** | Enterprise Architect | 2-page summary: assess → mobilize → migrate/modernize (or: requirements → design → build → ship for greenfield) |
| **Engagement Type Classification** | Enterprise Architect | Greenfield vs. Migration vs. Modernization — with rationale |

---

## Part 3 — Phase 1: Assess — Understand What You Have (Migration Track)

> **AWS Framework:** This maps to the **Assess** phase of the AWS Migration Acceleration Program (MAP).
> **Note:** This part covers assessment for **migration/modernization** engagements. For **greenfield** cloud-native projects, see **Part 3B** below.

### 3.1 Migration Readiness Assessment (MRA)

The first formal assessment. AWS provides the **Migration Readiness Assessment** tool to evaluate organizational readiness across 6 dimensions:

```
┌────────────────────────────────────────────────────────────────┐
│              Migration Readiness Assessment (MRA)               │
│                                                                 │
│   BUSINESS                    PEOPLE                            │
│   ┌──────────────────┐       ┌──────────────────┐              │
│   │ Business Case    │       │ Skills & CoE     │              │
│   │ Executive Sponsor│       │ Org Structure    │              │
│   │ Success Metrics  │       │ Training Plan    │              │
│   └──────────────────┘       └──────────────────┘              │
│                                                                 │
│   GOVERNANCE                  PLATFORM                          │
│   ┌──────────────────┐       ┌──────────────────┐              │
│   │ Change Mgmt      │       │ Landing Zone     │              │
│   │ Decision-Making  │       │ Networking       │              │
│   │ Risk Framework   │       │ Security Baseline│              │
│   └──────────────────┘       └──────────────────┘              │
│                                                                 │
│   PROCESS                     OPERATIONS                        │
│   ┌──────────────────┐       ┌──────────────────┐              │
│   │ CI/CD Maturity   │       │ Monitoring       │              │
│   │ Testing Strategy │       │ Incident Mgmt    │              │
│   │ Release Cadence  │       │ Runbook Culture  │              │
│   └──────────────────┘       └──────────────────┘              │
└────────────────────────────────────────────────────────────────┘

Scoring: Each dimension scored 1-5 (1=Not Started, 5=Optimized)
Target:  All dimensions ≥ 3 before starting migration execution
```

### 3.2 Portfolio Discovery & Analysis

This is where you **catalog everything**. The architect must resist the temptation to start designing before understanding the full portfolio.

#### Tools for Discovery

| Tool | What It Does | When to Use |
|------|-------------|-------------|
| **AWS Application Discovery Service** | Agent-based or agentless — discovers servers, dependencies, performance data | On-prem workloads with no CMDB |
| **AWS Migration Hub** | Central dashboard for tracking migration across tools | Throughout the migration |
| **AWS Migration Portfolio Assessment (MPA)** | TCO analysis, right-sizing, migration strategy recommendation | Business case and wave planning |
| **CloudEndure / AWS MGN** | Continuous replication for lift-and-shift | Rehost migrations |
| **AWS DMS (Database Migration Service)** | Database migration and continuous replication | Database tier migrations |
| **AWS SCT (Schema Conversion Tool)** | Schema conversion for heterogeneous DB migrations | Oracle → PostgreSQL, SQL Server → Aurora |
| **Manual interviews + CMDB** | Application owners know things tools can't discover | Always — tools supplement, not replace |

#### The Discovery Matrix

For each application, the architect needs to fill this matrix:

| Attribute | Example | Why It Matters |
|-----------|---------|---------------|
| **Application Name** | OrderManagement-v3 | Identification |
| **Business Criticality** | Tier 1 (Revenue-generating) | Determines migration priority and risk tolerance |
| **Current Infra** | 4 VMs on VMware, Oracle 12c | Determines migration tool and strategy |
| **Dependencies** | Calls PaymentGateway API, reads from SharedOracleDB | Determines wave grouping — dependent apps move together |
| **Data Volume** | 2.3 TB database, growing 50 GB/month | Determines migration window and replication strategy |
| **Compliance** | PCI-DSS Level 1, SOX | Determines target account structure and security controls |
| **SLA** | 99.95% availability, RPO 15 min, RTO 1 hr | Determines target architecture (Multi-AZ, cross-region) |
| **Technology Stack** | Java 8, Spring Boot, Oracle 12c, Tomcat | Determines modernization feasibility |
| **Team Ownership** | Team Payments (6 engineers) | Determines who needs training, who is accountable |
| **License Costs** | Oracle EE: $47K/year per core | Opportunity for cost savings via open-source migration |
| **Technical Debt** | Java 8 EOL, unpatched Oracle, no CI/CD | Risk assessment, determines if modernization is needed |

### 3.3 The 7 R's of Migration — Decision Framework

This is the **most critical decision** the architect makes for each workload. The 7 R's are not a menu — they are a decision tree:

```
                            ┌──────────────────────────┐
                            │  Is this application     │
                            │  still needed?            │
                            └────────────┬─────────────┘
                                         │
                              ┌──── NO ──┴── YES ────┐
                              ▼                       ▼
                     ┌────────────────┐    ┌──────────────────────┐
                     │   R7: RETIRE   │    │  Can it be replaced  │
                     │   Decommission │    │  by a SaaS product?  │
                     └────────────────┘    └──────────┬───────────┘
                                                      │
                                           ┌── YES ──┴── NO ────┐
                                           ▼                     ▼
                                  ┌────────────────┐  ┌──────────────────────┐
                                  │  R6: RETAIN /  │  │  Does the business   │
                                  │  REPURCHASE    │  │  need it modernized? │
                                  │  (Buy SaaS)    │  └──────────┬───────────┘
                                  └────────────────┘             │
                                                      ┌── YES ──┴── NO ────┐
                                                      ▼                     ▼
                                            ┌──────────────┐     ┌──────────────────┐
                                            │ Worth a full  │     │  R1: REHOST      │
                                            │ rewrite?      │     │  Lift-and-Shift  │
                                            └──────┬───────┘     │  (AWS MGN)       │
                                                   │              └──────────────────┘
                                        ┌── YES ──┴── NO ──┐
                                        ▼                    ▼
                              ┌──────────────┐    ┌──────────────────┐
                              │ R5: REFACTOR │    │ Can we swap the  │
                              │ Re-architect │    │ underlying       │
                              │ (Containers, │    │ platform?        │
                              │ Serverless)  │    └──────┬───────────┘
                              └──────────────┘           │
                                              ┌── YES ──┴── NO ──┐
                                              ▼                    ▼
                                    ┌──────────────┐    ┌──────────────┐
                                    │R3: REPLATFORM│    │R2: RELOCATE  │
                                    │ Lift-Tinker- │    │ VMware Cloud │
                                    │ Shift        │    │ on AWS       │
                                    │ (e.g. RDS)   │    └──────────────┘
                                    └──────────────┘
```

#### Decision Criteria for Each R

| Strategy | When to Choose | Example | Risk | Speed |
|----------|---------------|---------|------|-------|
| **R1: Rehost** | DC exit deadline, no budget for changes, low-risk apps | EC2 lift-and-shift with AWS MGN | Low | Fast (weeks) |
| **R2: Relocate** | Heavy VMware investment, need speed | VMware Cloud on AWS | Low | Fast |
| **R3: Replatform** | Quick wins with managed services, no code changes | Move MySQL to RDS, Tomcat to Elastic Beanstalk | Low-Med | Medium |
| **R4: Repurchase** | Better SaaS exists, not core competency | On-prem CRM → Salesforce, On-prem email → O365 | Med | Medium |
| **R5: Refactor** | Strategic apps that need agility, scale, or modernization | Monolith → Microservices on EKS, Oracle → Aurora | High | Slow (months) |
| **R6: Retain** | Not ready to move, regulatory, or needs more analysis | Mainframe (plan later), apps under vendor lock-in | N/A | N/A |
| **R7: Retire** | No business value, duplicate functionality | Legacy reporting tool replaced by new analytics platform | Low | Fast |

### 3.4 The Architect's Assessment Decision — A Real Example

```
SCENARIO: Customer has 150 applications. Discovery reveals:

  ┌──────────────────────────────────────────────────────┐
  │  Portfolio Breakdown:                                 │
  │                                                       │
  │  Retire:     23 apps (15%) — no users in 6+ months   │
  │  Repurchase: 12 apps (8%)  — replaced by SaaS        │
  │  Retain:      8 apps (5%)  — mainframe, move later   │
  │  Rehost:     62 apps (41%) — lift-and-shift           │
  │  Replatform: 31 apps (21%) — swap DB/runtime only    │
  │  Refactor:   14 apps (9%)  — strategic modernization │
  │                                                       │
  │  TOTAL IN-SCOPE FOR CLOUD: 107 apps                   │
  │  TOTAL TO MIGRATE:         107 apps in 5 waves        │
  └──────────────────────────────────────────────────────┘
```

**Architect's Thinking:**

- "23 apps can be retired — that's immediate cost savings. Include it in the business case."
- "62 rehost apps should go in waves 1-3. Low risk, builds confidence, demonstrates velocity."
- "14 refactor apps go in waves 4-5. By then, the team has cloud skills and patterns established."
- "The 8 retained mainframe apps need a separate workstream — don't let them block the migration."

### 3.5 Building the Business Case

The architect **must** translate technical analysis into financial language. This is what gets executive approval.

| Cost Category | On-Premises (Annual) | AWS (Annual) | Savings |
|--------------|---------------------|-------------|---------|
| **Compute** | $1.2M (servers, VMware licenses) | $680K (Reserved Instances + Savings Plans) | 43% |
| **Database Licenses** | $470K (Oracle EE) | $95K (Aurora PostgreSQL) | 80% |
| **Storage** | $180K (SAN) | $42K (S3 + EBS gp3) | 77% |
| **Networking** | $90K (load balancers, firewalls) | $65K (ALB + NACLs + SGs) | 28% |
| **Data Center** | $350K (power, cooling, lease, staff) | $0 | 100% |
| **DR** | $400K (secondary DC) | $85K (cross-region, pilot light) | 79% |
| **Staff Reallocation** | — | +$120K (cloud training) | Investment |
| **Migration Cost** | — | $450K (one-time) | Investment |
| **TOTAL** | **$2.69M/year** | **$1.54M/year** | **43% ($1.15M/year)** |
| **3-Year TCO** | $8.07M | $5.07M | **$3.0M saved** |

### 3.6 Deliverables from Phase 1 (Assess)

| Deliverable | Owner | Audience |
|-------------|-------|----------|
| **Migration Readiness Assessment (MRA) Report** | Principal Architect | Executive Sponsor, CTO |
| **Application Portfolio Analysis** | Principal Architect + App Owners | Program Manager, Engineering Leads |
| **7 R's Classification** (per application) | Principal Architect | All stakeholders |
| **Wave Plan** (grouping apps into migration waves) | Principal Architect | Program Manager |
| **Business Case / TCO Analysis** | Principal Architect + Finance | CFO, CTO, Executive Sponsor |
| **Risk Assessment** (updated) | Principal Architect | Steering Committee |
| **High-Level Target Architecture** | Principal Architect | Engineering, Security |

---

## Part 3B — Greenfield Cloud-Native: From Zero to Production

> **When there is no existing system to assess.** The customer wants to build something entirely new on the cloud. This is a fundamentally different engagement that requires a different architect's playbook.

### 3B.1 Why Greenfield Is Harder Than Migration

```
MIGRATION:     You have a reference architecture — the existing system.
               The question is "how do we move THIS to the cloud?"
               The existing system constrains your decisions (which is helpful).

GREENFIELD:    You have a blank canvas — and that's the problem.
               The question is "what SHOULD we build?"
               Every decision has 5+ valid options. Choice paralysis is real.
               Bad decisions made here live for 5-10 years.
```

**Architect's Mindset Shift:**

| Migration Mindset | Greenfield Mindset |
|-------------------|--------------------|
| "How do we replicate this in the cloud?" | "What is the right architecture for this problem?" |
| "What is the current state?" | "What are the requirements and constraints?" |
| "Minimize risk, minimize change" | "Optimize for the future, not the past" |
| "Reuse existing patterns" | "Select the best patterns for this context" |
| "Move fast, optimize later" | "Get the foundation right — it's permanent" |
| "The team knows the application" | "The team needs to align on the domain model" |

### 3B.2 The Greenfield Lifecycle — Phases

```
┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐
│ DISCOVER │──▶│  DESIGN  │──▶│ PLATFORM │──▶│  BUILD   │──▶│  LAUNCH  │──▶│  SCALE   │
│ & DEFINE │   │          │   │  RUNWAY  │   │  ITERATE │   │          │   │          │
│          │   │ Arch     │   │          │   │          │   │ Go-Live  │   │ Optimize │
│ Require- │   │ patterns │   │ Landing  │   │ MVP →    │   │ Hyper-   │   │ FinOps   │
│ ments    │   │ PoC      │   │ Zone     │   │ Feature  │   │ care     │   │ Multi-   │
│ Domain   │   │ ADRs     │   │ CI/CD    │   │ sprints  │   │ Monitor  │   │ region   │
│ model    │   │ NFRs     │   │ Modules  │   │ Security │   │ Feedback │   │ Cost     │
│ Personas │   │ Cost est │   │ Security │   │ scanning │   │ Loop     │   │ Perf     │
└──────────┘   └──────────┘   └──────────┘   └──────────┘   └──────────┘   └──────────┘
   2-4 wks       3-6 wks       4-8 wks       8-16+ wks     1-2 days       Ongoing
```

### 3B.3 Phase G1: Discover & Define — Requirements Engineering

In greenfield, the architect is part product thinker, part technologist. You must translate business ambitions into architectural requirements.

#### The Requirements Pyramid

```
                    ┌──────────────────┐
                    │   BUSINESS       │  ← CEO/VP cares about this
                    │   REQUIREMENTS   │
                    │   "What problem  │
                    │    do we solve?" │
                    └────────┬─────────┘
                             │
                    ┌────────▼─────────┐
                    │   FUNCTIONAL     │  ← Product Owner cares about this
                    │   REQUIREMENTS   │
                    │   "What features │
                    │    does it need?"│
                    └────────┬─────────┘
                             │
              ┌──────────────▼──────────────┐
              │   NON-FUNCTIONAL REQUIREMENTS│  ← ARCHITECT cares about this
              │   (The "-ilities")           │
              │                              │
              │   Performance  Security      │
              │   Scalability  Availability  │
              │   Reliability  Compliance    │
              │   Observability  Cost        │
              │   Maintainability  Latency   │
              └──────────────────────────────┘
```

**Architect's Rule:** Business and product teams define WHAT to build. The architect defines HOW to build it — and specifically the **non-functional requirements** that determine architecture.

#### Non-Functional Requirements Template (The Architect's Checklist)

| Category | Question | Example Answer | Architecture Impact |
|----------|----------|---------------|--------------------|
| **Scale** | Peak concurrent users? | 50K concurrent, 500K DAU | Need auto-scaling, CDN, connection pooling |
| **Throughput** | Requests per second at peak? | 10K RPS API, 50K RPS reads | Need caching layer, read replicas |
| **Latency** | P99 latency target? | < 200ms API, < 50ms cache | Need regional deployment, edge caching |
| **Availability** | SLA target? | 99.95% (21.9 min downtime/month) | Multi-AZ mandatory, cross-region optional |
| **Data Volume** | How much data? Growth rate? | 500 GB now, 2 TB/year growth | S3 tiering, DB partitioning strategy |
| **Data Residency** | Where must data live? | EU data stays in eu-west-1 | Region selection, data sovereignty controls |
| **Compliance** | Regulatory frameworks? | HIPAA + SOC 2 | Encryption, audit logging, BAA with AWS |
| **Recovery** | RPO and RTO? | RPO: 1 hour, RTO: 4 hours | Cross-region backups, DR strategy |
| **Multi-Tenancy** | How are tenants isolated? | SaaS: 500 tenants, some enterprise | Silo vs. Pool isolation model |
| **Budget** | Monthly cloud spend target? | < $5K/month Year 1, < $50K Year 3 | Serverless vs. containers decision |

#### Domain-Driven Design — The Architect's Secret Weapon for Greenfield

For any non-trivial greenfield system, the architect should run a **domain modeling exercise** before drawing architecture diagrams:

```
DOMAIN-DRIVEN DESIGN (DDD) — APPLIED TO ARCHITECTURE

Step 1: EVENT STORMING (Workshop with business + engineering)
  └── Identify domain events: "OrderPlaced", "PaymentProcessed", "ShipmentDispatched"
  └── Group events into bounded contexts (future microservices)
  └── Identify aggregates, commands, and queries

Step 2: CONTEXT MAP
  └── Map relationships between bounded contexts
  └── Identify: Customer, Supplier, Shared Kernel, Anti-Corruption Layer
  └── THIS MAP BECOMES YOUR MICROSERVICE BOUNDARY MAP

Step 3: MAP TO AWS SERVICES
  ┌─────────────────────┐     ┌─────────────────────┐
  │ Order Context        │     │ Payment Context      │
  │                     │     │                     │
  │ ECS Service         │     │ Lambda + Step Fns   │
  │ Aurora PostgreSQL   │────▶│ DynamoDB            │
  │ SQS (async events)  │     │ Stripe Integration  │
  └─────────────────────┘     └─────────────────────┘
  
  ┌─────────────────────┐     ┌─────────────────────┐
  │ Notification Context │     │ Analytics Context    │
  │                     │     │                     │
  │ Lambda              │     │ Kinesis Firehose    │
  │ SES / SNS / Pinpoint│     │ S3 Data Lake        │
  │ EventBridge         │     │ Athena + QuickSight │
  └─────────────────────┘     └─────────────────────┘

ARCHITECT'S RULE: "If you can't draw the domain model,
you can't draw the architecture. And if you can't draw
the architecture, you definitely shouldn't be writing code."
```

### 3B.4 Phase G2: Architecture Design — Making the Big Decisions

This is where the Principal Architect earns their title. Every decision made here echoes for years.

#### The 10 Critical Architecture Decisions for Greenfield

| # | Decision | Options | How the Architect Decides |
|---|----------|---------|---------------------------|
| 1 | **Compute Model** | Containers (EKS/ECS) vs. Serverless (Lambda) vs. Hybrid | Scale pattern, latency needs, team skills, cost model |
| 2 | **Database Strategy** | Relational (Aurora/RDS) vs. NoSQL (DynamoDB) vs. Both | Data model complexity, query patterns, scale requirements |
| 3 | **API Strategy** | REST vs. GraphQL vs. gRPC vs. WebSocket | Client types, real-time needs, mobile/web requirements |
| 4 | **Event Architecture** | Synchronous vs. Event-driven vs. CQRS/Event Sourcing | Consistency needs, coupling tolerance, audit requirements |
| 5 | **Multi-Tenancy** | Silo (account-per-tenant) vs. Pool (shared infra) vs. Bridge | Tenant count, isolation requirements, compliance, cost |
| 6 | **Data Platform** | Transactional only vs. Analytics lake vs. Lakehouse | BI needs, ML requirements, data team maturity |
| 7 | **Frontend Strategy** | SPA (React/Vue) + API vs. SSR (Next.js) vs. Mobile-first | SEO needs, target devices, offline requirements |
| 8 | **Auth & Identity** | Cognito vs. Auth0/Okta vs. Custom | Enterprise SSO needs, B2B vs. B2C, compliance |
| 9 | **Deployment Strategy** | GitOps (ArgoCD) vs. Push (GitHub Actions → deploy) vs. Blue/Green | Team maturity, rollback speed, environment count |
| 10 | **Observability** | CloudWatch-native vs. Grafana/Prometheus vs. Datadog/New Relic | Budget, K8s presence, custom metrics needs |

#### Reference Architecture Patterns for Common Greenfield Projects

**Pattern A: SaaS Platform (Multi-Tenant B2B)**

```
┌─────────────────────────────────────────────────────────────────────┐
│                     SaaS PLATFORM ARCHITECTURE                      │
│                                                                     │
│  ┌─────────┐   ┌─────────────┐   ┌────────────────────────────────┐│
│  │CloudFront│──▶│ API Gateway │──▶│ EKS (Private)                  ││
│  │  + S3    │   │ + WAF       │   │                                ││
│  │ (React)  │   │ + Cognito   │   │  ┌──────┐ ┌──────┐ ┌────────┐ ││
│  └─────────┘   └─────────────┘   │  │Tenant│ │Billing│ │Workflow│ ││
│                                   │  │ Svc  │ │ Svc  │ │  Svc   │ ││
│                                   │  └──┬───┘ └──┬───┘ └───┬────┘ ││
│                                   └─────┼────────┼─────────┼──────┘│
│                                         │        │         │       │
│  ┌──────────────────────────────────────▼────────▼─────────▼──────┐│
│  │ Aurora PostgreSQL (RLS for tenant isolation)                    ││
│  │ + ElastiCache Redis (session + cache)                          ││
│  │ + S3 (tenant data, isolated by prefix + IAM policy)            ││
│  └────────────────────────────────────────────────────────────────┘│
│                                                                     │
│  ┌────────────────┐  ┌─────────────────┐  ┌──────────────────────┐ │
│  │ EventBridge    │  │ SQS + Lambda    │  │ CloudWatch + Grafana │ │
│  │ (domain events)│  │ (async workers) │  │ (observability)      │ │
│  └────────────────┘  └─────────────────┘  └──────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

**Pattern B: Event-Driven Serverless Platform**

```
┌─────────────────────────────────────────────────────────────────────┐
│               SERVERLESS EVENT-DRIVEN ARCHITECTURE                  │
│                                                                     │
│  ┌─────────┐   ┌──────────────┐   ┌─────────────┐                 │
│  │API GW   │──▶│ Lambda       │──▶│ DynamoDB    │                 │
│  │(REST/WS)│   │ (handlers)   │   │ (main store)│                 │
│  └─────────┘   └──────┬───────┘   └─────────────┘                 │
│                        │                                            │
│                        ▼                                            │
│               ┌────────────────┐                                    │
│               │  EventBridge   │                                    │
│               │  (event bus)   │                                    │
│               └───┬────┬───┬──┘                                    │
│                   │    │   │                                        │
│            ┌──────▼┐ ┌─▼──┐ ┌▼──────────┐                         │
│            │Lambda │ │SQS │ │Kinesis    │                          │
│            │Notif. │ │→λ  │ │Firehose   │                          │
│            │(SES)  │ │Proc│ │→ S3 Lake  │                          │
│            └───────┘ └────┘ │→ Athena   │                          │
│                              └───────────┘                          │
│                                                                     │
│  Cost: ~$50-200/month at low scale, scales linearly with usage     │
│  Best for: Startups, variable traffic, event-driven workflows      │
└─────────────────────────────────────────────────────────────────────┘
```

**Pattern C: AI/ML Platform**

```
┌─────────────────────────────────────────────────────────────────────┐
│                    AI/ML PLATFORM ARCHITECTURE                       │
│                                                                     │
│  DATA INGESTION          PROCESSING           SERVING               │
│  ┌──────────┐           ┌───────────┐        ┌───────────────┐     │
│  │ Kinesis  │──────────▶│ Glue ETL  │───────▶│ S3 Data Lake  │     │
│  │ Data     │           │ / Spark   │        │ (Bronze/Silver│     │
│  │ Streams  │           └───────────┘        │  /Gold)       │     │
│  └──────────┘                                └───────┬───────┘     │
│  ┌──────────┐                                        │             │
│  │ S3 Batch │────────────────────────────────────────▶│             │
│  │ Upload   │                                        │             │
│  └──────────┘                                        │             │
│                                                      ▼             │
│  ML TRAINING              INFERENCE          ┌───────────────┐     │
│  ┌──────────┐            ┌──────────┐        │ Bedrock       │     │
│  │SageMaker │───models──▶│SageMaker │        │ (Claude/Titan)│     │
│  │Training  │            │Endpoints │        │ + RAG         │     │
│  └──────────┘            └──────────┘        └───────┬───────┘     │
│                                                      │             │
│  ┌───────────────────────────────────────────────────▼───────────┐ │
│  │ API Gateway → Lambda/ECS → Model Inference → Response         │ │
│  │ + Bedrock Guardrails (PII, content filtering, grounding)      │ │
│  └───────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

**Pattern D: Real-Time IoT Platform**

```
┌─────────────────────────────────────────────────────────────────────┐
│                    IOT PLATFORM ARCHITECTURE                         │
│                                                                     │
│  EDGE                      CLOUD                     ANALYTICS     │
│  ┌──────────────┐         ┌───────────────┐         ┌────────────┐ │
│  │ IoT Greengrass│───MQTT─▶│ IoT Core     │────────▶│ Timestream │ │
│  │ (edge compute)│        │ + Rules Engine│         │ (time-     │ │
│  │              │         └───────┬───────┘         │  series)   │ │
│  │ - Local ML   │                 │                  └────────────┘ │
│  │ - Filtering  │                 ▼                                 │
│  │ - Aggregation│         ┌───────────────┐         ┌────────────┐ │
│  └──────────────┘         │ Kinesis Data  │────────▶│ S3 Data    │ │
│                           │ Streams       │         │ Lake       │ │
│  ┌──────────────┐         └───────┬───────┘         └────────────┘ │
│  │ Device Shadow│                 │                                 │
│  │ (state sync) │                 ▼                                 │
│  └──────────────┘         ┌───────────────┐         ┌────────────┐ │
│                           │ Lambda        │────────▶│ SNS/SES    │ │
│  Fleet: Thing Groups      │ (alerting)    │         │ (alerts)   │ │
│  Security: X.509 + mTLS   └───────────────┘         └────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

### 3B.5 Phase G2 (continued): Proof of Concept — Validate Before You Commit

**Architect's Rule:** "Never commit to a greenfield architecture without a PoC that validates your riskiest assumptions."

```
POC STRATEGY — VALIDATE THE UNKNOWNS

What to PoC (pick the TOP 3 riskiest assumptions):

├── Performance: "Can DynamoDB handle our access patterns at 10K RPS?"
│   └── Build: Load test with realistic data, measure P99 latency
│
├── Integration: "Can we integrate with the legacy ERP via API Gateway?"
│   └── Build: End-to-end data flow through the integration point
│
├── Cost: "Will Bedrock costs stay under $2K/month at our query volume?"
│   └── Build: Simulate 30 days of production traffic, measure token usage
│
├── Security: "Can we achieve HIPAA compliance with our proposed architecture?"
│   └── Build: Deploy with all security controls, run compliance scan
│
└── Team: "Can the team build and operate Kubernetes?"
    └── Build: Deploy a sample app on EKS, simulate an incident, measure MTTR

PoC Timeline: 2-4 weeks (MAX). If it takes longer, scope is too big.
PoC Output: Go/No-Go decision + validated architecture + cost projections

WHAT IS NOT A POC:
  ✗ Building the entire MVP and calling it a PoC
  ✗ Validating things that are already well-known ("can we deploy to EC2?")
  ✗ A PoC that never ends and turns into production code
```

### 3B.6 Phase G3: Platform Runway — Build the Foundation Before Features

Just like migration needs a Landing Zone, greenfield needs a **Platform Runway** — the infrastructure and tooling foundation that all feature work builds on.

```
PLATFORM RUNWAY CHECKLIST — Must be done BEFORE sprint 1 of feature development

INFRASTRUCTURE FOUNDATION:
□ AWS Organization + accounts (dev, staging, prod — minimum)
□ Landing Zone (Control Tower or custom)
□ VPC architecture deployed (networking, subnets, NAT, endpoints)
□ DNS strategy (Route53 hosted zones, domain purchased/configured)
□ SSL/TLS certificates (ACM) provisioned
□ KMS keys created for each data classification level

DEVELOPER EXPERIENCE:
□ CI/CD pipeline working end-to-end (commit → deploy to dev)
□ IaC (Terraform) repo structure defined, modules bootstrapped
□ Local development environment documented and tested
□ Feature branch → PR → review → merge → auto-deploy workflow
□ Secrets management strategy implemented (Secrets Manager / SSM)

OBSERVABILITY (Day 0, not Day 90):
□ Centralized logging (CloudWatch Logs / OpenSearch)
□ Metrics collection (CloudWatch Metrics / Prometheus)
□ Distributed tracing (X-Ray / OpenTelemetry)
□ Alerting configured (at minimum: 5xx errors, high latency, infra health)
□ Dashboard for each service (even if empty — structure matters)

SECURITY (Shift-Left):
□ SAST/SCA scanning in CI pipeline
□ Container image scanning (Trivy/ECR native)
□ IaC scanning (Checkov/tfsec)
□ IAM roles per service (IRSA for EKS, execution roles for Lambda)
□ WAF configured for all internet-facing endpoints

DATA:
□ Database provisioned with encryption, backups, multi-AZ
□ Schema migration tool integrated (Flyway, Alembic, Prisma)
□ Seed data / test data strategy defined
□ Data backup and restore tested

ARCHITECT'S RULE: "If your platform runway isn't ready,
your feature teams will build on quicksand. Every shortcut
taken here becomes a 10x cost later."
```

### 3B.7 Phase G4: Build & Iterate — MVP to Production

Greenfield projects follow an iterative build model, not the wave-based factory model of migration:

```
ITERATIVE BUILD MODEL:

┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐
│  MVP    │───▶│ Alpha   │───▶│  Beta   │───▶│   RC    │───▶│   GA    │
│         │    │         │    │         │    │         │    │         │
│ Core    │    │ Core +  │    │ Feature │    │ Perf    │    │ Prod    │
│ features│    │ integr- │    │ complete│    │ tested  │    │ ready   │
│ only    │    │ ations  │    │ + UX    │    │ Secure  │    │ Scaled  │
│         │    │         │    │ polished│    │ DR done │    │ Support │
│ 6-8 wks │    │ 4-6 wks │    │ 4-6 wks │    │ 2-4 wks │    │ Launch  │
└─────────┘    └─────────┘    └─────────┘    └─────────┘    └─────────┘

MVP SCOPE — What's In vs. What's Out:

  IN (MUST HAVE):                    OUT (DEFER):
  ├── Core user workflow (happy path)├── Admin dashboard
  ├── Authentication & authorization ├── Advanced analytics
  ├── Basic API (CRUD + core logic)  ├── Multi-region
  ├── Essential integrations         ├── Advanced search
  ├── Monitoring & alerting          ├── Notification preferences
  ├── Security baseline              ├── Batch processing
  └── CI/CD deployment               └── Performance optimization
```

#### The Architect's Role in Greenfield Build Phase

| Activity | Frequency | Greenfield-Specific Focus |
|----------|-----------|--------------------------|
| **Architecture Review** | Per feature | Ensure new features don't create architectural debt |
| **API Design Review** | Per endpoint group | Consistency, versioning, backward compatibility |
| **Data Model Review** | Per schema change | Normalization, indexing strategy, query patterns |
| **Dependency Decisions** | As needed | "Should we build this or buy/integrate?" |
| **Non-Functional Validation** | Per milestone | Load testing, security scanning, cost review |
| **Technical Debt Tracking** | Sprint-over-sprint | Maintain a debt register, schedule paydown sprints |
| **Architecture Decision Records** | Per significant decision | Document WHY, not just WHAT — future you will thank you |

### 3B.8 Greenfield Cost Estimation — The Architect's Responsibility

Unlike migration (where you compare against on-prem TCO), greenfield requires **ground-up cost modeling**:

```
COST ESTIMATION FRAMEWORK FOR GREENFIELD:

Step 1: Estimate traffic → compute costs
  ├── Users: 10K DAU → ~100 RPS average → ~500 RPS peak
  ├── Compute: 3x m6i.large (EKS) or 1M Lambda invocations/month
  └── Estimated: $150-400/month

Step 2: Estimate data → storage + DB costs
  ├── Data: 50 GB initial, growing 10 GB/month
  ├── Database: Aurora Serverless v2 (0.5-4 ACU)
  ├── Object storage: S3 Standard (~$0.023/GB)
  └── Estimated: $80-250/month

Step 3: Estimate data transfer → networking costs
  ├── Ingress: Free
  ├── Egress: ~500 GB/month × $0.09 = $45
  ├── CloudFront: Reduces egress costs by ~60%
  └── Estimated: $20-80/month

Step 4: Estimate managed services
  ├── Bedrock/AI: Tokens × price per 1K tokens
  ├── ElastiCache: cache.t3.medium (2 nodes) = $70
  ├── Secrets Manager: $0.40/secret/month
  ├── KMS: $1/key/month + API calls
  └── Estimated: $50-500/month (AI is wildly variable)

Step 5: Add 30% buffer for unknowns

TOTAL ESTIMATE: $400-1,600/month (Year 1, pre-scale)

PRESENT TO STAKEHOLDERS AS A RANGE, NEVER A SINGLE NUMBER.
Include scaling projections: "At 100K users, cost grows to $X-Y/month"
```

### 3B.9 Greenfield Anti-Patterns

| Anti-Pattern | Why It's Dangerous | What to Do Instead |
|-------------|-------------------|-------------------|
| **"Design everything upfront"** | 6-month design phase = 6 months of zero value delivery + requirements will change | Design the core, build MVP, iterate. Use ADRs for decisions |
| **"Microservices from Day 1"** | 3 engineers building 15 microservices = distributed monolith | Start with a modular monolith. Extract services when you feel the pain |
| **"Build everything custom"** | Building auth, payments, notifications from scratch | Use managed services: Cognito, Stripe, SES. Build only your differentiator |
| **"Skip the platform runway"** | Teams start coding before CI/CD, IaC, monitoring exist | Invest 4-8 weeks in platform runway. It pays back 10x |
| **"We'll add security later"** | Security retrofit is 10x more expensive than security by design | Security in sprint 0: IAM, encryption, scanning in CI/CD |
| **"Use the newest technology"** | Team has no experience with the new stack | Use boring technology for infrastructure. Innovate in your product, not your platform |
| **"We don't need docs yet"** | 6 months later, nobody knows why decisions were made | ADRs from Day 1. Architecture diagrams updated weekly |
| **"One environment is enough"** | Devs testing in production, no staging for QA | Minimum 3 environments: dev, staging, prod. Even for MVP |

### 3B.10 Greenfield vs. Migration — Deliverables Comparison

| Phase | Migration Deliverables | Greenfield Deliverables |
|-------|----------------------|------------------------|
| **Discovery** | Portfolio inventory, MRA report, 7 R's classification | Requirements doc, domain model, persona map, NFR matrix |
| **Design** | Target architecture per app, wave plan | Reference architecture, PoC results, ADRs, API contracts |
| **Foundation** | Landing Zone, shared modules, wave runbooks | Platform runway, CI/CD, IaC, observability baseline |
| **Build** | Migration factory (rehost/replatform per app) | Iterative sprints (MVP → Alpha → Beta → RC → GA) |
| **Go-Live** | Cutover plan, rollback plan per app | Launch plan, feature flags, gradual rollout |
| **Post-Launch** | Optimization wave, decommission source | Scale, optimize, iterate on features |

---

## Part 4 — Phase 2: Mobilize — Prepare the Foundation

> **AWS Framework:** This maps to the **Mobilize** phase of MAP and the **AWS Cloud Adoption Framework (CAF)**.
> **Note:** The Landing Zone, security baseline, CCoE, and shared modules described below apply equally to migration AND greenfield projects. Every enterprise cloud engagement needs this foundation.

### 4.1 Landing Zone — The Foundation of Everything

**The most important architectural decision in the entire migration.** Get this wrong, and you will be refactoring your AWS organization for years.

```
┌──────────────────────────────────────────────────────────────────┐
│                    AWS LANDING ZONE ARCHITECTURE                   │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                    AWS Organizations                          │  │
│  │  ┌──────────────┐                                            │  │
│  │  │ Management   │  SCPs, CloudTrail Org Trail, AWS Config    │  │
│  │  │ Account      │  Billing, IAM Identity Center (SSO)        │  │
│  │  └──────┬───────┘                                            │  │
│  │         │                                                     │  │
│  │  ┌──────┴──────────────────────────────────────────────────┐  │  │
│  │  │                  Organizational Units (OUs)              │  │  │
│  │  │                                                          │  │  │
│  │  │  ┌────────────┐  ┌────────────┐  ┌────────────────────┐ │  │  │
│  │  │  │ Security   │  │ Shared     │  │ Workload OUs       │ │  │  │
│  │  │  │ OU         │  │ Services   │  │                    │ │  │  │
│  │  │  │            │  │ OU         │  │  ┌──────────────┐  │ │  │  │
│  │  │  │ - Log      │  │            │  │  │ Prod OU      │  │ │  │  │
│  │  │  │   Archive  │  │ - Network  │  │  │ - App1 Acct  │  │ │  │  │
│  │  │  │ - Security │  │   Hub      │  │  │ - App2 Acct  │  │ │  │  │
│  │  │  │   Tooling  │  │ - Shared   │  │  └──────────────┘  │ │  │  │
│  │  │  │ - Audit    │  │   DNS      │  │  ┌──────────────┐  │ │  │  │
│  │  │  │            │  │ - CI/CD    │  │  │ Non-Prod OU  │  │ │  │  │
│  │  │  │            │  │   Tooling  │  │  │ - Dev Acct   │  │ │  │  │
│  │  │  │            │  │            │  │  │ - QA Acct    │  │ │  │  │
│  │  │  │            │  │            │  │  │ - Stage Acct │  │ │  │  │
│  │  │  └────────────┘  └────────────┘  │  └──────────────┘  │ │  │  │
│  │  │                                  │  ┌──────────────┐  │ │  │  │
│  │  │                                  │  │ Sandbox OU   │  │ │  │  │
│  │  │                                  │  │ - Sandbox1   │  │ │  │  │
│  │  │                                  │  │ - Sandbox2   │  │ │  │  │
│  │  │                                  │  └──────────────┘  │ │  │  │
│  │  │                                  └────────────────────┘ │  │  │
│  │  └──────────────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                    │
│  NETWORK HUB (Transit Gateway):                                    │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  On-Prem ←→ Direct Connect / VPN ←→ Transit Gateway         │  │
│  │  Transit GW ←→ Shared Services VPC                           │  │
│  │  Transit GW ←→ Workload VPCs (spoke model)                  │  │
│  │  Inspection VPC (Network Firewall) for N-S traffic           │  │
│  └──────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

#### Key Landing Zone Decisions the Architect Must Make

| Decision | Options | Architect's Consideration |
|----------|---------|--------------------------|
| **Account Strategy** | Single account vs. Multi-account | **Always multi-account** for enterprise. Blast radius isolation, billing separation, security boundaries |
| **OU Structure** | Flat vs. nested OUs | Start with Security, Shared Services, Workloads (Prod/Non-Prod), Sandbox. Don't over-nest |
| **Network Topology** | Hub-spoke (TGW) vs. Mesh vs. VPC Peering | **Transit Gateway hub-spoke** for enterprise. VPC peering doesn't scale beyond 10 connections |
| **Connectivity** | Direct Connect vs. Site-to-Site VPN | Direct Connect for production (dedicated, consistent latency). VPN as backup/failover |
| **DNS** | Route53 Private Hosted Zones vs. on-prem DNS | Hybrid DNS with Route53 Resolver Endpoints + on-prem conditional forwarding |
| **Identity** | IAM Identity Center (SSO) vs. per-account IAM users | **IAM Identity Center** (AWS SSO) + federation with existing IdP (Okta, Azure AD) |
| **Guardrails** | SCPs vs. Config Rules vs. both | **Both.** SCPs for preventive ("cannot"), Config Rules for detective ("notify if") |
| **Automation** | Control Tower vs. custom | Control Tower for most enterprises. Custom only if requirements exceed CT capabilities |
| **Logging** | Per-account vs. centralized | **Centralized** logging account. CloudTrail Org Trail + Config + VPC Flow Logs → central S3 |

### 4.2 Security Baseline — Non-Negotiable Controls

The architect defines the **security baseline** that applies to EVERY account, EVERY workload, no exceptions:

```
SECURITY BASELINE — ENFORCED VIA SCPs + CONFIG RULES + TERRAFORM MODULES

PREVENTIVE (SCPs — Cannot Bypass):
├── Cannot disable CloudTrail in any account
├── Cannot delete VPC Flow Logs
├── Cannot create IAM users with console access (SSO only)
├── Cannot launch EC2 without IMDSv2
├── Cannot create S3 buckets with public access
├── Cannot create unencrypted EBS volumes
├── Cannot use unapproved regions (restrict to eu-west-1, us-east-1, etc.)
└── Cannot modify Security OU resources from workload accounts

DETECTIVE (Config Rules — Alert + Auto-Remediate):
├── EC2 instances must be in a VPC
├── RDS instances must be encrypted
├── Security groups must not allow 0.0.0.0/0 ingress on port 22/3389
├── IAM policies must not have * resources
├── S3 buckets must have versioning enabled
├── ELB must have access logging enabled
├── Lambda functions must be in a VPC (for data-processing functions)
└── Root account must have MFA enabled

MANDATORY SERVICES (Every Account):
├── AWS CloudTrail (Org Trail → central logging)
├── AWS Config (recording all resource types)
├── Amazon GuardDuty (threat detection)
├── AWS Security Hub (aggregated findings)
├── IAM Access Analyzer (external access detection)
├── VPC Flow Logs (network monitoring)
└── AWS SSM Session Manager (no SSH bastion needed)
```

### 4.3 Cloud Center of Excellence (CCoE) — The Organizational Backbone

The architect advocates for — and often helps build — the CCoE:

```
┌──────────────────────────────────────────────────────────────────┐
│                    Cloud Center of Excellence (CCoE)              │
│                                                                    │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────────┐  │
│  │ Cloud Platform │  │ Cloud Security │  │ Cloud FinOps       │  │
│  │ Engineering    │  │ & Governance   │  │                    │  │
│  │                │  │                │  │ - Cost allocation  │  │
│  │ - Landing Zone │  │ - SCPs, Config │  │ - Budgets & alerts │  │
│  │ - IaC modules  │  │ - Compliance   │  │ - RI/SP purchasing │  │
│  │ - CI/CD Golden │  │ - Incident     │  │ - Chargeback model │  │
│  │   Pipelines    │  │   response     │  │ - Optimization     │  │
│  │ - Golden AMIs  │  │ - Audit prep   │  │   recommendations  │  │
│  └────────────────┘  └────────────────┘  └────────────────────┘  │
│                                                                    │
│  ┌────────────────┐  ┌────────────────┐                          │
│  │ Cloud Adoption │  │ Cloud Ops /    │                          │
│  │ & Enablement   │  │ SRE            │                          │
│  │                │  │                │                          │
│  │ - Training     │  │ - Monitoring   │                          │
│  │ - Certifications│ │ - Alerting     │                          │
│  │ - Patterns lib │  │ - On-call      │                          │
│  │ - Office hours │  │ - Runbooks     │                          │
│  └────────────────┘  └────────────────┘                          │
└──────────────────────────────────────────────────────────────────┘
```

### 4.4 Building Shared Terraform Modules (The "Paved Road")

The architect doesn't let every team reinvent infrastructure. They create **opinionated, shared Terraform modules** — the "paved road":

```
terraform-modules/  (internal registry or Git monorepo)
├── vpc/                    # Standard VPC: 3-AZ, public/private/data subnets, flow logs
├── eks-cluster/            # EKS with managed nodes, IRSA, ALB controller, Karpenter
├── rds-aurora/             # Aurora with encryption, backups, multi-AZ, parameter groups
├── s3-bucket/              # S3 with encryption, versioning, lifecycle, public access block
├── lambda-function/        # Lambda with VPC, KMS, X-Ray, dead-letter queue
├── api-gateway/            # API Gateway with WAF, throttling, Cognito auth
├── github-actions-oidc/    # OIDC provider for keyless GitHub Actions → AWS
├── cloudwatch-alarms/      # Standard alarm set for each service type
└── security-baseline/      # Config Rules, GuardDuty, Security Hub per account
```

**Architect's Rule:** "You CAN build your own VPC module. But if you use our paved-road module, you get security compliance for free, your PR is approved in 1 day instead of 5, and you don't need to justify your design to the security team."

### 4.5 Wave Planning — Grouping Applications for Migration

```
WAVE PLANNING PRINCIPLES:

Wave 0 (Foundation):
  └── Landing Zone, Network, Security Baseline, CI/CD, Monitoring
      Duration: 4-8 weeks

Wave 1 (Pilot — Low Risk, High Learning):
  └── 3-5 non-critical applications
  └── Purpose: Validate tooling, processes, runbooks
  └── Success criteria: Migrated, stable for 2 weeks, team confident
      Duration: 4-6 weeks

Wave 2 (Build Confidence — Medium Complexity):
  └── 10-15 applications (mostly rehost + replatform)
  └── Purpose: Build velocity, identify repeatable patterns
  └── Start parallelizing — 2-3 apps migrating concurrently
      Duration: 6-8 weeks

Wave 3-4 (Scale — High Volume):
  └── 30-50 applications per wave
  └── Purpose: Factory model — repeatable, templated migrations
  └── Multiple teams running in parallel
      Duration: 8-12 weeks per wave

Wave 5 (Complex — Modernization):
  └── Strategic applications requiring refactoring
  └── Monolith → microservices, Oracle → Aurora, etc.
  └── Longer timelines, more risk, more testing
      Duration: 12-16+ weeks

Post-Migration:
  └── Optimization wave: right-sizing, Reserved Instances, cost cleanup
      Duration: Ongoing
```

### 4.6 Deliverables from Phase 2 (Mobilize)

| Deliverable | Owner | Description |
|-------------|-------|-------------|
| **Landing Zone (deployed)** | Platform Engineering / CCoE | Multi-account org, SCPs, network, security baseline |
| **Network Architecture** | Principal Architect | Transit Gateway, Direct Connect, DNS, VPN |
| **Shared Terraform Module Library** | Platform Engineering | Paved-road modules for common infrastructure patterns |
| **CI/CD Pipeline Templates** | Platform Engineering | Golden pipelines for Terraform and application deployments |
| **Security Baseline** (deployed) | Cloud Security Team | Config Rules, GuardDuty, Security Hub, CloudTrail |
| **Wave Plan** (detailed) | Principal Architect + PMO | App-to-wave mapping with dates, dependencies, team assignments |
| **Runbook Templates** | SRE / Cloud Ops | Migration runbook, rollback runbook, cutover checklist |
| **Training Plan** (executed) | Cloud Enablement | AWS certifications, hands-on labs, team readiness |
| **CCoE Charter** | Enterprise Architect | Team structure, responsibilities, escalation paths |
| **Architecture Decision Records (ADRs)** | Principal Architect | Documented decisions with rationale and alternatives considered |

---

## Part 5 — Phase 3: Migrate & Modernize — Execute in Waves

### 5.1 The Migration Factory Model

For each application in a wave, the migration follows a standardized pipeline:

```
┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐
│ DISCOVER │──▶│  DESIGN  │──▶│  BUILD   │──▶│  TEST    │──▶│ CUTOVER  │──▶│ OPTIMIZE │
│          │   │          │   │          │   │          │   │          │   │          │
│ App deep │   │ Target   │   │ Infra    │   │ Functio- │   │ DNS/LB   │   │ Right-   │
│ dive     │   │ arch     │   │ Terraform│   │ nal, Perf│   │ switchover│  │ size     │
│ Depen-   │   │ Security │   │ Data     │   │ Security │   │ Rollback │   │ Cost     │
│ dencies  │   │ review   │   │ replicatn│   │ DR drill │   │ plan     │   │ Tags     │
│ Data map │   │ Sizing   │   │ CI/CD    │   │ UAT      │   │ Verify   │   │ Reservatn│
└──────────┘   └──────────┘   └──────────┘   └──────────┘   └──────────┘   └──────────┘
    2-3 days      3-5 days      1-2 weeks     1-2 weeks      1 day          Ongoing
```

### 5.2 The Architect's Role During Execution

During execution, the Principal Architect shifts from **designing** to **reviewing, unblocking, and ensuring consistency**:

| Activity | Frequency | Purpose |
|----------|-----------|---------|
| **Architecture Review Board** | Weekly | Review designs for each wave's applications. Ensure consistency with patterns |
| **Design Reviews** | Per application | Approve target architecture before build starts |
| **Exception Management** | As needed | Handle "this app doesn't fit any pattern" situations |
| **Risk Review** | Weekly | Review migration risks, update risk register, escalate blockers |
| **Standards Enforcement** | Continuous | Ensure teams use shared modules, follow naming conventions, tag resources |
| **Dependency Resolution** | As needed | Unblock cross-team dependencies (e.g., network changes, shared databases) |
| **Stakeholder Communication** | Weekly | Migration dashboard, burndown charts, risk flags to executives |

### 5.3 Critical Decision Points During Migration

#### Database Migration — The Hardest Part

```
DATABASE MIGRATION DECISION TREE:

Q1: Are you changing the database engine?
    ├── NO (Homogeneous: Oracle → Oracle, MySQL → MySQL)
    │   └── Use AWS DMS for continuous replication
    │       Cutover: Stop writes → DMS catches up → Switch endpoint → Resume
    │
    └── YES (Heterogeneous: Oracle → Aurora PostgreSQL)
        └── Q2: How complex is the schema?
            ├── Simple (no stored procs, standard SQL)
            │   └── AWS SCT for schema conversion + DMS for data
            │
            └── Complex (PL/SQL stored procs, Oracle-specific features)
                └── Manual conversion required (weeks-months of effort)
                    ├── Convert stored procs to PostgreSQL PL/pgSQL
                    ├── Rewrite Oracle-specific SQL (CONNECT BY, ROWNUM, etc.)
                    ├── Replace Oracle sequences with PostgreSQL sequences
                    └── Extensive regression testing required

ARCHITECT'S RULE: Never underestimate database migration.
  - Schema conversion is 20% of the effort
  - Data migration is 20% of the effort
  - Application testing against the new DB is 60% of the effort
```

#### Modernization Decision — Containers vs. Serverless

```
Q: Should this app go to containers (EKS/ECS) or serverless (Lambda)?

CONTAINERS (EKS/ECS) when:
├── Long-running processes (>15 min)
├── Need consistent latency (no cold starts)
├── Complex networking (service mesh, mTLS)
├── Team has Kubernetes expertise
├── Need to run the same code on-prem and cloud
└── Stateful workloads

SERVERLESS (Lambda + API GW + DynamoDB) when:
├── Event-driven, sporadic traffic
├── Request-response pattern (<15 min execution)
├── Want zero operational overhead
├── Highly variable traffic (0 to 10K RPS)
├── Cost-sensitive (pay only when invoked)
└── Team is small, can't afford K8s ops overhead

ECS FARGATE when:
├── Want containers but NOT Kubernetes complexity
├── Simple deployment model (task definitions)
├── Don't need Helm, service mesh, custom operators
└── Team has Docker skills but not K8s skills
```

### 5.4 Architecture Review Checklist — What the Architect Checks for Every Workload

```
ARCHITECTURE REVIEW GATE — Every workload must pass before Go-Live

RELIABILITY
□ Multi-AZ deployment (no single-AZ anything in production)
□ Health checks configured (ALB + application-level)
□ Auto-scaling policies defined and tested
□ Graceful degradation for downstream failures (circuit breakers, retries, timeouts)
□ Backup strategy defined (RPO/RTO validated)
□ DR tested (not just designed — actually tested)

SECURITY
□ No public IPs on compute (use ALB/NLB for ingress)
□ No IAM users — IRSA, OIDC, or instance profiles only
□ All storage encrypted (KMS CMK, not AWS-managed keys for regulated workloads)
□ Security groups are least-privilege (no 0.0.0.0/0)
□ Secrets in Secrets Manager or SSM Parameter Store (not env vars or config files)
□ WAF configured for internet-facing endpoints
□ Vulnerability scanning in CI/CD pipeline (container + dependency)
□ CloudTrail, Config, GuardDuty enabled (should be via landing zone baseline)

PERFORMANCE
□ Right-sized instances (not over-provisioned from on-prem sizing)
□ Caching strategy (ElastiCache, CloudFront, application-level)
□ Database connection pooling configured
□ Latency targets validated with load testing

OPERATIONS
□ Monitoring dashboard exists (CloudWatch or Grafana)
□ Alerting configured for critical metrics (CPU, memory, error rate, latency)
□ Runbook exists for common failure scenarios
□ Deployment pipeline is automated (no manual deployments)
□ Log aggregation configured (CloudWatch Logs or ELK/OpenSearch)
□ Tagging compliant (Environment, Project, Owner, CostCenter, ManagedBy)

COST
□ Right-sizing applied (not 1:1 from on-prem)
□ Storage tier appropriate (gp3 not gp2, S3 lifecycle policies)
□ Reserved capacity or Savings Plans evaluated for steady-state workloads
□ Cost allocation tags applied for chargeback
□ Budget alerts configured
```

---

## Part 6 — Phase 4: Go-Live Readiness & Cutover

### 6.1 Go-Live Readiness Assessment

**No cutover happens without a formal Go-Live Readiness Review.** The architect chairs this review with all stakeholders.

```
GO-LIVE READINESS CHECKLIST

FUNCTIONAL READINESS
□ All functional test cases passed (UAT sign-off from business owner)
□ Data migration validated (row counts, checksums, data quality)
□ Integration tests passed (all upstream/downstream systems verified)
□ Performance test completed (meets or exceeds SLA targets)
□ Security scan completed (no CRITICAL/HIGH findings unresolved)

OPERATIONAL READINESS
□ Monitoring dashboards deployed and validated
□ Alerting configured and tested (PagerDuty/OpsGenie integration)
□ Runbooks reviewed and accessible to on-call team
□ On-call rotation defined for hypercare period
□ Escalation matrix documented and distributed

ROLLBACK READINESS
□ Rollback plan documented step-by-step
□ Rollback tested and time-boxed (must complete within RTO)
□ Rollback decision criteria defined ("if X happens within Y minutes, rollback")
□ Rollback decision owner identified (usually: Principal Architect or App Owner)
□ Data rollback strategy defined (especially for DB migrations with writes)

COMMUNICATION READINESS
□ Go-Live communication sent to all stakeholders (24h before)
□ War room / bridge line set up
□ Status update cadence defined (every 30 min during cutover)
□ Customer communication prepared (if external-facing)
□ Rollback communication prepared (just in case)

SIGN-OFF
□ Application Owner: __________ Date: __________
□ Engineering Lead: __________ Date: __________
□ Security Team: __________ Date: __________
□ Operations / SRE: __________ Date: __________
□ Principal Architect: __________ Date: __________
```

### 6.2 Cutover Execution — The Architect's Orchestration

```
CUTOVER TIMELINE (Example: Database Migration with Cutover Window)

T-24h:  Final pre-cutover checks
        ├── Verify DMS replication lag < 1 second
        ├── Confirm all target infrastructure is healthy
        ├── Brief war room participants
        └── Send "Go-Live Tomorrow" communication

T-4h:   Pre-cutover
        ├── Scale up target environment (handle potential spike)
        ├── Warm connection pools
        └── Final monitoring check

T-0:    CUTOVER START (typically Friday 10 PM or Saturday morning)
        ├── Step 1: Enable maintenance page (or read-only mode)
        ├── Step 2: Stop application writes to source DB
        ├── Step 3: Wait for DMS replication to reach zero lag
        ├── Step 4: Validate data consistency (checksums, row counts)
        ├── Step 5: Update application config to point to new DB/endpoints
        ├── Step 6: Deploy application to new environment
        ├── Step 7: Smoke tests (critical path validation)
        ├── Step 8: Switch DNS / Load Balancer to new environment
        ├── Step 9: Monitor for 30 minutes (error rates, latency, logs)
        └── Step 10: Confirm GO or ROLLBACK decision

T+30m:  GO / NO-GO DECISION POINT
        ├── GO: Remove maintenance page, notify stakeholders
        └── NO-GO: Execute rollback plan, root cause analysis

T+1h:   Post-cutover monitoring (elevated alerting thresholds)

T+24h:  Day 1 business hours validation
        ├── Business users validate key workflows
        ├── Performance metrics baseline comparison
        └── Any issues escalated to war room
```

### 6.3 Rollback Strategy — The Safety Net

**Architect's Rule:** "Hope for the best, plan for the worst. A migration without a tested rollback plan is a career-ending event."

| Rollback Scenario | Strategy | Time to Rollback |
|-------------------|----------|------------------|
| **Rehost (EC2)** | Keep source servers running (powered off) for 7 days | < 30 min (re-point DNS/LB) |
| **Replatform (RDS)** | DMS reverse replication to source DB | 1-4 hours |
| **Refactor (new app)** | Blue-green: old environment stays warm for 7 days | < 5 min (DNS switch) |
| **Database (homogeneous)** | DMS reverse replication | 1-2 hours |
| **Database (heterogeneous)** | Keep source DB read-only, reverse ETL if needed | 2-8 hours (risky) |

---

## Part 7 — Phase 5: Hypercare & Stabilization

### 7.1 Hypercare Period — The First 2-4 Weeks Post Go-Live

```
HYPERCARE OPERATING MODEL

Week 1 (Critical — War Room Mode):
├── 24/7 monitoring with dedicated on-call rotation
├── Architect available on-call for escalations
├── Daily standup at 9:00 AM (30 min) — review overnight issues
├── Hourly monitoring of error rates, latency, infrastructure health
├── Any P1/P2 incident: war room activation within 15 minutes
├── Daily executive status update (green/amber/red)
└── No other changes allowed (change freeze on migrated workload)

Week 2 (Elevated — Reduced Intensity):
├── 12/7 monitoring (business hours + evening)
├── Daily standup continues
├── Begin performance baseline comparison (on-prem vs. cloud)
├── Address accumulated non-critical issues
├── Start right-sizing analysis (actual usage data now available)
└── Change freeze relaxed for non-critical changes

Week 3-4 (Stabilization):
├── Standard monitoring + alerting (normal on-call rotation)
├── Weekly review instead of daily
├── Performance optimization recommendations
├── Cost optimization (right-sizing, reserved instances)
├── Knowledge transfer to BAU operations team
└── Hypercare exit criteria validation
```

### 7.2 Hypercare Exit Criteria

| Criteria | Threshold | Validated By |
|----------|-----------|--------------|
| **Availability** | ≥ SLA target (e.g., 99.95%) for 14 consecutive days | Monitoring data |
| **Error Rate** | ≤ pre-migration baseline | APM / CloudWatch |
| **Latency** | ≤ 110% of pre-migration baseline (10% margin for network path change) | Load balancer metrics |
| **No P1 Incidents** | Zero P1 incidents in last 7 days | Incident management system |
| **No P2 Incidents** | ≤ 2 P2 incidents in last 7 days, all resolved | Incident management system |
| **Runbooks Validated** | All critical runbooks executed at least once | Operations team sign-off |
| **Knowledge Transfer** | BAU team can operate without migration team support | BAU team sign-off |
| **Rollback Decommissioned** | Source environment powered down (after exit approval) | Infrastructure team |

### 7.3 Post-Migration Optimization — The Work Continues

```
OPTIMIZATION ACTIVITIES (Ongoing After Hypercare):

COST OPTIMIZATION:
├── Right-size instances based on 2-4 weeks of actual CloudWatch data
│   (Most on-prem servers are 70-80% over-provisioned)
├── Purchase Savings Plans or Reserved Instances for steady-state workloads
├── Implement S3 Intelligent-Tiering or lifecycle policies
├── Review and eliminate unused EBS volumes, EIPs, idle load balancers
├── Enable gp3 for all EBS volumes (20% cheaper than gp2, better performance)
├── Evaluate Graviton instances for compatible workloads (20% cheaper)
└── Set up AWS Cost Explorer reports and budgets

PERFORMANCE OPTIMIZATION:
├── Enable CloudFront for static content (reduce origin load)
├── Implement ElastiCache for frequently-accessed data
├── Review database query performance (Performance Insights)
├── Evaluate Aurora Serverless v2 for variable workloads
└── Implement connection pooling (RDS Proxy or PgBouncer)

OPERATIONAL OPTIMIZATION:
├── Automate patching with AWS Systems Manager Patch Manager
├── Implement AWS Backup for centralized backup management
├── Set up AWS Health Dashboard integration
├── Automate compliance checks with AWS Config conformance packs
└── Implement Infrastructure as Code for any manually-created resources
```

---

## Part 8 — Phase 6: Project Closure & Transition to BAU

### 8.1 Formal Project Closure

```
PROJECT CLOSURE CHECKLIST

DELIVERABLE VALIDATION:
□ All applications migrated per scope (or formally de-scoped with sign-off)
□ All Terraform code in version control (Git) with documentation
□ Architecture documentation up-to-date (diagrams, ADRs, network maps)
□ Runbooks complete and validated by BAU team
□ Monitoring and alerting fully operational

SOURCE ENVIRONMENT DECOMMISSION:
□ Source servers powered off for 30 days (safety net)
□ Data retention requirements verified before deletion
□ License release/cancellation initiated (Oracle, VMware, Windows)
□ Data center contract termination notice sent (if applicable)
□ Final backup of source environment stored in S3 Glacier (if required)

KNOWLEDGE TRANSFER:
□ Operations playbook handed to BAU team
□ Architecture walk-through completed (recorded)
□ On-call handover completed
□ Escalation matrix updated with BAU contacts
□ CCoE patterns library updated with lessons learned

FINANCIAL CLOSURE:
□ Actual vs. projected cost comparison documented
□ Savings realization report presented to executive sponsor
□ FinOps handover (tagging, budgets, Reserved Instance management)
□ Vendor contract changes documented (new AWS, cancelled legacy)

RETROSPECTIVE:
□ Project retrospective conducted (what went well, what didn't)
□ Lessons learned document published
□ Recommendations for future waves/projects documented
□ Team recognition and celebration
```

### 8.2 The Closure Report — What the Architect Presents to Leadership

```
MIGRATION CLOSURE EXECUTIVE SUMMARY

PROJECT: Enterprise Cloud Migration Program — Phase 1
DURATION: 9 months (Oct 2024 — Jun 2025)
SPONSOR: [CTO Name]

SCOPE DELIVERED:
  ├── 107 applications migrated to AWS (of 107 planned — 100%)
  ├── 23 applications retired (immediate cost savings)
  ├── 12 applications replaced with SaaS
  ├── 3 data centers consolidated to 1 (2 fully decommissioned)
  └── 8 applications retained on-prem (mainframe — Phase 2)

FINANCIAL OUTCOME:
  ├── Projected annual savings: $1.15M/year
  ├── Actual annual run-rate savings: $1.32M/year (exceeded by 15%)
  ├── Migration investment: $420K (under $450K budget)
  ├── Payback period: 3.8 months
  └── 3-year projected savings: $3.54M

OPERATIONAL METRICS:
  ├── Average availability post-migration: 99.97% (target: 99.95%)
  ├── P1 incidents during migration: 2 (both resolved within SLA)
  ├── Zero data loss events
  ├── Zero unplanned rollbacks
  └── Mean cutover time: 2.3 hours (target: 4 hours)

KEY ACHIEVEMENTS:
  ├── Eliminated Oracle licensing: $470K/year saved
  ├── CCoE established with 8 certified team members
  ├── 100% Infrastructure as Code — zero manual provisioning
  ├── CI/CD pipelines for all migrated applications
  └── Security posture improved: GuardDuty + Security Hub baseline

RECOMMENDATIONS FOR PHASE 2:
  ├── Mainframe modernization assessment (8 retained apps)
  ├── Kubernetes adoption for 14 refactored applications
  ├── Data lake implementation for analytics workloads
  └── Multi-region DR implementation for Tier-1 applications
```

### 8.3 Transition to BAU — The Architect Steps Back

```
BAU OPERATING MODEL (Post-Migration)

                    ┌────────────────────────────┐
                    │       CCoE (Ongoing)       │
                    │                            │
                    │  Platform Engineering       │
                    │  ├── Module maintenance     │
                    │  ├── New service onboarding │
                    │  └── Landing Zone updates   │
                    │                            │
                    │  Cloud Security             │
                    │  ├── SCP updates            │
                    │  ├── Compliance audits      │
                    │  └── Incident response      │
                    │                            │
                    │  FinOps                     │
                    │  ├── Monthly cost reviews   │
                    │  ├── RI/SP management       │
                    │  └── Chargeback reporting   │
                    └──────────────┬─────────────┘
                                   │
                    ┌──────────────▼─────────────┐
                    │    Application Teams        │
                    │    (Self-Service Model)     │
                    │                            │
                    │  Use CCoE modules           │
                    │  Deploy via CI/CD pipelines  │
                    │  Own their workloads         │
                    │  Follow guardrails           │
                    │  Request exceptions via ADR  │
                    └────────────────────────────┘
```

---

## Part 9 — AWS Frameworks & References

### 9.1 Key AWS Frameworks an Enterprise Architect Must Know

| Framework | Purpose | When to Use |
|-----------|---------|-------------|
| **AWS Cloud Adoption Framework (CAF)** | Organizational readiness across 6 perspectives (Business, People, Governance, Platform, Security, Operations) | Phase 0-1: Initial assessment |
| **AWS Migration Acceleration Program (MAP)** | Structured 3-phase migration methodology (Assess → Mobilize → Migrate) | Entire migration lifecycle |
| **AWS Well-Architected Framework** | 6-pillar review of individual workloads | Phase 3-4: Design reviews before go-live |
| **AWS Prescriptive Guidance** | Detailed patterns for specific migration scenarios | Phase 3: Implementation patterns |
| **AWS Migration Readiness Assessment (MRA)** | Organizational readiness scoring tool | Phase 1: Assessment |
| **AWS Migration Portfolio Assessment (MPA)** | Portfolio analysis and business case tool | Phase 1: Assessment |

### 9.2 AWS Well-Architected Framework — The 6 Pillars

Every workload review should assess against all 6 pillars:

```
┌──────────────────────────────────────────────────────────────────┐
│                AWS WELL-ARCHITECTED FRAMEWORK                     │
│                                                                    │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────────┐  │
│  │ 1. OPERATIONAL │  │ 2. SECURITY    │  │ 3. RELIABILITY     │  │
│  │    EXCELLENCE   │  │                │  │                    │  │
│  │                │  │ - IAM           │  │ - Multi-AZ         │  │
│  │ - IaC          │  │ - Encryption    │  │ - Auto-scaling     │  │
│  │ - CI/CD        │  │ - Network       │  │ - Backup/DR        │  │
│  │ - Monitoring   │  │ - Detection     │  │ - Fault isolation  │  │
│  │ - Runbooks     │  │ - Compliance    │  │ - Graceful degrade │  │
│  │ - Automation   │  │ - Incident resp │  │ - Chaos engineering│  │
│  └────────────────┘  └────────────────┘  └────────────────────┘  │
│                                                                    │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────────┐  │
│  │ 4. PERFORMANCE │  │ 5. COST        │  │ 6. SUSTAINABILITY  │  │
│  │    EFFICIENCY   │  │    OPTIMIZATION│  │                    │  │
│  │                │  │                │  │ - Right-sizing     │  │
│  │ - Right type   │  │ - Right-sizing │  │ - Managed services │  │
│  │ - Caching      │  │ - Savings Plans│  │ - Graviton (ARM)   │  │
│  │ - CDN          │  │ - Spot/Graviton│  │ - Serverless       │  │
│  │ - DB optimize  │  │ - Storage tiers│  │ - Region selection │  │
│  │ - Load testing │  │ - FinOps       │  │ - Code efficiency  │  │
│  └────────────────┘  └────────────────┘  └────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

### 9.3 Key AWS Services by Migration Phase

| Phase | Key AWS Services |
|-------|-----------------|
| **Assess** | Application Discovery Service, Migration Hub, Migration Evaluator (TSO Logic) |
| **Mobilize** | Control Tower, Organizations, IAM Identity Center, Transit Gateway, Direct Connect |
| **Migrate (Rehost)** | Application Migration Service (MGN), CloudEndure |
| **Migrate (Replatform)** | DMS, SCT, RDS, ElastiCache, Elastic Beanstalk |
| **Migrate (Refactor)** | EKS, ECS, Lambda, API Gateway, Aurora, DynamoDB |
| **Optimize** | Compute Optimizer, Cost Explorer, Trusted Advisor, Savings Plans |
| **Operate** | CloudWatch, Systems Manager, Config, GuardDuty, Security Hub, AWS Backup |

---

## Part 10 — Anti-Patterns & Hard Lessons

### 10.1 Migration Anti-Patterns the Architect Must Prevent

| Anti-Pattern | Why It's Dangerous | What to Do Instead |
|-------------|-------------------|-------------------|
| **"Lift-and-shift everything, optimize later"** | "Later" never comes. You end up running overprovisioned EC2 at 10% utilization for years | Rehost + immediate right-sizing. Schedule optimization wave |
| **"Let's rewrite it all in microservices"** | 3-year rewrite projects fail 70% of the time. Business can't wait | Strangler fig pattern — incrementally extract services |
| **"Each team designs their own VPC"** | 200 VPCs with overlapping CIDRs, no connectivity, inconsistent security | Shared VPC patterns or centralized network architecture |
| **"We don't need a landing zone"** | 6 months in, you discover you need consolidated logging, SCPs, and multi-account — and refactoring is painful | Always build the foundation first (even if it takes 6-8 weeks) |
| **"Security will review after we migrate"** | Security finds 200 findings, blocks go-live, delays project by months | Security embedded from Day 1. Shared modules enforce security |
| **"We'll do DR later"** | First outage happens before DR is built. Executives ask why | DR architecture defined in Phase 2, tested before go-live |
| **"1:1 instance mapping from on-prem"** | On-prem servers are 70-80% overprovisioned. 1:1 wastes money | Right-size based on actual utilization data (CloudWatch, Application Discovery) |
| **"One big account for everything"** | One compromised credential = everything compromised. No blast radius | Multi-account from Day 1. Account-per-workload or account-per-environment |
| **"Skip the pilot wave"** | First wave with 50 apps = 50 unknown risks simultaneously | Always start with 3-5 low-risk apps. Validate tooling, processes, runbooks |
| **"The architect designs, someone else builds"** | Ivory tower architecture = designs that don't work in reality | Architect reviews PRs, joins design sessions, stays hands-on |

### 10.2 Questions an Enterprise Architect Should Ask at Every Stage

**During Assessment:**

- "What happens to this application if we DON'T migrate it?"
- "Who will be accountable for this application in the cloud?"
- "What is the actual utilization of these servers — not what was spec'd, but what's running?"

**During Design:**

- "What is the blast radius if this component fails?"
- "Can we recover from a complete region failure?"
- "Is this the simplest design that meets the requirements?"
- "What would we need to change if traffic doubles tomorrow?"

**During Migration:**

- "What is our rollback plan, and have we tested it?"
- "What is the maximum tolerable downtime for this cutover?"
- "Who is the single decision-maker for go/no-go?"

**During Hypercare:**

- "Is this issue a migration-related regression or a pre-existing problem?"
- "Are our monitoring baselines accurate, or are we comparing against incomplete on-prem data?"
- "At what point do we declare hypercare complete and move to BAU?"

**During Closure:**

- "Did we achieve the business outcome we committed to?"
- "What would we do differently if we started over?"
- "What institutional knowledge needs to be documented before the team disperses?"

### 10.3 The Architect's Career Rule

> **"A Principal Architect's reputation is built on three things: decisions that age well, risks they saw coming, and the disasters they prevented — not the ones they responded to."**

The best architects are not the ones who design the most complex systems. They are the ones who:

1. **Make complexity invisible** — Teams don't feel the complexity because the shared modules and guardrails handle it
2. **Say "no" at the right time** — Prevent scope creep, technology fads, and premature optimization
3. **Build trust through transparency** — Surface risks early, communicate trade-offs honestly, never hide bad news
4. **Leave the organization better than they found it** — CCoE, modules, patterns, documentation, trained team
5. **Make themselves replaceable** — If the project can't function without you, you failed as an architect

---

## Summary — The Complete Journey at a Glance

### Migration / Modernization Track

```
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                         │
│  PHASE 0          PHASE 1         PHASE 2         PHASE 3              │
│  Pre-Engagement   Assess          Mobilize        Migrate/Modernize    │
│  ─────────────    ──────          ────────        ─────────────────    │
│  2-4 weeks        4-8 weeks       6-10 weeks      12-40+ weeks         │
│                                                                         │
│  ┌──────┐        ┌──────┐        ┌──────┐        ┌──────┐             │
│  │Listen│───────▶│Assess│───────▶│Build │───────▶│Exec  │             │
│  │Learn │        │Plan  │        │Found-│        │Waves │             │
│  │Align │        │Case  │        │ation │        │Review│             │
│  └──────┘        └──────┘        └──────┘        └──┬───┘             │
│                                                      │                  │
│  PHASE 4          PHASE 5         PHASE 6           │                  │
│  Go-Live          Hypercare       Closure            │                  │
│  ───────          ─────────       ───────            │                  │
│  1-2 days/app     2-4 weeks       2-4 weeks         │                  │
│                                                      │                  │
│  ┌──────┐        ┌──────┐        ┌──────┐           │                  │
│  │Cut-  │◀───────│Stabi-│◀───────│Close │◀──────────┘                  │
│  │over  │        │lize  │        │Hand- │                              │
│  │Verify│        │Optim │        │over  │                              │
│  └──────┘        └──────┘        └──────┘                              │
│                                                                         │
│  ARCHITECT'S ROLE:                                                      │
│  Strategy ──▶ Design ──▶ Review ──▶ Orchestrate ──▶ Validate ──▶ Exit │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Greenfield Cloud-Native Track

```
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                         │
│  PHASE G0         PHASE G1        PHASE G2        PHASE G3             │
│  Discovery &      Architecture    Platform        Build &              │
│  Requirements     Design & PoC    Runway          Iterate              │
│  ────────────     ────────────    ────────        ───────              │
│  2-4 weeks        3-6 weeks       4-8 weeks       8-16+ weeks          │
│                                                                         │
│  ┌──────┐        ┌──────┐        ┌──────┐        ┌──────┐             │
│  │Define│───────▶│Design│───────▶│Build │───────▶│Build │             │
│  │NFRs  │        │Arch  │        │Found-│        │MVP → │             │
│  │Domain│        │PoC   │        │ation │        │Beta →│             │
│  │Model │        │ADRs  │        │CI/CD │        │GA    │             │
│  └──────┘        └──────┘        └──────┘        └──┬───┘             │
│                                                      │                  │
│  PHASE G4         PHASE G5        PHASE G6          │                  │
│  Go-Live &        Hypercare       Scale &            │                  │
│  Launch           & Stabilize     Optimize           │                  │
│  ─────────        ────────────    ────────           │                  │
│  1-2 weeks        2-4 weeks       Ongoing            │                  │
│                                                      │                  │
│  ┌──────┐        ┌──────┐        ┌──────┐           │                  │
│  │Launch│◀───────│Stabi-│◀───────│Scale │◀──────────┘                  │
│  │Grad- │        │lize  │        │Multi-│                              │
│  │ual   │        │Perf  │        │region│                              │
│  │Roll- │        │tune  │        │FinOps│                              │
│  │out   │        │      │        │Iter- │                              │
│  └──────┘        └──────┘        │ate   │                              │
│                                   └──────┘                              │
│                                                                         │
│  ARCHITECT'S ROLE:                                                      │
│  Envision ──▶ Design ──▶ Establish ──▶ Guide ──▶ Launch ──▶ Evolve   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Both Tracks Share

```
┌─────────────────────────────────────────────────────────────────────────┐
│  SHARED ACROSS BOTH TRACKS (regardless of Migration or Greenfield):    │
│                                                                         │
│  ✅ Landing Zone & Multi-Account Strategy                              │
│  ✅ Security Baseline (SCPs, Config Rules, GuardDuty, Security Hub)    │
│  ✅ CCoE (Cloud Center of Excellence)                                  │
│  ✅ Shared Terraform Modules ("Paved Road")                           │
│  ✅ CI/CD Golden Pipelines                                             │
│  ✅ Observability Stack                                                │
│  ✅ FinOps & Cost Governance                                           │
│  ✅ Architecture Decision Records (ADRs)                               │
│  ✅ Go-Live Readiness Review                                           │
│  ✅ Hypercare Period                                                   │
│  ✅ Project Closure & BAU Transition                                   │
│                                                                         │
│  The FOUNDATION is the same. The JOURNEY to get there differs.         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

**Built with precision by Pushparaj Naik** | Principal Cloud Architect Playbook
