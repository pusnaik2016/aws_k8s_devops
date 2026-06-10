# Azure Enterprise / Principal Cloud Architect Playbook

## Migration, Modernization & Greenfield — With AWS Comparisons

> **Author:** Pushparaj Naik
> **Scope:** Microsoft Azure — End-to-End Lifecycle
> **Audience:** Enterprise Architects, Principal Cloud Architects, Multi-Cloud Strategists

---

## Table of Contents

- [Part 1 — Azure vs AWS: Philosophical Differences](#part-1--azure-vs-aws-philosophical-differences)
- [Part 2 — Azure Service Mapping (vs AWS)](#part-2--azure-service-mapping-vs-aws)
- [Part 3 — Azure Organization & Landing Zone](#part-3--azure-organization--landing-zone)
- [Part 4 — Azure Migration: Assess → Migrate → Modernize → Optimize](#part-4--azure-migration-assess--migrate--modernize--optimize)
- [Part 5 — Azure Modernization & Cloud-Native Patterns](#part-5--azure-modernization--cloud-native-patterns)
- [Part 6 — Azure DevOps & CI/CD Architecture](#part-6--azure-devops--cicd-architecture)
- [Part 7 — Azure Security, Compliance & Governance](#part-7--azure-security-compliance--governance)
- [Part 8 — Azure Data & AI Platform Architecture](#part-8--azure-data--ai-platform-architecture)
- [Part 9 — Azure Networking Deep Dive](#part-9--azure-networking-deep-dive)
- [Part 10 — Azure Cost Management & FinOps](#part-10--azure-cost-management--finops)
- [Part 11 — Azure Interview Q&A: 50 Questions](#part-11--azure-interview-qa-50-questions)

---

## Part 1 — Azure vs AWS: Philosophical Differences

### 1.1 Core Philosophy Comparison

| Aspect | AWS | Azure |
|--------|-----|-------|
| **Design Philosophy** | "Cloud-native first, broadest service catalog" | "Enterprise-first, hybrid by design, integrated with Microsoft ecosystem" |
| **Identity Model** | IAM (per-account, standalone) | **Azure AD (Entra ID)** — same identity for Office 365, Azure, and on-prem AD |
| **Enterprise Appeal** | Cloud-native companies, startups, mature cloud users | **Enterprises already using Microsoft** (AD, Office 365, SQL Server, .NET) |
| **Hybrid Story** | Outposts (limited), EKS Anywhere | **Azure Arc** (manage any infra from Azure), Azure Stack HCI/Hub |
| **Developer Ecosystem** | Polyglot (Python, Node, Go, Java equally supported) | **.NET/C# first-class**, but supports all (VS Code, GitHub integration) |
| **AI/ML** | Bedrock (managed LLMs), SageMaker | **Azure OpenAI Service** (exclusive GPT-4, GPT-4o access) |
| **Licensing** | Separate from enterprise software licensing | **Azure Hybrid Benefit** (reuse on-prem Windows/SQL licenses — 40-80% savings) |
| **Compliance** | 148 compliance certifications | **100+ compliance offerings** + deep government cloud (Azure Government, DoD) |
| **Marketplace** | Largest cloud marketplace | Strong enterprise ISV presence (SAP, Oracle, Citrix native integration) |

### 1.2 When to Choose Azure Over AWS — The Architect's Decision

| Scenario | Why Azure Wins | AWS Comparison |
|----------|---------------|---------------|
| **Microsoft shop** (AD, O365, Teams, SharePoint) | Single identity (Entra ID), SSO across everything, Intune MDM | AWS has no equivalent Microsoft integration |
| **Windows Server / SQL Server workloads** | **Azure Hybrid Benefit** saves 40-80% by reusing on-prem licenses | AWS charges full license cost (BYOL is more complex) |
| **.NET application portfolio** | Azure App Service, Functions, and Visual Studio integration are best-in-class for .NET | AWS supports .NET but Azure is the native home |
| **AI with GPT/OpenAI models** | **Azure OpenAI Service** (exclusive enterprise access to GPT-4, GPT-4o, DALL-E) | AWS Bedrock has Claude, Titan, Llama — but no GPT-4 |
| **SAP workloads** | SAP on Azure is a certified, co-engineered partnership | SAP on AWS works but Azure has deeper SAP partnership |
| **Hybrid / on-premises integration** | **Azure Arc** manages on-prem, multi-cloud, and edge from one pane | AWS Outposts is AWS-only, doesn't manage other clouds |
| **Government / regulated industries** | Azure Government (separate regions), DoD IL5/IL6, FedRAMP High | AWS GovCloud exists but Azure Government is more adopted in US federal |
| **Enterprise Java modernization** | Azure Spring Apps (managed Spring Boot) + Azure Kubernetes Service | AWS has no managed Spring Boot service |

### 1.3 When AWS Still Wins Over Azure

| Scenario | Why AWS Wins | Azure Gap |
|----------|-------------|-----------|
| **Cloud-native innovation** | AWS innovates faster, more services, broader edge cases | Azure is more conservative, enterprise-focused |
| **Kubernetes maturity** | EKS is strong (but GKE is best) | AKS is good but GKE and EKS have more ecosystem tooling |
| **Serverless maturity** | Lambda + API Gateway + DynamoDB + Step Functions = best serverless stack | Azure Functions + Durable Functions are solid but less polished |
| **IoT / Edge** | IoT Core + Greengrass is the most complete edge stack | Azure IoT Hub + IoT Edge is close but Greengrass has more edge ML |
| **Data Lake / Analytics** | S3 + Glue + Athena + EMR is mature | Azure Data Lake Gen2 + Synapse is powerful but more complex |
| **Global CDN reach** | CloudFront with 450+ PoPs | Azure CDN / Front Door with ~120 PoPs |

---

## Part 2 — Azure Service Mapping (vs AWS)

### 2.1 Compute

| Category | AWS | Azure | Key Difference |
|----------|-----|-------|----------------|
| **Virtual Machines** | EC2 | **Azure Virtual Machines** | Azure offers Hybrid Benefit (reuse Windows/SQL licenses — huge savings) |
| **Managed Kubernetes** | EKS | **AKS (Azure Kubernetes Service)** | AKS control plane is FREE (AWS EKS charges $0.10/hr/cluster) |
| **Serverless Containers** | ECS Fargate / App Runner | **Azure Container Apps** | Container Apps = Dapr + KEDA integrated, event-driven by default |
| **Serverless Functions** | Lambda | **Azure Functions** | Azure Functions supports Durable Functions (stateful orchestrations) |
| **PaaS (Web Apps)** | Elastic Beanstalk | **Azure App Service** | App Service is far superior to Beanstalk — deployment slots, auto-scale, custom domains |
| **Batch Processing** | AWS Batch | **Azure Batch** | Similar capabilities |
| **VM Scale Sets** | Auto Scaling Groups | **VM Scale Sets (VMSS)** | Similar — VMSS supports Flexible orchestration mode |
| **Spot/Low-Priority** | Spot Instances | **Spot VMs** | Similar pricing model, Azure also has Low-Priority VMs for Batch |
| **Dedicated Hosts** | Dedicated Hosts | **Azure Dedicated Host** | Both offer single-tenant physical servers |

### 2.2 Containers & Kubernetes

| Category | AWS | Azure | Key Difference |
|----------|-----|-------|----------------|
| **Managed K8s** | EKS | **AKS** | AKS control plane is FREE. EKS charges $0.10/hr ($73/month) |
| **Container Registry** | ECR | **Azure Container Registry (ACR)** | ACR supports geo-replication, content trust, Helm charts |
| **Serverless Containers** | App Runner / Fargate | **Azure Container Apps** | Container Apps has built-in Dapr, KEDA, traffic splitting |
| **Container Instances** | No direct equivalent | **Azure Container Instances (ACI)** | Run individual containers without clusters — great for burst/batch |
| **Service Mesh** | App Mesh / Istio on EKS | **Istio on AKS (managed add-on)** | AKS has managed Istio as first-class add-on |
| **Multi-Cloud K8s** | No equivalent | **Azure Arc-enabled Kubernetes** | Manage any K8s cluster from Azure (EKS, GKE, on-prem) |
| **Spring Boot PaaS** | No direct equivalent | **Azure Spring Apps** | Managed VMware Tanzu — Spring Boot apps with zero K8s ops |

### 2.3 Database & Storage

| Category | AWS | Azure | Key Difference |
|----------|-----|-------|----------------|
| **Object Storage** | S3 | **Azure Blob Storage** | Blob supports Hot/Cool/Cold/Archive tiers + immutable storage |
| **Block Storage** | EBS | **Azure Managed Disks** | Ultra Disk for high-IOPS, Premium SSD v2 for flexibility |
| **File Storage** | EFS | **Azure Files** | Azure Files supports SMB (Windows-native) + NFS |
| **Managed SQL Server** | RDS SQL Server | **Azure SQL Database / SQL Managed Instance** | Azure SQL is the native home for SQL Server (best compatibility + Hybrid Benefit) |
| **Managed PostgreSQL** | RDS / Aurora PostgreSQL | **Azure Database for PostgreSQL Flexible Server** | Flexible Server supports Citus (horizontal scale) |
| **Managed MySQL** | RDS / Aurora MySQL | **Azure Database for MySQL Flexible Server** | Similar, Azure has built-in HA |
| **NoSQL (Document)** | DynamoDB | **Cosmos DB** | Cosmos DB supports 5 APIs (SQL, MongoDB, Cassandra, Gremlin, Table) |
| **Data Warehouse** | Redshift | **Azure Synapse Analytics** | Synapse = data warehouse + data lake + Spark + pipelines in one |
| **In-Memory Cache** | ElastiCache | **Azure Cache for Redis** | Similar — Azure also offers Redis Enterprise tier |
| **Distributed Database** | Aurora Global Database | **Cosmos DB (multi-region writes)** | Cosmos DB supports 5 consistency levels (from Strong to Eventual) |

### 2.4 Networking

| Category | AWS | Azure | Key Difference |
|----------|-----|-------|----------------|
| **VPC** | VPC (Regional) | **VNet (Regional)** | Both are regional. Azure supports VNet peering (global) |
| **Load Balancer (L7)** | ALB | **Application Gateway** | App Gateway includes WAF natively |
| **Global Load Balancer** | CloudFront + Route53 | **Azure Front Door** | Front Door = global LB + CDN + WAF in one service |
| **Load Balancer (L4)** | NLB | **Azure Load Balancer** | Similar |
| **CDN** | CloudFront | **Azure CDN / Front Door** | Front Door combines CDN + global LB + WAF |
| **DNS** | Route 53 | **Azure DNS** | Azure DNS has Private DNS Zones (like Route53 PHZ) |
| **VPN** | Site-to-Site VPN | **VPN Gateway** | Similar — S2S, P2S, ExpressRoute |
| **Dedicated Connectivity** | Direct Connect | **ExpressRoute** | ExpressRoute supports Global Reach (connect on-prem sites through Microsoft backbone) |
| **Hub-Spoke** | Transit Gateway | **Azure Virtual WAN / Hub-Spoke VNets** | Virtual WAN = managed hub, or DIY hub-spoke with peering |
| **Private Endpoints** | VPC Endpoints (PrivateLink) | **Azure Private Link / Private Endpoints** | Same concept — private IPs for PaaS services |
| **Firewall** | AWS Network Firewall | **Azure Firewall (Premium)** | Azure Firewall Premium has TLS inspection, IDPS |
| **DDoS** | AWS Shield | **Azure DDoS Protection** | Standard tier auto-protects all public IPs in VNet |
| **WAF** | AWS WAF | **Azure WAF (on App Gateway/Front Door)** | WAF integrated into load balancing (simpler) |

### 2.5 Security & Identity

| Category | AWS | Azure | Key Difference |
|----------|-----|-------|----------------|
| **Identity Provider** | IAM (cloud only) | **Microsoft Entra ID (Azure AD)** | Entra ID = enterprise IdP for Azure, O365, SaaS apps, on-prem AD sync |
| **SSO** | IAM Identity Center | **Entra ID SSO** | Entra ID provides SSO for 3000+ SaaS apps (Salesforce, ServiceNow, etc.) |
| **MFA / Conditional Access** | IAM MFA | **Entra ID Conditional Access** | Risk-based, device-aware, location-aware policies (far richer than AWS MFA) |
| **Privileged Identity** | No equivalent | **Entra PIM (Privileged Identity Management)** | Just-in-time admin access with approval workflows |
| **Secrets** | Secrets Manager | **Azure Key Vault** | Key Vault combines secrets + keys + certificates (AWS splits these into 3 services) |
| **Threat Detection** | GuardDuty | **Microsoft Defender for Cloud** | Defender covers Azure, AWS, GCP, on-prem (multi-cloud security) |
| **Security Posture** | Security Hub | **Microsoft Defender for Cloud (CSPM)** | Includes Secure Score, compliance dashboard, recommendations |
| **SIEM** | No native SIEM (use third-party) | **Microsoft Sentinel** | Cloud-native SIEM + SOAR — collects from Azure, O365, AWS, GCP |
| **Organization Policies** | SCPs | **Azure Policy** | Azure Policy = preventive + detective. Deny, audit, modify, deploy-if-not-exists |
| **Governance Framework** | Control Tower | **Azure Landing Zones (ALZ) + Management Groups** | Management Groups = hierarchical policy inheritance |

### 2.6 DevOps & CI/CD

| Category | AWS | Azure | Key Difference |
|----------|-----|-------|----------------|
| **DevOps Platform** | CodePipeline + CodeBuild (or GitHub Actions) | **Azure DevOps** (Boards, Repos, Pipelines, Artifacts, Test Plans) | Azure DevOps is a complete ALM platform (not just CI/CD) |
| **CI/CD Pipeline** | CodePipeline + CodeBuild | **Azure Pipelines** (or GitHub Actions) | Azure Pipelines has YAML + Classic (visual) editor, multi-stage |
| **Artifact Storage** | ECR + CodeArtifact | **Azure Artifacts + ACR** | Azure Artifacts supports npm, NuGet, Maven, Python, Universal |
| **Source Control** | CodeCommit (deprecated) | **Azure Repos** (or GitHub) | Microsoft owns GitHub — deep integration |
| **Project Management** | No equivalent | **Azure Boards** | Boards = Agile project management (backlogs, sprints, Kanban) |
| **Test Management** | No equivalent | **Azure Test Plans** | Integrated test case management |
| **Monitoring** | CloudWatch | **Azure Monitor** | Azure Monitor = metrics + logs + alerts + Application Insights (APM) |
| **APM** | X-Ray | **Application Insights** | App Insights has live metrics, smart detection, availability tests |
| **Log Analytics** | CloudWatch Logs | **Log Analytics Workspace** | KQL (Kusto Query Language) is more powerful than CloudWatch Insights |
| **IaC** | CloudFormation / Terraform | **Bicep / ARM Templates / Terraform** | Bicep = Azure-native IaC (transpiles to ARM), simpler than ARM JSON |

### 2.7 AI/ML & Data

| Category | AWS | Azure | Key Difference |
|----------|-----|-------|----------------|
| **LLM Platform** | Bedrock (Claude, Titan, Llama) | **Azure OpenAI Service** | Exclusive enterprise access to GPT-4, GPT-4o, o1, DALL-E, Whisper |
| **ML Platform** | SageMaker | **Azure Machine Learning** | AML Studio has designer (low-code) + notebooks + pipelines |
| **Cognitive Services** | Rekognition, Comprehend, Polly (separate) | **Azure AI Services** (unified SDK) | Vision, Speech, Language, Decision — single SDK, single endpoint |
| **RAG / Search** | Bedrock Knowledge Bases + OpenSearch | **Azure AI Search (Cognitive Search)** | AI Search = vector + keyword + semantic search in one |
| **Data Warehouse** | Redshift | **Synapse Analytics (Dedicated SQL Pool)** | Synapse = warehouse + lake + Spark + pipelines unified |
| **Data Lake** | S3 + Glue + Lake Formation | **Azure Data Lake Storage Gen2** | ADLS Gen2 = hierarchical namespace on Blob Storage (HDFS-compatible) |
| **Stream Processing** | Kinesis | **Event Hubs + Stream Analytics** | Event Hubs ≈ Kafka (has Kafka-compatible endpoint!) |
| **ETL / Data Integration** | Glue | **Azure Data Factory** | Data Factory = visual ETL, 100+ connectors, mapping data flows |
| **Messaging** | SQS + SNS | **Service Bus + Event Grid** | Service Bus = enterprise messaging (sessions, dead-letter, transactions) |
| **Workflow** | Step Functions | **Logic Apps / Durable Functions** | Logic Apps = visual workflow designer with 400+ connectors |

---

## Part 3 — Azure Organization & Landing Zone

### 3.1 Azure Resource Hierarchy — Fundamentally Different from AWS

```
AZURE RESOURCE HIERARCHY (vs AWS):

┌──────────────────────────────────────────────────────────────────────────┐
│  Azure                                    AWS Equivalent                 │
│                                                                          │
│  Entra ID Tenant (identity boundary)      ≈ AWS Organizations root      │
│  ├── Management Groups (nested)           ≈ OUs                         │
│  │   ├── MG: Platform                     ≈ Shared Services OU          │
│  │   │   ├── Subscription: Connectivity   ≈ Network Hub Account        │
│  │   │   ├── Subscription: Identity       ≈ Security Account           │
│  │   │   └── Subscription: Management     ≈ Management Account         │
│  │   ├── MG: Landing Zones                                              │
│  │   │   ├── MG: Production                                             │
│  │   │   │   ├── Subscription: prod-app1  ≈ AWS Account: prod-app1    │
│  │   │   │   └── Subscription: prod-app2                                │
│  │   │   └── MG: Non-Production                                         │
│  │   │       ├── Subscription: dev-app1                                  │
│  │   │       └── Subscription: staging                                   │
│  │   ├── MG: Sandbox                                                     │
│  │   │   └── Subscription: sandbox-dev                                   │
│  │   └── MG: Decommissioned                                             │
│  └── Azure Policy (at any level)          ≈ SCPs                        │
│                                                                          │
│  KEY DIFFERENCES FROM AWS:                                               │
│  • Azure "Subscription" = AWS "Account" (blast radius boundary)         │
│  • Azure "Management Group" = AWS "OU" (but unlimited nesting)          │
│  • Azure identity is Entra ID (shared with O365, on-prem AD)            │
│  • Azure Policy is MORE POWERFUL than SCPs (can audit, modify, deploy)  │
│  • Azure has Resource Groups WITHIN subscriptions (no AWS equivalent)   │
│  • Azure RBAC inherits down: MG → Subscription → RG → Resource         │
└──────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Azure Landing Zone Architecture (CAF)

```
┌──────────────────────────────────────────────────────────────────────────┐
│             AZURE LANDING ZONE (Cloud Adoption Framework)                │
│                                                                          │
│  Root Management Group                                                   │
│  ├── Platform MG                                                         │
│  │   ├── Connectivity Subscription                                       │
│  │   │   ├── Hub VNet (10.0.0.0/16)                                     │
│  │   │   ├── Azure Firewall (Premium)                                   │
│  │   │   ├── ExpressRoute Gateway                                       │
│  │   │   ├── VPN Gateway (backup)                                       │
│  │   │   ├── Azure DNS Private Resolver                                 │
│  │   │   └── Azure Bastion (no SSH/RDP over public IP)                  │
│  │   │                                                                   │
│  │   ├── Identity Subscription                                           │
│  │   │   ├── Domain Controllers (AD DS if hybrid)                       │
│  │   │   └── Entra ID Connect (sync on-prem AD)                        │
│  │   │                                                                   │
│  │   └── Management Subscription                                         │
│  │       ├── Log Analytics Workspace (central logging)                  │
│  │       ├── Microsoft Sentinel (SIEM)                                  │
│  │       ├── Automation Account (patching, compliance)                  │
│  │       └── Azure Monitor (metrics, alerts, dashboards)                │
│  │                                                                       │
│  ├── Landing Zones MG                                                    │
│  │   ├── Corp MG (internal apps — no direct internet)                   │
│  │   │   ├── Subscription: corp-app1 → Spoke VNet peered to Hub        │
│  │   │   └── Subscription: corp-app2 → Spoke VNet peered to Hub        │
│  │   └── Online MG (internet-facing apps)                               │
│  │       ├── Subscription: online-app1 → Front Door + App Service      │
│  │       └── Subscription: online-app2 → AKS + Application Gateway    │
│  │                                                                       │
│  ├── Sandbox MG (no connectivity to corporate network)                  │
│  │   └── Subscription: sandbox-dev (auto-expire resources)              │
│  │                                                                       │
│  └── Decommissioned MG (migrated/retired subscriptions)                 │
│                                                                          │
│  POLICY ASSIGNMENTS (at Root MG level):                                  │
│  ├── Require resource tagging (CostCenter, Owner, Environment)          │
│  ├── Deny public IP creation on VMs                                      │
│  ├── Require encryption on all storage accounts                         │
│  ├── Audit/Deny resources outside approved regions                      │
│  ├── Deploy Defender for Cloud on all subscriptions                     │
│  ├── Deploy diagnostic settings to Log Analytics                        │
│  └── Deny classic/legacy resources                                       │
└──────────────────────────────────────────────────────────────────────────┘

AWS COMPARISON:
  Root MG                  ≈ Organizations root
  Platform MG              ≈ Shared Services OU (Security, Network, Logging accounts)
  Connectivity Sub         ≈ Network Hub Account (Transit Gateway, Direct Connect)
  Management Sub           ≈ Log Archive Account + Management Account
  Landing Zones MG         ≈ Workload OUs (Prod, Non-Prod)
  Azure Policy             ≈ SCPs (but Azure Policy is much more powerful)
  Azure Firewall           ≈ AWS Network Firewall (Azure Firewall is more mature)
  ExpressRoute             ≈ Direct Connect
  Azure Bastion            ≈ SSM Session Manager (no bastion host needed)
  Log Analytics Workspace  ≈ CloudWatch Logs (but KQL >> CloudWatch Insights)
  Microsoft Sentinel       ≈ No AWS equivalent (GuardDuty + Security Hub + 3rd party SIEM)
```

### 3.3 Hub-Spoke Network Topology

```
AZURE HUB-SPOKE (vs AWS Transit Gateway):

                    ┌─────────────────────────────────┐
                    │          HUB VNET                │
                    │   (Connectivity Subscription)    │
                    │                                   │
                    │  ┌─────────────┐ ┌────────────┐ │
  On-Prem ←─────── │  │ ExpressRoute│ │  Azure     │ │
  (AD, SAP, etc)    │  │ Gateway     │ │  Firewall  │ │
                    │  └─────────────┘ └────────────┘ │
                    │  ┌─────────────┐ ┌────────────┐ │
                    │  │ VPN Gateway │ │  Azure     │ │
                    │  │ (backup)    │ │  Bastion   │ │
                    │  └─────────────┘ └────────────┘ │
                    └──────────┬──────────────────────┘
                               │ VNet Peering
              ┌────────────────┼────────────────┐
              │                │                │
        ┌─────▼─────┐   ┌─────▼─────┐   ┌─────▼─────┐
        │ Spoke VNet│   │ Spoke VNet│   │ Spoke VNet│
        │ App 1     │   │ App 2     │   │ AKS       │
        │ (prod-app1│   │ (prod-app2│   │ (k8s-prod │
        │  sub)     │   │  sub)     │   │  sub)     │
        └───────────┘   └───────────┘   └───────────┘

AWS EQUIVALENT:
  Hub VNet + Azure Firewall  ≈  Inspection VPC + AWS Network Firewall + Transit Gateway
  VNet Peering               ≈  TGW attachments (but VNet peering is simpler)
  ExpressRoute               ≈  Direct Connect
  Azure Bastion              ≈  SSM Session Manager
  
KEY AZURE ADVANTAGE:
• Azure Firewall is more mature (TLS inspection, IDPS, threat intel, web categories)
• Azure Bastion = managed jump box (no EC2 bastion host needed)
• VNet peering is simpler than Transit Gateway for <50 spokes
• For >50 spokes, use Azure Virtual WAN (≈ managed Transit Gateway)
```

### 3.4 Landing Zone Automation

| Tool | Azure | AWS Equivalent |
|------|-------|---------------|
| **Landing Zone Blueprint** | **Azure Landing Zone Accelerator (Bicep/Terraform)** | Control Tower |
| **Policy Framework** | Azure Policy (built-in initiative definitions) | SCPs + Config Rules |
| **Subscription Vending** | Subscription Vending Module (Terraform) | Control Tower Account Factory |
| **IaC (Azure-native)** | **Bicep** (cleaner than ARM JSON) | CloudFormation |
| **IaC (multi-cloud)** | **Terraform (AzureRM provider)** | Terraform (AWS provider) |
| **Governance Dashboard** | Azure Resource Graph + Workbooks | Config + Security Hub |

---

## Part 4 — Azure Migration: Assess → Migrate → Modernize → Optimize

### 4.1 Azure Migration Framework (Cloud Adoption Framework)

```
AZURE CLOUD ADOPTION FRAMEWORK (CAF) PHASES:

AWS MAP:    Assess  →  Mobilize  →  Migrate & Modernize
Azure CAF:  Strategy → Plan → Ready → Migrate/Innovate → Govern → Manage

Azure CAF is BROADER than AWS MAP — it includes governance and management as 
ongoing phases, not just migration checkpoints.

Strategy:  Define business justifications and expected outcomes
Plan:      Align actionable adoption plan with business outcomes  
Ready:     Prepare the cloud environment (Landing Zone)
Migrate:   Migrate existing workloads
Innovate:  Build new cloud-native solutions (Greenfield)
Govern:    Govern the environment (policies, cost, security)
Manage:    Manage operations (monitoring, patching, DR)
```

### 4.2 Azure Migration Tools (vs AWS)

| Migration Task | Azure Tool | AWS Equivalent |
|---------------|------------|---------------|
| **Portfolio Discovery** | **Azure Migrate** (unified hub) | Application Discovery Service + Migration Hub |
| **VM Migration** | **Azure Migrate: Server Migration** | Application Migration Service (MGN) |
| **Database Migration** | **Azure Database Migration Service (DMS)** | AWS DMS |
| **Schema Assessment** | **Data Migration Assistant (DMA)** | Schema Conversion Tool (SCT) |
| **Web App Migration** | **Azure Migrate: App Service Migration** | No equivalent (manual) |
| **Containerization** | **Azure Migrate: App Containerization** | No equivalent (manual) |
| **Large Data Transfer** | **Azure Data Box** (100TB/1PB) | Snowball / Snowmobile |
| **Online Data Transfer** | **AzCopy / Azure File Sync** | DataSync |
| **SQL Server Assessment** | **Azure SQL Migration Extension** | No equivalent |
| **Cost Estimation** | **TCO Calculator + Azure Migrate** | Migration Evaluator |

### 4.3 Azure Migrate — The Unified Migration Hub

```
AZURE MIGRATE (vs AWS — which splits across multiple tools):

┌──────────────────────────────────────────────────────────────────┐
│                      AZURE MIGRATE                                │
│               (Single hub for ALL migration)                      │
│                                                                   │
│  ┌────────────────┐  ┌────────────────┐  ┌───────────────────┐  │
│  │ Discovery &    │  │ Assessment     │  │ Migration         │  │
│  │ Assessment     │  │ (readiness,    │  │ (execute the      │  │
│  │ (install agent │  │  sizing,       │  │  migration)       │  │
│  │  or agentless) │  │  cost)         │  │                   │  │
│  └────────────────┘  └────────────────┘  └───────────────────┘  │
│                                                                   │
│  Covers:                                                          │
│  ├── Servers (VMware, Hyper-V, physical, AWS EC2)               │
│  ├── Databases (SQL Server, PostgreSQL, MySQL, Oracle)          │
│  ├── Web Apps (ASP.NET, Java → App Service)                     │
│  ├── Containerization (auto-containerize VMs → AKS)             │
│  ├── VDI (VMware Horizon → Azure Virtual Desktop)               │
│  └── Data (large-scale data migration planning)                  │
└──────────────────────────────────────────────────────────────────┘

AWS EQUIVALENT REQUIRES MULTIPLE TOOLS:
  Azure Migrate (discovery)     = Application Discovery Service
  Azure Migrate (assessment)    = Migration Evaluator (TSO Logic)
  Azure Migrate (VM migration)  = Application Migration Service (MGN)
  Azure Migrate (DB migration)  = DMS + SCT
  Azure Migrate (web apps)      = No equivalent (manual)
  Azure Migrate (containers)    = No equivalent (manual)

AZURE ADVANTAGE: ONE tool to discover, assess, and migrate everything.
AWS requires 4-5 separate tools for the same scope.
```

### 4.4 Database Migration — Azure Specifics

```
DATABASE MIGRATION ON AZURE:

Source Database         → Azure Target                      → AWS Equivalent
────────────────────────────────────────────────────────────────────────────
SQL Server              → Azure SQL Database (PaaS)         → RDS SQL Server
                        → SQL Managed Instance (PaaS, 100%) → No equivalent (closest: RDS)
                        → SQL Server on Azure VM (IaaS)     → EC2 + SQL Server

Oracle                  → Azure SQL (with conversion)       → Aurora PostgreSQL
                        → Azure DB for PostgreSQL            → Aurora PostgreSQL
                        → Oracle on Azure VM                 → Oracle on EC2

PostgreSQL              → Azure DB for PostgreSQL Flex      → RDS/Aurora PostgreSQL

MySQL                   → Azure DB for MySQL Flexible       → RDS/Aurora MySQL

MongoDB                 → Cosmos DB (MongoDB API)           → DocumentDB
                        → MongoDB Atlas on Azure             → MongoDB Atlas on AWS

Cassandra               → Cosmos DB (Cassandra API)         → Keyspaces (managed Cassandra)

AZURE UNIQUE ADVANTAGES:
1. SQL Managed Instance = 100% SQL Server compatibility in PaaS
   (No AWS equivalent — RDS SQL Server has limitations)
   
2. Azure Hybrid Benefit = Reuse on-prem SQL Server licenses
   (Saves 40-55% vs full-price Azure SQL, no AWS equivalent)
   
3. Azure SQL has built-in:
   ├── Intelligent Performance (auto-tuning indexes, query store)
   ├── Hyperscale tier (100TB+, instant scale, rapid backup)
   ├── Serverless tier (auto-pause, auto-scale, pay per second)
   └── Elastic Pools (share resources across databases)
   
4. Cosmos DB supports 5 APIs in one service:
   SQL (document), MongoDB, Cassandra, Gremlin (graph), Table
   (AWS has separate services: DynamoDB, DocumentDB, Keyspaces, Neptune)
```

---

## Part 5 — Azure Modernization & Cloud-Native Patterns

### 5.1 Compute Decision Tree on Azure

```
APPLICATION MODERNIZATION — WHERE TO RUN IT ON AZURE:

                    ┌──────────────────────────────┐
                    │ What type of application?     │
                    └──────────────┬───────────────┘
                                   │
           ┌───────────────────────┼───────────────────────┐
           ▼                       ▼                       ▼
    ┌─────────────┐         ┌─────────────┐         ┌─────────────┐
    │ Web App /   │         │ Container / │         │ Event-driven│
    │ API         │         │ Microservice│         │ / Batch     │
    └──────┬──────┘         └──────┬──────┘         └──────┬──────┘
           │                       │                       │
    ┌──────▼──────┐         ┌──────▼──────┐         ┌──────▼──────┐
    │ Need full   │         │ Need K8s    │         │ Simple      │
    │ PaaS?       │         │ control?    │         │ triggers?   │
    └──────┬──────┘         └──────┬──────┘         └──────┬──────┘
           │                       │                       │
    ┌─YES──┴──NO──┐         ┌─YES──┴──NO──┐         ┌─YES──┴──NO──┐
    ▼              ▼         ▼              ▼         ▼              ▼
App Service   Static Web  AKS         Container   Azure         Azure
(.NET, Java,  Apps        (full K8s)  Apps        Functions     Batch
 Python, Node)                       (serverless  (serverless   (HPC,
                                      containers) compute)      rendering)

AWS COMPARISON:
  App Service       ≈  Elastic Beanstalk (but App Service is FAR superior)
  Static Web Apps   ≈  Amplify Hosting
  AKS              ≈  EKS (AKS control plane is FREE)
  Container Apps    ≈  App Runner + Fargate (Container Apps has Dapr + KEDA built-in)
  Azure Functions   ≈  Lambda (Functions supports Durable Functions for stateful)
  Azure Batch       ≈  AWS Batch
```

### 5.2 AKS Deep Dive — vs EKS

| Feature | AKS (Azure) | EKS (AWS) | Winner |
|---------|-------------|-----------|--------|
| **Control Plane Cost** | **FREE** | $0.10/hr ($73/month per cluster) | **AKS** |
| **Managed Upgrades** | Auto-upgrade channels (Rapid, Stable) | Manual upgrade process | AKS |
| **Managed Istio** | Istio-based service mesh (add-on) | App Mesh or manual Istio | Tie |
| **Workload Identity** | Azure AD Workload Identity | IRSA | Similar |
| **Windows Containers** | **Full Windows node pool support** | Limited Windows support | **AKS** |
| **Virtual Nodes (serverless)** | ACI integration (burst to serverless) | Fargate profiles | Similar |
| **GitOps** | Flux (GitOps add-on) | ArgoCD (third-party) | Tie |
| **Dev Spaces** | Bridge to Kubernetes (VS Code) | No equivalent | **AKS** |
| **Multi-Cluster** | Azure Arc-enabled K8s | No equivalent | **AKS** |
| **Node Autoscaling** | Cluster Autoscaler + KEDA | Karpenter / Cluster Autoscaler | EKS (Karpenter) |

### 5.3 Azure App Service — The .NET/Java PaaS Champion

```
APP SERVICE (No real AWS equivalent — Beanstalk is far inferior):

Features that AWS Elastic Beanstalk DOESN'T have:
├── Deployment Slots (blue/green with traffic routing by percentage)
├── Auto-heal (restart app on memory leak, slow responses)
├── VNet Integration (private access to databases without NAT)
├── Hybrid Connections (connect to on-prem databases without VPN)
├── Managed Certificates (auto-SSL with custom domains)
├── Authentication built-in (Entra ID, Google, Facebook — zero code)
├── WebJobs (background processing attached to the app)
├── Azure Spring Apps (managed VMware Tanzu for Spring Boot)
└── Automatic OS patching (no maintenance window)

WHEN TO USE APP SERVICE:
├── .NET (ASP.NET Core, .NET Framework) web apps
├── Java (Spring Boot, Tomcat, JBoss) web apps
├── Node.js / Python / PHP / Ruby web apps
├── REST APIs
├── Mobile backends
└── Any HTTP workload that doesn't need containers/K8s complexity
```

### 5.4 Cosmos DB — Azure's Unique Global Database

```
COSMOS DB vs AWS DATABASES:

┌──────────────────────────────────────────────────────────────────┐
│                     COSMOS DB CAPABILITIES                        │
│                                                                   │
│  5 APIs in ONE Service:                                           │
│  ├── NoSQL (native — SQL-like query over JSON documents)         │
│  ├── MongoDB API (drop-in replacement for MongoDB)               │
│  ├── Cassandra API (drop-in replacement for Cassandra)           │
│  ├── Gremlin API (graph database)                                │
│  ├── Table API (key-value, replaces Azure Table Storage)         │
│                                                                   │
│  Unique Features:                                                 │
│  ├── 5 Consistency Levels:                                       │
│  │   Strong → Bounded Staleness → Session → Consistent Prefix → Eventual
│  │   (AWS DynamoDB only offers: Strong or Eventual — no middle ground)
│  ├── Multi-region writes (active-active globally)                │
│  ├── Automatic indexing (every property indexed, no management)  │
│  ├── Serverless tier (pay per operation) OR Provisioned (RU/s)  │
│  ├── < 10ms reads, < 10ms writes (SLA-backed)                  │
│  └── 99.999% availability SLA (with multi-region writes)        │
│                                                                   │
│  AWS EQUIVALENTS (requires 4 separate services):                 │
│  ├── DynamoDB (NoSQL / key-value)                                │
│  ├── DocumentDB (MongoDB compatible)                             │
│  ├── Keyspaces (Cassandra compatible)                            │
│  └── Neptune (Graph — Gremlin/SPARQL)                            │
│                                                                   │
│  COSMOS DB ADVANTAGE: One service, one SDK, one monitoring,     │
│  one billing model — vs 4 separate AWS services with different  │
│  APIs, SDKs, pricing models, and operational models.            │
└──────────────────────────────────────────────────────────────────┘
```

---

## Part 6 — Azure DevOps & CI/CD Architecture

### 6.1 Azure DevOps vs GitHub Actions vs AWS

| Capability | Azure DevOps Pipelines | GitHub Actions | AWS CodePipeline/Build |
|-----------|----------------------|----------------|----------------------|
| **Visual Editor** | Yes (Classic) | No | Yes (console only) |
| **YAML Pipeline** | Yes (multi-stage) | Yes | Limited |
| **Self-Hosted Agents** | Yes | Yes (runners) | No |
| **Approval Gates** | Yes (environments) | Yes (environments) | Yes (manual approval) |
| **Artifact Management** | Azure Artifacts (NuGet, npm, Maven, Python) | GitHub Packages | CodeArtifact |
| **Board/Work Tracking** | Azure Boards (Agile, Scrum, CMMI) | GitHub Issues/Projects | No equivalent |
| **Test Management** | Azure Test Plans | No built-in | No equivalent |
| **Integration** | Azure + GitHub + any Git | GitHub + any cloud | AWS only |
| **Cost** | Free for first 5 users, 1800 min CI/CD | Free 2000 min/month (public repos) | Pay per build minute |

### 6.2 Azure CI/CD Pipeline Architecture

```
AZURE CI/CD (using Azure DevOps or GitHub Actions):

┌────────────────────────────────────────────────────────────────────┐
│  GitHub / Azure Repos                                              │
│                    │                                                │
│                    ▼                                                │
│  ┌────────────────────────────────────┐                            │
│  │ Azure Pipelines / GitHub Actions    │                            │
│  │                                     │                            │
│  │  Stage 1: BUILD                     │                            │
│  │  ├── Restore dependencies           │                            │
│  │  ├── Compile / build                │                            │
│  │  ├── Unit tests                     │                            │
│  │  ├── SonarQube / SAST               │                            │
│  │  └── Docker build                   │                            │
│  │                                     │                            │
│  │  Stage 2: SCAN                      │                            │
│  │  ├── Trivy (container scan)         │                            │
│  │  ├── OWASP DC (dependency scan)     │                            │
│  │  ├── Checkov / tfsec (IaC scan)     │                            │
│  │  └── Push to ACR                    │                            │
│  │                                     │                            │
│  │  Stage 3: DEPLOY (per environment)  │                            │
│  │  ├── DEV: auto-deploy               │                            │
│  │  ├── STAGING: auto-deploy + tests   │                            │
│  │  └── PROD: manual approval → deploy │                            │
│  └────────────────────────────────────┘                            │
│                    │                                                │
│        ┌───────────┼───────────┐                                   │
│        ▼           ▼           ▼                                   │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐                          │
│  │   ACR    │ │   AKS    │ │App Service│                          │
│  │ (Docker  │ │ (K8s via │ │ (Slots    │                          │
│  │  images) │ │  Flux    │ │  for blue/│                          │
│  │          │ │  GitOps) │ │  green)   │                          │
│  └──────────┘ └──────────┘ └──────────┘                          │
└────────────────────────────────────────────────────────────────────┘
```

### 6.3 Azure Monitoring & Observability

| Capability | Azure Service | AWS Equivalent | Key Difference |
|-----------|---------------|---------------|----------------|
| **Metrics** | Azure Monitor Metrics | CloudWatch Metrics | Similar |
| **Logs** | Log Analytics (KQL) | CloudWatch Logs (Insights) | **KQL is far more powerful** than CloudWatch Insights |
| **APM** | **Application Insights** | X-Ray | App Insights is a complete APM with live metrics, auto-detection |
| **Distributed Tracing** | Application Insights | X-Ray | App Insights has end-to-end transaction tracking |
| **Smart Detection** | App Insights Anomaly Detection | No equivalent | Automatically detects failures, latency anomalies |
| **Live Metrics** | App Insights Live Metrics | No equivalent | Real-time streaming of telemetry |
| **Availability Tests** | App Insights URL Ping/Multi-step | Route 53 Health Checks | More sophisticated web test scenarios |
| **Dashboards** | Azure Dashboards + Workbooks | CloudWatch Dashboards | Workbooks have interactive, parametric queries |
| **SIEM** | **Microsoft Sentinel** | No native SIEM | Sentinel = cloud SIEM + SOAR + threat hunting |
| **Alerting** | Azure Monitor Alerts | CloudWatch Alarms | Action Groups route to email, SMS, Logic App, Function, webhook |

---

## Part 7 — Azure Security, Compliance & Governance

### 7.1 Security Architecture — Azure vs AWS

```
AZURE SECURITY MODEL vs AWS:

Azure                                        AWS
──────────────────────────────────────       ──────────────────────────────────────
Azure Policy (preventive + detective)        SCPs (preventive only)
├── Deny (≈ SCP deny)                        ├── Deny
├── Audit (≈ Config Rule)                    │   (SCPs can only deny, not audit)
├── Modify (auto-tag, auto-remediate)        │   (No equivalent to Modify)
├── DeployIfNotExists (auto-deploy)          │   (No equivalent — must use CFn)
└── Append (add fields to requests)          └── 

Microsoft Defender for Cloud                 GuardDuty + Security Hub + Inspector
├── Secure Score (0-100 score)               ├── Security Hub score
├── CSPM (multi-cloud — AWS, GCP too!)       ├── AWS-only CSPM
├── Defender for Servers (EDR)               ├── GuardDuty (no EDR)
├── Defender for Containers                  ├── No container security
├── Defender for SQL                         ├── No database security
├── Defender for Storage                     ├── Macie (S3 only)
├── Defender for Key Vault                   ├── No KMS monitoring
└── Regulatory compliance dashboard          └── Config Conformance Packs

Microsoft Sentinel (SIEM + SOAR)             No native SIEM
├── 200+ data connectors                     ├── (Need Splunk/Datadog/etc.)
├── KQL-based detection rules                │
├── Automated playbooks (Logic Apps)         │
├── Threat hunting notebooks                 │
├── UEBA (User Entity Behavior Analytics)    │
└── Collects from Azure, O365, AWS, GCP      └──

AZURE UNIQUE SECURITY ADVANTAGES:
1. Azure Policy is MORE POWERFUL than SCPs
   (SCPs can only deny. Azure Policy can deny, audit, modify, deploy-if-not-exists)
   
2. Microsoft Defender for Cloud works MULTI-CLOUD
   (Protects AWS and GCP workloads too — not just Azure)
   
3. Microsoft Sentinel is a cloud-native SIEM
   (AWS has no native SIEM — must use third-party)
   
4. Entra ID Conditional Access
   (Risk-based, device-aware, location-aware access policies — far beyond AWS MFA)
   
5. Entra PIM (Privileged Identity Management)
   (Just-in-time admin access with approval workflows — no AWS equivalent)
```

### 7.2 Azure Policy — More Powerful Than AWS SCPs

```
AZURE POLICY EFFECTS (vs AWS SCPs):

┌──────────────────────────────────────────────────────────────────┐
│  Effect                Description                AWS Equivalent │
│  ────────────────────────────────────────────────────────────────│
│  Deny                  Block non-compliant         SCP Deny      │
│                        resource creation                         │
│                                                                   │
│  Audit                 Log non-compliance          Config Rule   │
│                        (don't block)               (separate svc)│
│                                                                   │
│  Modify                Auto-fix resources          NO EQUIVALENT │
│                        (add tags, fix settings)                   │
│                                                                   │
│  DeployIfNotExists     Auto-deploy missing         NO EQUIVALENT │
│                        resources (e.g., deploy                    │
│                        diagnostic settings)                       │
│                                                                   │
│  Append                Add fields to requests      NO EQUIVALENT │
│                        (e.g., force HTTPS)                        │
│                                                                   │
│  AuditIfNotExists      Audit if related            NO EQUIVALENT │
│                        resource is missing                        │
│                                                                   │
│  Disabled              Turn off a policy           N/A           │
└──────────────────────────────────────────────────────────────────┘

EXAMPLE — Auto-deploy diagnostic settings:
{
  "effect": "DeployIfNotExists",
  "details": {
    "type": "Microsoft.Insights/diagnosticSettings",
    "deployment": {
      // ARM template to create diagnostic settings
      // sending logs to central Log Analytics Workspace
    }
  }
}

This AUTOMATICALLY configures logging for EVERY new resource.
On AWS, you'd need a CloudTrail + Lambda + Config Rule chain to do this.
```

---

## Part 8 — Azure Data & AI Platform Architecture

### 8.1 Azure Data Platform Architecture

```
AZURE DATA PLATFORM (vs AWS):

┌──────────────────────────────────────────────────────────────────────┐
│  AZURE SYNAPSE ANALYTICS (≈ Redshift + Athena + Glue + EMR combined)│
│                                                                       │
│  INGEST              PROCESS              ANALYZE                    │
│  ┌──────────┐       ┌──────────────┐     ┌────────────────────┐     │
│  │Event Hubs│──────▶│ Synapse      │────▶│ Synapse SQL Pool   │     │
│  │(≈ Kinesis)│      │ Spark Pools  │     │ (dedicated/        │     │
│  └──────────┘       │ (managed     │     │  serverless)       │     │
│  ┌──────────┐       │  Spark)      │     └────────────────────┘     │
│  │Data Lake │──────▶│              │                                 │
│  │Gen2 (≈S3)│       └──────────────┘     ┌────────────────────┐     │
│  └──────────┘       ┌──────────────┐     │ Power BI           │     │
│  ┌──────────┐       │ Data Factory │     │ (≈ QuickSight but  │     │
│  │Event Grid│──────▶│ (≈ Glue)     │────▶│  enterprise-grade) │     │
│  │(≈ EB)    │       │ 100+ connectors│   └────────────────────┘     │
│  └──────────┘       └──────────────┘                                 │
│                                          ┌────────────────────┐     │
│  ML & AI                                 │ Azure ML / Azure   │     │
│  ┌──────────┐                            │ OpenAI Service     │     │
│  │ Synapse  │───────────────────────────▶│ (GPT-4, GPT-4o)   │     │
│  │ ML       │                            └────────────────────┘     │
│  │ (in-DB ML│                                                        │
│  └──────────┘                                                        │
└──────────────────────────────────────────────────────────────────────┘

AWS EQUIVALENT REQUIRES SEPARATE SERVICES:
  Synapse SQL Pool     = Redshift (dedicated) + Athena (serverless)
  Synapse Spark        = EMR (Spark)
  Data Factory         = Glue
  Event Hubs           = Kinesis Data Streams
  Data Lake Gen2       = S3 + Lake Formation
  Power BI             = QuickSight (Power BI is more powerful/adopted)
  Synapse Pipelines    = Glue Workflows / Step Functions
  
  Azure: 1 service (Synapse) with integrated workspace
  AWS: 5+ separate services, separate consoles, separate billing
```

### 8.2 Azure OpenAI Service — Azure's AI Differentiator

```
AZURE OPENAI SERVICE vs AWS BEDROCK:

┌──────────────────────────────────────────────────────────────────┐
│  Azure OpenAI Service           AWS Bedrock                      │
│  ─────────────────────          ──────────────────────           │
│  GPT-4, GPT-4o, GPT-4-turbo    Claude 3.5 (Anthropic)          │
│  o1, o1-mini (reasoning)        Titan (Amazon)                   │
│  DALL-E 3 (images)              Llama 3 (Meta)                   │
│  Whisper (speech-to-text)       Mistral, Cohere                  │
│  Text Embedding (ada-002)       Titan Embeddings                 │
│  GPT-4 Vision (multimodal)      Claude 3 Vision                  │
│                                                                   │
│  AZURE ADVANTAGE:                                                │
│  ├── GPT-4 is the market leader — Azure has exclusive access    │
│  ├── Enterprise features: content filtering, abuse monitoring    │
│  ├── Runs in YOUR Azure subscription (data stays in region)     │
│  ├── Private endpoints — no data leaves your VNet               │
│  ├── Azure AI Search integration for RAG                        │
│  └── Same Azure RBAC, Azure Policy, compliance framework        │
│                                                                   │
│  AWS ADVANTAGE:                                                   │
│  ├── More model VARIETY (Claude, Llama, Mistral, Cohere)        │
│  ├── Fine-tuning for more models                                 │
│  ├── Knowledge Bases (managed RAG)                               │
│  └── Agents (multi-step reasoning)                               │
│                                                                   │
│  ARCHITECT'S TAKE:                                               │
│  • If you need GPT-4/o1 specifically → Azure OpenAI             │
│  • If you want model diversity/flexibility → AWS Bedrock        │
│  • If you want latest Google models → GCP Vertex AI (Gemini)    │
└──────────────────────────────────────────────────────────────────┘
```

---

## Part 9 — Azure Networking Deep Dive

### 9.1 VNet Architecture — Regional Like AWS

```
AZURE VNET vs AWS VPC:

Both are REGIONAL (unlike GCP's Global VPC):

Azure VNet:                              AWS VPC:
├── Regional (same as AWS)               ├── Regional
├── Subnets are AZ-spanning by default   ├── Subnets are AZ-specific
│   (no need to create subnet-per-AZ)    │   (must create subnet per AZ)
├── NSGs attach to NIC or Subnet         ├── SGs attach to ENI
├── ASGs (Application Security Groups)   ├── No equivalent (tag-based SGs)
├── Service Endpoints (route to PaaS)    ├── VPC Endpoints (gateway/interface)
├── Private Endpoints (Private Link)     ├── PrivateLink
├── VNet Peering (global, non-transitive)├── VPC Peering (global, non-transitive)
└── Azure Firewall (NVA alternative)     └── AWS Network Firewall

KEY DIFFERENCE — SUBNETS:
Azure: Subnets span ALL availability zones in a region.
       One subnet = all AZs. Simpler! Fewer subnets to manage.
       
AWS:   Subnets are AZ-specific.
       Need 3 subnets × 3 tiers = 9 subnets minimum.
       More granular but more complex.
```

### 9.2 Azure Front Door — Global Load Balancing + CDN + WAF

```
AZURE FRONT DOOR (vs AWS CloudFront + ALB + WAF + Route53):

Azure Front Door = ONE SERVICE that combines:
├── Global load balancing (Layer 7)        = CloudFront + Route53
├── CDN (content caching at edge)          = CloudFront
├── WAF (web application firewall)         = AWS WAF
├── SSL offloading                         = ACM + ALB
├── URL-based routing                      = ALB listener rules
├── Session affinity                       = ALB sticky sessions
├── Health probes with auto-failover       = Route53 health checks
├── Caching rules                          = CloudFront behaviors
└── Private Link to origins                = PrivateLink + ALB

AWS requires 4+ separate services to achieve what Front Door does in one.

WHEN TO USE FRONT DOOR:
├── Internet-facing applications needing global reach
├── Multi-region deployments with automatic failover
├── Applications needing WAF + CDN + LB in one
└── API backends behind a global endpoint
```

### 9.3 ExpressRoute vs AWS Direct Connect

| Feature | Azure ExpressRoute | AWS Direct Connect |
|---------|-------------------|-------------------|
| **Speed** | 50 Mbps – 100 Gbps | 1 Gbps – 100 Gbps |
| **Global Reach** | **Connect on-prem sites through Microsoft backbone** | No equivalent (need separate circuits) |
| **Microsoft Peering** | **Access O365, Dynamics via private circuit** | No equivalent (O365 is Microsoft) |
| **Redundancy** | Zone-redundant gateways, ExpressRoute circuits | Redundant connections to DX locations |
| **Encryption** | MACsec (layer 2 encryption) | MACsec |
| **Pricing** | Metered ($0.025/GB outbound) or Unlimited | Port hour + data transfer |

---

## Part 10 — Azure Cost Management & FinOps

### 10.1 Azure Pricing Model (vs AWS)

| Pricing Feature | Azure | AWS |
|----------------|-------|-----|
| **On-Demand** | Pay-as-you-go (per-second for Linux, per-minute for Windows) | Per-second billing |
| **Reserved Instances** | 1-year (≈40% off) or 3-year (≈60% off) | 1-year or 3-year RIs |
| **Savings Plans** | Azure Savings Plans (compute, similar to AWS) | AWS Savings Plans |
| **Spot** | Spot VMs (up to 90% off) | Spot Instances (similar) |
| **Hybrid Benefit** | **Reuse Windows/SQL Server licenses — 40-80% savings** | **No equivalent** (BYOL is limited) |
| **Dev/Test Pricing** | **Azure Dev/Test subscriptions — discounted rates, no license fees** | No equivalent |
| **Free Tier** | 12-month free + always-free services | 12-month free + always-free |
| **Enterprise Agreement** | EA pricing, MACC (Microsoft Azure Consumption Commitment) | EDP (Enterprise Discount Program) |

### 10.2 Azure Cost Management Tools

| Tool | Azure | AWS Equivalent |
|------|-------|---------------|
| **Cost Analysis** | **Cost Management + Billing** (native, free) | Cost Explorer |
| **Budgets** | Azure Budgets (with action groups) | AWS Budgets |
| **Advisor Recommendations** | **Azure Advisor** (cost, security, reliability, performance, operational excellence) | Trusted Advisor |
| **Right-Sizing** | Azure Advisor VM right-sizing | Compute Optimizer |
| **Reservation Recommendations** | Azure Advisor RI recommendations | RI/SP recommendations |
| **Cost Allocation** | Tags + Cost Management scopes | Tags + Cost Allocation Tags |
| **Exports** | Cost Management exports to Storage Account | CUR export to S3 |
| **Third-Party** | Finout, CloudHealth, Spot.io | Same third-party tools |

### 10.3 Azure Hybrid Benefit — The Enterprise Cost Saver

```
AZURE HYBRID BENEFIT (NO AWS EQUIVALENT):

If you have on-prem licenses with Software Assurance:

Windows Server:
├── On-prem license → FREE Windows VM in Azure
├── Savings: ~40% vs pay-as-you-go Windows VM
└── Example: D4s v5 Windows VM: $280/month → $166/month (save $114/month)

SQL Server:
├── Enterprise license → Azure SQL Managed Instance at Linux price
├── Savings: ~55% on Azure SQL Database / Managed Instance
├── Can also apply to SQL Server on Azure VMs
└── Example: 8-core SQL MI: $3,200/month → $1,440/month (save $1,760/month!)

Linux:
├── Red Hat / SUSE subscriptions → RHEL/SUSE VMs at lower price
└── Savings: ~30-40%

ARCHITECT'S ADVICE:
"If your customer has existing Microsoft EA with SQL Server and
Windows Server licenses, Azure is automatically 40-55% cheaper
than AWS for those workloads — before any architecture optimization.
This is often the single biggest factor in cloud choice for
Microsoft-heavy enterprises."
```

---

## Part 11 — Azure Interview Q&A: 50 Questions

### Category 1: Azure Architecture & Design (15 Questions)

**Q1: What is the Azure resource hierarchy and how does it differ from AWS?**

> **A:** Azure has: Entra ID Tenant → Management Groups (nested, unlimited depth) → Subscriptions → Resource Groups → Resources. Key differences from AWS: (1) Azure "Subscription" = AWS "Account" (blast radius boundary). (2) Azure has "Resource Groups" within subscriptions (AWS has no sub-account grouping). (3) Azure Management Groups support unlimited nesting (AWS OUs are more limited). (4) Azure RBAC and Policy inherit down the hierarchy (Management Group → Subscription → Resource Group → Resource). (5) Azure identity is Entra ID — shared with Office 365, Windows, on-prem AD. AWS IAM is standalone per account.

**Q2: When would you choose Azure SQL Database vs SQL Managed Instance vs SQL Server on VM?**

> **A:** Decision hierarchy: (1) **Azure SQL Database** (PaaS): Best for new applications, serverless/Hyperscale options, auto-tuning, lowest operational overhead. Some SQL Server features not available (SQL Agent, cross-database queries). (2) **SQL Managed Instance** (PaaS with near-100% compatibility): Best for lift-and-shift of existing SQL Server workloads. Supports SQL Agent, linked servers, CLR, Service Broker. Best migration target when app relies on SQL Server-specific features. (3) **SQL Server on Azure VM** (IaaS): Full control, 100% compatibility, required when you need OS-level access or unsupported features. Highest operational overhead. **AWS comparison:** AWS RDS SQL Server ≈ Azure SQL Database (but with fewer features). No AWS equivalent to SQL Managed Instance. SQL Server on EC2 ≈ SQL Server on Azure VM, but Azure Hybrid Benefit makes Azure VMs 40-55% cheaper.

**Q3: Explain Cosmos DB's consistency levels and when to use each.**

> **A:** Cosmos DB offers 5 consistency levels (from strongest to weakest): (1) **Strong:** All reads see the latest write globally. Use for financial transactions where consistency is critical. Cost: highest latency. (2) **Bounded Staleness:** Reads may lag by at most K versions or T time. Use when you need predictable consistency guarantees. (3) **Session:** Consistency within a user session (most common). A user always sees their own writes. Default and recommended for most apps. (4) **Consistent Prefix:** Reads never see out-of-order writes. Use for scenarios where order matters but staleness is OK. (5) **Eventual:** No ordering guarantees, lowest latency. Use for view counters, likes, non-critical aggregations. **AWS comparison:** DynamoDB offers only Strong or Eventual — no middle ground. Cosmos DB's 5 levels let you fine-tune the consistency-performance trade-off per collection/query.

**Q4: How do you design a multi-region application on Azure?**

> **A:** (1) **Azure Front Door** as the global entry point (single anycast IP, CDN, WAF, health probes). (2) **App Service or AKS** in each region behind the Front Door backend pool. (3) **Cosmos DB** with multi-region writes for global database consistency. (4) **Azure SQL** with active geo-replication or auto-failover groups for relational data. (5) **Azure Cache for Redis** per region for caching. (6) **Traffic Manager** (DNS-based) or **Front Door** (proxy-based) for failover. (7) **Event Grid / Service Bus** for cross-region event distribution. **Key Azure advantage:** Front Door provides both CDN + global LB + WAF in one service (AWS needs CloudFront + ALB + WAF + Route53). Cosmos DB active-active multi-region writes with 5 consistency levels has no AWS equivalent.

**Q5: What is Azure Arc and when would you use it?**

> **A:** Azure Arc extends Azure management to any infrastructure: (1) **Arc-enabled servers:** Manage on-prem/other-cloud VMs from Azure (Azure Policy, Monitoring, Defender). (2) **Arc-enabled Kubernetes:** Manage any K8s cluster (EKS, GKE, on-prem) from Azure portal. Apply GitOps, Azure Policy, Defender. (3) **Arc-enabled data services:** Run Azure SQL Managed Instance and PostgreSQL on any K8s cluster. (4) **Arc-enabled app services:** Run Azure App Service, Functions, Logic Apps on any K8s cluster. **When to use:** Hybrid environments, multi-cloud governance, edge deployments, organizations that want Azure's management plane for non-Azure resources. **AWS comparison:** AWS Outposts runs AWS on-prem but only supports AWS services. Azure Arc manages any infrastructure and brings Azure services to any Kubernetes.

**Q6: How does Azure Policy differ from AWS SCPs and Config Rules?**

> **A:** Azure Policy is more powerful because it combines what AWS needs two separate services for: (1) **Deny** effect ≈ SCP deny (preventive). (2) **Audit** effect ≈ Config Rule (detective). (3) **Modify** effect = no AWS equivalent (auto-remediate non-compliant resources — e.g., auto-add tags). (4) **DeployIfNotExists** = no AWS equivalent (auto-deploy resources — e.g., auto-configure diagnostic settings for every new resource). (5) **Append** = no AWS equivalent (modify request payload). Azure Policy can be assigned at Management Group, Subscription, or Resource Group level (like SCPs at OU/Account). It also has built-in **Policy Initiatives** (groups of policies for compliance standards: CIS, PCI, HIPAA).

**Q7: What is the difference between Azure Firewall and NSGs?**

> **A:** **NSGs (Network Security Groups):** Layer 3/4 stateful firewall at the subnet or NIC level. Allow/deny based on IP, port, protocol. Free. ≈ AWS Security Groups. **Azure Firewall:** Layer 3-7 managed firewall at the VNet/hub level. Supports FQDN filtering, TLS inspection (Premium), IDPS, threat intelligence, centralized logging. Costs ~$900/month + data processing. ≈ AWS Network Firewall (but more mature). **When to use which:** NSGs for micro-segmentation between subnets/VMs. Azure Firewall for centralized egress filtering, hub-spoke inspection, and advanced threat detection. Most enterprises use both: NSGs within spokes, Azure Firewall in the hub.

**Q8-Q15: Additional Architecture Questions**

| # | Question | Key Points |
|---|----------|------------|
| 8 | How do you implement zero-trust on Azure? | Entra ID Conditional Access + PIM + Private Link + Azure Firewall + Defender |
| 9 | What is Azure Virtual WAN? | Managed hub-spoke at scale (>50 spokes). Includes VPN, ExpressRoute, Firewall. ≈ Managed Transit Gateway |
| 10 | How do you handle DNS in a hybrid environment? | Azure Private DNS Zones + DNS Private Resolver + conditional forwarding to on-prem |
| 11 | When to use Azure Container Apps vs AKS? | Container Apps: simple event-driven microservices (Dapr + KEDA built-in). AKS: complex K8s workloads |
| 12 | What are Availability Zones on Azure? | 3+ AZs per region, zone-redundant services. Same as AWS AZs but subnets span all zones by default |
| 13 | How does Azure handle encryption? | SSE (default for all storage), CMK (Key Vault), Azure Confidential Computing (AMD SEV-SNP) |
| 14 | What is Azure Lighthouse? | Cross-tenant management for MSPs (manage multiple customer tenants). No AWS equivalent |
| 15 | What is Microsoft Purview? | Unified data governance: data map, data catalog, classification, lineage. ≈ Glue Data Catalog + Macie |

### Category 2: Migration & Modernization (10 Questions)

**Q16: Walk through migrating from AWS to Azure.**

> **A:** Phase 1: **Assess** — Deploy Azure Migrate appliance in AWS (agent-based). Discover EC2, RDS, S3 workloads. Map AWS services → Azure. Phase 2: **Plan** — Deploy Azure Landing Zone, establish connectivity (ExpressRoute or site-to-site VPN between AWS VPC and Azure VNet). Phase 3: **Migrate** — VMs: Azure Migrate agent replicates EC2 → Azure VMs. Databases: DMS for SQL/PostgreSQL/MySQL. Data: AzCopy or Data Box for large S3 → Blob migrations. Phase 4: **Modernize** — EKS → AKS, Lambda → Azure Functions, DynamoDB → Cosmos DB, S3 → Blob + ADLS Gen2. **Key savings opportunity:** Apply Azure Hybrid Benefit for all Windows/SQL Server workloads immediately.

**Q17: How would you migrate an on-prem .NET application to Azure?**

> **A:** Decision tree: (1) **App Service** (if web app/API — easiest path). Use App Service Migration Assistant for assessment. Deploy with deployment slots for blue/green. (2) **Azure Container Apps** (if you want containers without K8s). Containerize with Docker, deploy to Container Apps with Dapr for service communication. (3) **AKS** (if complex microservices architecture). Use Azure Migrate App Containerization tool to auto-containerize .NET apps. (4) **Azure Functions** (if event-driven/background processing). Refactor background workers to Functions. **For .NET Framework (legacy):** App Service supports .NET Framework on Windows. SQL Managed Instance supports legacy SQL features. This combination allows lift-and-shift of legacy .NET apps without code changes.

**Q18-Q25: Additional Migration & Operations Questions**

| # | Question | Key Points |
|---|----------|------------|
| 18 | How to migrate Oracle to Azure? | Oracle → Azure SQL MI (with conversion) or Azure DB for PostgreSQL. Azure Hybrid Benefit doesn't apply to Oracle |
| 19 | How to set up DR on Azure? | Azure Site Recovery (VM replication), Azure SQL auto-failover groups, Cosmos DB multi-region, Traffic Manager/Front Door failover |
| 20 | How to manage secrets on Azure? | Azure Key Vault (combines secrets + keys + certificates). AKS: CSI driver for Key Vault. App Service: Key Vault references |
| 21 | How to implement GitOps on AKS? | Flux v2 (managed GitOps add-on for AKS). ≈ ArgoCD but Azure-managed |
| 22 | How to handle Windows containers? | AKS has first-class Windows node pools. AWS EKS Windows support is more limited |
| 23 | What is Azure Spring Apps? | Managed VMware Tanzu — deploy Spring Boot apps without K8s ops. No AWS equivalent |
| 24 | How to modernize a monolith on Azure? | Strangler fig → extract to App Service/Functions/Container Apps. Use Service Bus for async messaging |
| 25 | How to handle large data migrations? | Azure Data Box (100TB/1PB). AzCopy for online. Data Factory for orchestrated transfers |

### Category 3: Scenario-Based & Comparison (Q26-Q50)

**Q26: A large bank uses Windows Server, SQL Server, and Active Directory. AWS or Azure?**

> **A:** **Azure wins decisively:** (1) Azure Hybrid Benefit saves 40-55% on Windows Server and SQL Server VMs (AWS charges full license cost). (2) Entra ID + AD Connect provides seamless SSO with existing Active Directory — same identity for Azure, O365, and on-prem. AWS has no Active Directory integration at this level. (3) SQL Managed Instance offers 100% SQL Server compatibility in PaaS (no AWS equivalent). (4) Microsoft Defender + Sentinel provides enterprise SIEM/SOC (AWS needs third-party SIEM). (5) Azure DevOps provides complete ALM platform for .NET teams. For a bank with 500 Windows/SQL Server VMs, Azure Hybrid Benefit alone could save **$500K+ per year** vs AWS.

**Q27: A startup needs to build an AI chatbot. AWS Bedrock or Azure OpenAI?**

> **A:** Depends on the model: (1) **Azure OpenAI if:** You specifically want GPT-4/GPT-4o (the market leader), need enterprise content filtering, need compliance certifications for LLM usage, or the organization already uses Azure. (2) **AWS Bedrock if:** You want model diversity (Claude, Llama, Mistral), need flexibility to switch models, prefer pay-per-token without provisioning, or already on AWS. **Architect's recommendation for a startup:** Start with Azure OpenAI (GPT-4o) for the strongest model capability. Add Azure AI Search for RAG. Use Azure API Management to expose the API. Total solution deployable in 1-2 weeks. If cost becomes a concern, switch to smaller/cheaper models via Azure OpenAI's model catalog.

**Q28-Q50: Rapid-Fire Q&A**

| # | Question | Azure Answer | AWS Comparison |
|---|----------|-------------|---------------|
| 28 | Best service for .NET web apps? | **App Service** (deployment slots, auto-heal, auth built-in) | Elastic Beanstalk (inferior) |
| 29 | How to do blue-green deployments? | App Service deployment slots / AKS + Flux / Container Apps traffic splitting | CodeDeploy / ArgoCD |
| 30 | How to handle DDoS? | Azure DDoS Protection Standard (auto on all public IPs) | Shield Standard (limited) + Shield Advanced ($3K/month) |
| 31 | How to manage multi-cloud? | **Azure Arc** (manage AWS, GCP, on-prem from Azure) | No equivalent |
| 32 | How to do IaC on Azure? | **Bicep** (Azure-native, simpler than ARM) or **Terraform** | CloudFormation or Terraform |
| 33 | How to queue messages? | Service Bus (enterprise messaging with sessions, FIFO, DLQ, transactions) | SQS (simpler) |
| 34 | How to handle event-driven? | Event Grid (events) + Functions (compute) + Service Bus (messaging) | EventBridge + Lambda + SQS |
| 35 | How to run Apache Spark? | Synapse Spark Pools or Azure Databricks | EMR |
| 36 | How to handle file storage (SMB)? | **Azure Files (SMB 3.0)** — native Windows file shares in the cloud | FSx for Windows (similar) |
| 37 | How to do API management? | **Azure API Management (APIM)** — policies, rate limiting, developer portal | API Gateway (less features) |
| 38 | Best SIEM for Azure? | **Microsoft Sentinel** — cloud SIEM + SOAR, KQL queries, 200+ connectors | No native SIEM |
| 39 | How to handle batch jobs? | Azure Batch (HPC) or Azure Functions (event-driven batch) | AWS Batch |
| 40 | How to handle IoT? | Azure IoT Hub + IoT Edge + Digital Twins | IoT Core + Greengrass |
| 41 | How to handle DevSecOps? | Defender for DevOps + GitHub Advanced Security + Azure Pipelines | CodeGuru + third-party |
| 42 | How to manage ML experiments? | Azure ML Studio (experiments, pipelines, model registry) | SageMaker Studio |
| 43 | How to handle graph databases? | Cosmos DB Gremlin API | Neptune |
| 44 | How to handle caching? | Azure Cache for Redis (Basic/Standard/Premium/Enterprise) | ElastiCache Redis |
| 45 | How to handle video streaming? | Azure Media Services + Azure CDN | MediaLive + CloudFront |
| 46 | How to handle static websites? | Azure Static Web Apps (integrated CI/CD, Functions backend) | Amplify Hosting |
| 47 | How to handle VDI/desktops? | **Azure Virtual Desktop** (multi-session Windows, FSLogix profiles) | WorkSpaces (single-session) |
| 48 | How to handle SAP? | SAP on Azure (certified, co-engineered, dedicated hardware) | SAP on AWS (certified) |
| 49 | How to handle compliance reporting? | Defender for Cloud regulatory compliance dashboard | Security Hub compliance |
| 50 | How to optimize reserved capacity? | Azure Advisor RI recommendations + Reservation utilization reports | Compute Optimizer + RI reports |

---

## Quick Reference — Azure Certification Path

| Certification | Level | Focus |
|--------------|-------|-------|
| **AZ-900** | Foundational | Azure Fundamentals |
| **AZ-104** | Associate | Azure Administrator |
| **AZ-204** | Associate | Azure Developer |
| **AZ-400** | Expert | Azure DevOps Engineer |
| **AZ-305** | Expert | **Azure Solutions Architect** |
| **AZ-500** | Associate | Azure Security Engineer |
| **AZ-700** | Associate | Azure Network Engineer |
| **DP-203** | Associate | Azure Data Engineer |
| **AI-102** | Associate | Azure AI Engineer |
| **AZ-140** | Associate | Azure Virtual Desktop |
| **SC-100** | Expert | Cybersecurity Architect |
| **SC-200** | Associate | Security Operations Analyst (Sentinel) |

---

**Built with precision by Pushparaj Naik** | Azure Cloud Architect Playbook
