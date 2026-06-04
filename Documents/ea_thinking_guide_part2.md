# Enterprise Architect Thinking Guide — Part 2

**Focus:** Migration Risks, Dependency Management, Cutover Checklist

---

## Question 3: What Can Go Wrong in Migration? How Do You Handle It?

### The EA Mindset

> *"An experienced EA doesn't hope for the best — they plan for the worst. Every migration has risks. The difference between success and failure is whether you identified them BEFORE they became problems."*

---

### Migration Risk Registry — 12 Real-World Failure Patterns

#### Category A: Technical Risks

| # | What Goes Wrong | Root Cause | How I Prevent It |
|---|---|---|---|
| 1 | **Application breaks after lift-and-shift** | Hidden dependencies on hostname, IP address, local file paths, or hardcoded endpoints | **Discovery phase:** Run dependency mapping (Application Discovery Service). Document every server-to-server connection. Test in staging environment that mirrors cloud networking. |
| 2 | **Database migration data loss or corruption** | Large databases timeout during migration, CDC lag not monitored, character encoding mismatches | **Use AWS DMS with CDC.** Full load + continuous replication. Run data validation scripts (row count, checksum, business-rule checks) BEFORE cutover. Always have rollback window. |
| 3 | **Performance degradation after migration** | Wrong instance sizing, different storage IOPS profile (SAN → EBS), network latency between tiers that were previously co-located | **Right-sizing ≠ same-sizing.** Use actual utilization data, not nameplate capacity. Run performance benchmarks in cloud BEFORE cutover. Use provisioned IOPS EBS where needed. |
| 4 | **DNS/Network connectivity failures at cutover** | DNS TTL not lowered in advance, firewall rules incomplete, VPN/Direct Connect not tested under load | **Lower DNS TTL to 60 seconds 48 hours before cutover.** Test all network paths in advance. Have a network engineer on the bridge during cutover. |
| 5 | **License compliance violations** | Oracle/SQL Server licensing doesn't transfer to cloud the same way, bringing BYOL to wrong instance types | **License audit during discovery phase.** Engage vendor licensing specialist. Understand BYOL rules per cloud provider. Consider license-included or open-source alternatives (Oracle → Aurora PostgreSQL). |

#### Category B: Organizational Risks

| # | What Goes Wrong | Root Cause | How I Prevent It |
|---|---|---|---|
| 6 | **Team skill gap causes delays** | Engineers unfamiliar with cloud networking, IAM, or IaC — every task takes 3x longer | **Invest in training BEFORE migration starts.** Embed cloud-experienced engineers (AWS ProServ or partner) for Wave 1. Knowledge transfer is explicit deliverable. |
| 7 | **Application owners unavailable for testing** | Business teams don't prioritize UAT, or key person is on leave during cutover window | **Book UAT windows 6 weeks in advance.** Get named testers with backup. UAT is a GATE — no sign-off = no cutover. Include in project RACI. |
| 8 | **Scope creep — "while we're migrating, let's also..."** | Stakeholders add modernization, refactoring, or feature requests mid-migration | **Hard boundary:** Migration is migration. Modernization is Phase 2. Mixing them doubles timeline and risk. Document this in the SOW. |

#### Category C: Cost Risks

| # | What Goes Wrong | Root Cause | How I Prevent It |
|---|---|---|---|
| 9 | **Cloud costs 2-3x higher than estimated** | Lifted same-sized servers without right-sizing, forgot data transfer costs, NAT Gateway charges, unused resources after migration | **Right-size based on utilization data (not spec).** Budget for data transfer (egress during migration period). Set up AWS Budgets and Cost Anomaly Detection from Day 1. Monthly FinOps review. |
| 10 | **Dual-run costs exceed budget** | Running both on-prem and cloud simultaneously during migration takes longer than planned | **Plan for 3-month dual-run buffer in budget.** Decommission migrated on-prem servers within 30 days of successful cutover. Track dual-run cost weekly. |

#### Category D: Security & Compliance Risks

| # | What Goes Wrong | Root Cause | How I Prevent It |
|---|---|---|---|
| 11 | **Security posture weaker in cloud than on-prem** | Security team not involved early, default VPC used, overprivileged IAM roles, no encryption | **Security architect involved from Day 1.** Landing zone includes: private subnets, no public access, KMS encryption mandatory, least-privilege IAM, GuardDuty + Config enabled. Security is pre-requisite, not afterthought. |
| 12 | **Regulatory non-compliance post-migration** | Data moved to non-approved region, audit logs not configured, retention policies not applied | **Compliance checklist as migration gate.** Verify data residency, encryption, audit logging, retention policies BEFORE each wave cutover. Security Hub compliance dashboard from Day 1. |

---

### How I Handle Issues When They Occur

**Triage Framework:**

```
Issue Detected
│
├── Severity? (Critical / High / Medium / Low)
│
├── Can we fix it within the cutover window?
│   ├── YES → Fix, retest, proceed
│   └── NO → Rollback to on-prem, schedule retry
│
├── Is it a pattern that will affect future waves?
│   ├── YES → Root cause analysis, update migration playbook
│   └── NO → Isolated issue, document and move on
│
└── Communication
    ├── SEV1/2 → Immediate stakeholder notification
    └── SEV3/4 → Include in weekly status report
```

**Real Example from My Experience:**

> *At Advantest, during the GLP application migration to AWS, we discovered that the application had hardcoded internal DNS names that didn't resolve in the cloud VPC. We caught this during staging testing (not production cutover) because we had mandated a full regression cycle in the cloud environment before cutover. Fix: Route 53 private hosted zone with the same DNS names pointing to cloud resources. Lesson: Always test name resolution end-to-end.*

---

## Question 4: How Do You Ensure Timelines When You Have External Dependencies?

### The EA Mindset

> *"As an EA, I don't just manage MY team's timeline — I manage the critical path across ALL teams. Dependencies are the #1 cause of enterprise project delays. My job is to identify them early, track them relentlessly, and escalate before they become blockers."*

---

### Dependency Management Framework

#### Step 1: Dependency Mapping (During Planning Phase)

| Dependency | Owner | Lead Time | Risk Level | Mitigation |
|---|---|---|---|---|
| **VPN/Direct Connect provisioning** | Network Team | 6-8 weeks | HIGH | Order in Week 1 of project, not Week 6 |
| **Firewall rule changes** | Network Security | 2-3 weeks per request | MEDIUM | Batch all rules for a wave into one change request |
| **SSL certificate provisioning** | Security Team | 1-2 weeks | LOW | Use ACM (free, auto-renewing) instead of manual certs |
| **DNS zone delegation** | Network Team | 1-2 weeks | MEDIUM | Request early, test in staging first |
| **Compliance sign-off** | GRC Team | 4-6 weeks | HIGH | Engage in Week 1, provide documentation template upfront |
| **AWS SES production access** | AWS | 2-4 weeks | MEDIUM | Apply early, use SNS as fallback for critical alerts |
| **AWS account limits increase** | AWS Support | 1-3 days (with Enterprise Support) | LOW | Request before Wave 1, not during |
| **Penetration testing approval** | Security + AWS | 2-3 weeks | MEDIUM | Schedule 4 weeks before go-live |

#### Step 2: Critical Path Management

```
Week 1-2: Foundation Phase
  ├── [CRITICAL PATH] Order Direct Connect / VPN ← 6-8 week lead time
  ├── [CRITICAL PATH] Submit compliance documentation to GRC ← 4-6 weeks
  ├── Request AWS SES production access ← 2-4 weeks
  ├── Request account service limit increases
  └── Set up landing zone (parallel — no dependencies)

Week 3-6: Build Phase
  ├── Terraform modules, CI/CD pipelines (no dependencies)
  ├── [TRACK] VPN/DC provisioning status — weekly check-in with network team
  ├── [TRACK] GRC compliance review progress
  └── Security architecture review (engage security team)

Week 7-8: Integration Phase
  ├── [GATE] VPN/Direct Connect must be live ← If not, escalate to CTO
  ├── End-to-end connectivity testing
  └── Firewall rules validation

Week 9+: Migration Waves
  ├── [GATE] Compliance sign-off must be received ← If not, delay wave
  └── Execute with tested, validated dependencies
```

#### Step 3: RAID Log (Risks, Assumptions, Issues, Dependencies)

I maintain a **live RAID log** reviewed in every weekly steering committee:

| ID | Type | Description | Owner | Due Date | Status | Escalation |
|---|---|---|---|---|---|---|
| D-001 | Dependency | Direct Connect provisioning | Network Lead | Week 6 | 🟡 In Progress | Escalate if not ordered by Week 2 |
| D-002 | Dependency | GRC compliance sign-off | Compliance Manager | Week 8 | 🔴 At Risk | Meeting scheduled with GRC VP |
| R-003 | Risk | AWS SES production approval delay | Cloud Team | Week 4 | 🟢 On Track | Fallback: use SNS for alerts |
| D-004 | Dependency | Firewall rules for Wave 1 | Network Security | Week 7 | 🟡 Submitted | Follow up if no response by Week 5 |

#### Step 4: Specific Dependency Handling Strategies

**Networking Team Delays:**

- **Prevention:** Include network team in kickoff meeting, present FULL list of requirements upfront (all VPN tunnels, all firewall rules, all DNS changes for ALL waves)
- **Escalation path:** If network work is > 1 week late → escalate to Infrastructure VP with impact statement: "Migration Wave 1 will slip by 2 weeks, affecting $X in delayed savings"
- **Workaround:** For development/testing, use AWS Site-to-Site VPN (can be provisioned in hours) while waiting for Direct Connect

**Compliance/Regulation Team Delays:**

- **Prevention:** Provide a pre-filled compliance template with all answers ready — make their job easy
- **Parallel processing:** Request conditional approval for non-production waves while full approval is pending
- **Escalation:** Frame as business risk — "Without compliance sign-off by date X, we miss the data center lease deadline, committing to $2.4M/year"

**AWS Service Delays (SES, limit increases, etc.):**

- **Prevention:** Submit all service requests in Week 1 — don't wait until you need them
- **Enterprise Support:** Use the TAM (Technical Account Manager) to expedite requests
- **Workaround:** Always have a Plan B:
  - SES delayed → Use SNS for alerts, SES for non-critical email
  - Limit increase delayed → Deploy across multiple accounts to stay within limits
  - Support case slow → Escalate through TAM or AWS account team

---

### How I'd Answer in an Interview

> *"Dependencies are the silent killer of enterprise projects. My approach is aggressive early action — I identify ALL cross-team dependencies in Week 1 and start the longest-lead items immediately, before we write a single line of Terraform. I maintain a RAID log reviewed weekly with stakeholders, and I escalate dependencies at risk BEFORE they become blockers, not after. The key is framing escalations in business impact terms — 'this delay costs us $X per week' — not technical terms."*

---

## Question 5: Cutover / Go-Live Checklist

### The EA Mindset

> *"A successful cutover is boring. It's boring because you've rehearsed it, tested it, and documented every step. Excitement during cutover means something went wrong."*

---

### Pre-Cutover Checklist (T-2 Weeks)

#### ✅ Phase 1: Infrastructure Readiness

| # | Check | Owner | Status |
|---|---|---|---|
| 1 | All target infrastructure provisioned and tested | Cloud Team | ☐ |
| 2 | Network connectivity verified (VPN/DC, all ports, all directions) | Network Team | ☐ |
| 3 | DNS entries prepared (not yet switched) | Network Team | ☐ |
| 4 | DNS TTL lowered to 60 seconds (48 hours before cutover) | Network Team | ☐ |
| 5 | Load balancers configured and health checks passing | Cloud Team | ☐ |
| 6 | Auto-scaling policies configured and tested | Cloud Team | ☐ |
| 7 | Backup and snapshot schedules configured | Cloud Team | ☐ |
| 8 | DR/failover tested (if applicable) | Cloud + SRE | ☐ |

#### ✅ Phase 2: Data Migration Readiness

| # | Check | Owner | Status |
|---|---|---|---|
| 9 | Full data load completed | DBA Team | ☐ |
| 10 | CDC replication running and lag < 5 seconds | DBA Team | ☐ |
| 11 | Data validation passed (row counts, checksums, business rules) | DBA + App Team | ☐ |
| 12 | Database performance benchmarks match or exceed source | DBA Team | ☐ |
| 13 | Rollback procedure tested (can we revert to source DB?) | DBA Team | ☐ |

#### ✅ Phase 3: Application Readiness

| # | Check | Owner | Status |
|---|---|---|---|
| 14 | Application deployed and running in cloud | Dev Team | ☐ |
| 15 | Configuration updated for cloud endpoints (DB, cache, queues) | Dev Team | ☐ |
| 16 | UAT sign-off received from business stakeholders | App Owner | ☐ |
| 17 | Performance/load test passed in cloud environment | QA Team | ☐ |
| 18 | Integration tests passed (all upstream/downstream connections) | Dev + QA | ☐ |
| 19 | SSL certificates installed and verified | Security | ☐ |

#### ✅ Phase 4: Security Sign-Off

| # | Check | Owner | Status |
|---|---|---|---|
| 20 | Security group rules reviewed and approved | Security Team | ☐ |
| 21 | IAM roles follow least-privilege principle | Security Team | ☐ |
| 22 | Encryption at rest enabled (all storage, databases) | Cloud Team | ☐ |
| 23 | Encryption in transit enabled (TLS 1.2+) | Cloud Team | ☐ |
| 24 | Vulnerability scan completed, no CRITICAL findings | Security Team | ☐ |
| 25 | Compliance sign-off received | GRC Team | ☐ |
| 26 | Penetration test completed (if required) | Security Team | ☐ |

#### ✅ Phase 5: Monitoring & Observability

| # | Check | Owner | Status |
|---|---|---|---|
| 27 | CloudWatch alarms configured for all critical metrics | SRE Team | ☐ |
| 28 | Dashboards created (infrastructure + application) | SRE Team | ☐ |
| 29 | Log aggregation working (application + access + audit logs) | SRE Team | ☐ |
| 30 | Alerting pipeline tested (alarm → SNS → PagerDuty/Slack) | SRE Team | ☐ |
| 31 | On-call schedule configured for post-cutover support | SRE Lead | ☐ |

#### ✅ Phase 6: Communication & Stakeholders

| # | Check | Owner | Status |
|---|---|---|---|
| 32 | Cutover plan distributed to all stakeholders | Project Manager | ☐ |
| 33 | War room / bridge dial-in details shared | Project Manager | ☐ |
| 34 | Business communication sent (maintenance window notice) | Comms Team | ☐ |
| 35 | Rollback decision criteria documented and agreed | EA + App Owner | ☐ |
| 36 | Post-cutover support plan communicated | SRE Lead | ☐ |

#### ✅ Phase 7: Rollback Readiness

| # | Check | Owner | Status |
|---|---|---|---|
| 37 | Rollback procedure documented step-by-step | Cloud Team | ☐ |
| 38 | Rollback tested in staging/DR environment | Cloud + DBA | ☐ |
| 39 | Rollback decision point defined (T+2 hours, T+4 hours) | EA | ☐ |
| 40 | On-prem environment kept running during hypercare period | Ops Team | ☐ |

---

### Go / No-Go Decision Matrix

**Decision meeting: T-24 hours before cutover**

| Criterion | Go | No-Go |
|---|---|---|
| UAT sign-off | ✅ Received | ❌ Not received |
| Data validation | ✅ All checks passed | ❌ Discrepancies found |
| Performance test | ✅ Meets or exceeds baseline | ❌ Degradation > 20% |
| Security scan | ✅ No CRITICAL findings | ❌ Open CRITICAL findings |
| Network connectivity | ✅ All paths tested | ❌ Any path untested |
| Rollback plan | ✅ Tested and documented | ❌ Not tested |
| Key personnel available | ✅ All on-call confirmed | ❌ Key person unavailable |
| Business calendar | ✅ No conflicting events | ❌ Month-end, peak season |

**Decision authority:** The EA recommends, but the **Application Owner** (business) makes the final Go/No-Go call. This is documented in the cutover minutes.

---

### Cutover Night Execution Timeline (Example)

```
Friday 10:00 PM — Cutover begins
  ├── 10:00 PM: War room opens, roll call of all teams
  ├── 10:15 PM: Stop application writes to source database
  ├── 10:20 PM: Verify DMS CDC lag = 0 (all data replicated)
  ├── 10:30 PM: Run data validation scripts (row counts, checksums)
  ├── 10:45 PM: Switch application config to cloud database endpoint
  ├── 11:00 PM: Deploy application to cloud (or enable traffic to cloud)
  ├── 11:15 PM: Switch DNS to cloud load balancer
  ├── 11:30 PM: Smoke tests (critical user journeys)
  ├── 11:45 PM: Monitoring check (all dashboards green?)
  │
  ├── DECISION POINT (midnight):
  │   ├── All green → Proceed → Notify stakeholders "cutover successful"
  │   └── Issues found → Evaluate:
  │       ├── Fixable in < 1 hour → Fix, retest
  │       └── Not fixable → ROLLBACK: switch DNS back, re-enable source DB
  │
Saturday 12:00 AM - 8:00 AM — Hypercare monitoring
  ├── Engineer on-call monitoring all dashboards
  ├── Hourly status updates to war room
  └── 8:00 AM: Morning standup — confirm stable
  
Monday 9:00 AM — Business validation
  └── Business users confirm application working normally
  └── Post-cutover sign-off
```

---
