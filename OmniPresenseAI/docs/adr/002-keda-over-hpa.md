# ADR-002: KEDA over Standard HPA for Analytics Scaling

| Field | Value |
|-------|-------|
| **Status** | Accepted |
| **Date** | 2024-01-18 |
| **Decision Makers** | Pushparaj Naik |

---

## Context

The analytics-service processes chat messages asynchronously — performing sentiment analysis and archiving transcripts. Messages are queued in Redis after each chat conversation. We need an autoscaling strategy that responds to **queue depth** rather than pod CPU/memory utilization.

Two options were evaluated:
1. **Standard Kubernetes HPA** (Horizontal Pod Autoscaler)
2. **KEDA** (Kubernetes Event-Driven Autoscaler)

---

## Decision

We chose **KEDA** for the analytics-service autoscaling, while retaining **standard HPA** for the chat-service.

---

## Rationale

### 1. Event-Driven Scaling vs. Resource-Based Scaling

| Aspect | HPA | KEDA |
|--------|-----|------|
| Scale trigger | CPU/Memory utilization | Any event source (Redis, SQS, etc.) |
| Scale to zero | ❌ Minimum 1 replica | ✅ Supports scale-to-zero |
| Queue awareness | ❌ No built-in support | ✅ Native Redis list length trigger |
| Custom metrics | Requires Prometheus adapter | Built-in 50+ scalers |

The analytics workload is **bursty** — no messages during quiet periods, spikes after busy chat sessions. HPA would either:
- Keep pods running at minimum (wasting resources), or
- React slowly because CPU stays low until queue is already large

KEDA directly monitors `analytics:queue` Redis list length and scales immediately.

### 2. Scale-to-Zero Cost Savings

```
Analytics pod (idle): ~250m CPU, 512Mi memory
Hours idle per day (estimated): 8-12 hours
Monthly savings with scale-to-zero: ~$15-25/mo
```

For a cost-conscious deployment, KEDA's scale-to-zero capability means we only pay for analytics compute when there's actual work to do.

### 3. Configuration Simplicity

**KEDA ScaledObject** (what we use):
```yaml
triggers:
  - type: redis
    metadata:
      address: redis:6379
      listName: analytics:queue
      listLength: "5"  # Scale up when > 5 messages queued
```

**HPA with Custom Metrics** (alternative):
- Requires deploying Prometheus
- Requires Prometheus Adapter
- Requires custom metric registration
- More moving parts to maintain

### 4. Why HPA for Chat Service

The chat-service is different:
- Always needs at least 2 replicas (availability)
- CPU-bound during Bedrock API calls
- Scales with concurrent connections, which correlates with CPU

Standard HPA on CPU utilization is the right fit for chat-service.

---

## Trade-offs Accepted

- **Additional dependency:** KEDA controller must be deployed to the cluster (Helm chart)
- **Complexity:** One more component to monitor and upgrade
- **Cold start:** Scale-from-zero adds ~10-15 seconds for first analytics request
- **KEDA version management:** Must track KEDA releases for security patches

---

## Consequences

- KEDA deployed via Helm in `scripts/setup-kubeconfig.sh`
- `ScaledObject` manifest in `k8s/base/keda/scaledobject.yaml`
- Analytics-service can scale 0-5 replicas based on Redis queue depth
- Chat-service uses standard HPA (CPU-based, 2-10 replicas)
- Queue threshold set to 5 messages to trigger scale-up
- Cool-down period of 300 seconds to prevent flapping
