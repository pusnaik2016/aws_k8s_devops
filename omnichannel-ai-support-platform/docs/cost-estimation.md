# Cost Estimation — OmniPresenseAI

> Detailed AWS cost breakdown for the Omnichannel AI-Powered Customer Support & Analytics Platform.

---

## Table of Contents

1. [Production Cost Summary](#production-cost-summary)
2. [Per-Service Breakdown](#per-service-breakdown)
3. [Staging vs. Production](#staging-vs-production)
4. [Cost Optimization Strategies](#cost-optimization-strategies)
5. [Scaling Cost Projections](#scaling-cost-projections)

---

## Production Cost Summary

| Service | Monthly Estimate | % of Total | Notes |
|---------|-----------------|------------|-------|
| EKS Control Plane | $73 | 13% | Fixed cost |
| EC2 Instances (2× m6g.large) | $140 | 24% | Graviton, On-Demand |
| Aurora Serverless v2 | $90 | 16% | 0.5–4 ACU |
| ElastiCache Redis | $48 | 8% | r6g.large single node |
| Amazon Bedrock | $50–200 | 9–35% | Usage dependent |
| CloudFront + S3 | $15 | 3% | Static assets + data |
| API Gateway | $10 | 2% | WebSocket + REST |
| NAT Gateway | $32 | 6% | Single AZ |
| Other (KMS, CloudWatch, Route53) | $20 | 3% | Monitoring, DNS, keys |
| **Total** | **$478–628/mo** | **100%** | |

---

## Per-Service Breakdown

### Amazon EKS — $73/mo

| Item | Cost |
|------|------|
| EKS cluster (control plane) | $73/mo (fixed) |

### EC2 (EKS Worker Nodes) — $140/mo

| Item | Quantity | Unit Price | Monthly |
|------|----------|-----------|---------|
| m6g.large (Graviton, 2 vCPU, 8 GiB) | 2 | $0.0770/hr | $55.44 each |
| EBS gp3 (20 GiB root volume) | 2 | $0.08/GiB/mo | $1.60 each |
| **Subtotal** | | | **$114.08** |

> HPA can scale to 10 nodes. At max scale: ~$570/mo for EC2 alone.

### Aurora Serverless v2 — $90/mo

| Item | Quantity | Unit Price | Monthly |
|------|----------|-----------|---------|
| Aurora ACU hours (avg 1 ACU) | 730 hrs | $0.12/ACU-hr | $87.60 |
| Storage (10 GiB estimated) | 10 GiB | $0.10/GiB/mo | $1.00 |
| I/O (1M requests) | 1M | $0.20/1M | $0.20 |
| **Subtotal** | | | **$88.80** |

> Scales 0.5–4 ACU automatically. Peak usage (4 ACU): ~$350/mo.

### ElastiCache Redis — $48/mo

| Item | Quantity | Unit Price | Monthly |
|------|----------|-----------|---------|
| r6g.large (2 vCPU, 13.07 GiB) | 1 node | $0.066/hr | $48.18 |

> Single node for cost efficiency. For HA, add replica: ~$96/mo.

### Amazon Bedrock — $50–200/mo

| Model | Input Tokens | Output Tokens | Estimated |
|-------|-------------|---------------|-----------|
| Claude 3.5 Sonnet (chat) | $3.00/1M tokens | $15.00/1M tokens | $40–150/mo |
| Titan Embeddings v2 (RAG) | $0.02/1M tokens | — | $10–50/mo |

> Based on ~10,000 conversations/month, avg 500 tokens/conversation.

### CloudFront + S3 — $15/mo

| Item | Quantity | Unit Price | Monthly |
|------|----------|-----------|---------|
| CloudFront data transfer | 50 GiB | $0.085/GiB | $4.25 |
| CloudFront requests | 1M | $0.0100/10K | $1.00 |
| S3 Standard (frontend) | 1 GiB | $0.023/GiB | $0.02 |
| S3 Standard (data lake) | 10 GiB | $0.023/GiB | $0.23 |
| S3 requests | 100K | $0.005/1K | $0.50 |
| **Subtotal** | | | **~$6.00** |

### API Gateway — $10/mo

| Item | Quantity | Unit Price | Monthly |
|------|----------|-----------|---------|
| WebSocket messages | 1M | $1.00/1M | $1.00 |
| WebSocket connection mins | 500K | $0.25/1M | $0.13 |
| HTTP API requests | 5M | $1.00/1M | $5.00 |
| **Subtotal** | | | **~$6.13** |

### NAT Gateway — $32/mo

| Item | Quantity | Unit Price | Monthly |
|------|----------|-----------|---------|
| NAT Gateway (hourly) | 730 hrs | $0.045/hr | $32.85 |
| Data processing | 10 GiB | $0.045/GiB | $0.45 |
| **Subtotal** | | | **~$33.30** |

### Other Services — $20/mo

| Item | Monthly |
|------|---------|
| KMS (3 keys) | $3.00 |
| KMS API calls | $0.50 |
| CloudWatch Logs (10 GiB) | $5.00 |
| CloudWatch Metrics (custom) | $3.00 |
| Route 53 Hosted Zone | $0.50 |
| Route 53 Queries (1M) | $0.40 |
| SSM Parameter Store | $0.00 (free tier) |
| **Subtotal** | **~$12.40** |

---

## Staging vs. Production

| Resource | Staging | Production | Savings |
|----------|---------|------------|---------|
| EKS Control Plane | $73 | $73 | — |
| EC2 Nodes | $35 (1× t3.medium) | $140 (2× m6g.large) | 75% |
| Aurora | $45 (0.5–2 ACU) | $90 (0.5–4 ACU) | 50% |
| Redis | $18 (cache.t3.medium) | $48 (r6g.large) | 63% |
| NAT Gateway | $33 | $33 | — |
| Bedrock | $10 (minimal testing) | $50–200 | 80%+ |
| CloudFront | $5 | $15 | 67% |
| **Total** | **~$219/mo** | **~$478–628/mo** | **55–65%** |

---

## Cost Optimization Strategies

### Immediate Savings (No Architecture Change)

| Strategy | Savings | Implementation |
|----------|---------|----------------|
| **Graviton instances** | ~20% vs x86 | ✅ Already using m6g.large |
| **Single NAT Gateway** | ~$66/mo | ✅ Already single AZ |
| **Aurora Serverless v2** | Variable | ✅ Scales to zero ACU on idle |
| **S3 Lifecycle policies** | ~$5/mo | ✅ Standard → IA → Glacier |
| **Redis response caching** | 30–50% Bedrock cost | ✅ Implemented in chat-service |

### Medium-Term Optimizations

| Strategy | Potential Savings | Effort |
|----------|-------------------|--------|
| **EC2 Savings Plans (1yr)** | ~30% on compute | Low — commit to usage |
| **Reserved ElastiCache** | ~30% on Redis | Low — 1yr reservation |
| **Spot Instances for non-critical** | ~60% on analytics nodes | Medium — add Spot node group |
| **Bedrock caching layer** | 20–40% on LLM costs | Medium — extend cache TTLs |

### Long-Term Optimizations

| Strategy | Potential Savings | Effort |
|----------|-------------------|--------|
| **Fargate for analytics** | Pay-per-use vs always-on | High — architecture change |
| **Multi-region NAT sharing** | ~$33/mo per region | Medium — VPC peering |
| **Reserved Aurora capacity** | ~30% if steady-state | Low — commit when predictable |

### Cost Alerts

```bash
# Set up AWS Budget alert
aws budgets create-budget \
  --account-id <ACCOUNT_ID> \
  --budget '{
    "BudgetName": "OmniPresenseAI-Monthly",
    "BudgetLimit": {"Amount": "700", "Unit": "USD"},
    "BudgetType": "COST",
    "TimeUnit": "MONTHLY"
  }' \
  --notifications-with-subscribers '[{
    "Notification": {
      "NotificationType": "ACTUAL",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": 80
    },
    "Subscribers": [{"SubscriptionType": "EMAIL", "Address": "team@example.com"}]
  }]'
```

---

## Scaling Cost Projections

### By Conversation Volume

| Monthly Conversations | EC2 Nodes | Aurora ACU | Bedrock Cost | Total Est. |
|----------------------|-----------|-----------|--------------|------------|
| 5,000 | 2 | 0.5–1 | $25 | ~$400/mo |
| 10,000 | 2 | 1–2 | $75 | ~$530/mo |
| 50,000 | 4 | 2–4 | $350 | ~$950/mo |
| 100,000 | 6 | 4–8 | $700 | ~$1,500/mo |
| 500,000 | 10 | 8–16 | $3,500 | ~$5,000/mo |

> Bedrock costs dominate at scale. Consider provisioned throughput pricing for > 100K conversations.
