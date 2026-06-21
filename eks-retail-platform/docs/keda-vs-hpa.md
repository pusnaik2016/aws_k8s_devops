# KEDA vs Native HPA — Autoscaling Decision Guide

## Overview

This platform uses **both** KEDA and native Kubernetes HPA to provide optimal autoscaling for different workload types. This document explains the decision criteria and implementation details.

## Decision Matrix

| Criteria | KEDA ScaledObject | Native HPA (K8s 1.36+) | Standard HPA |
|---|---|---|---|
| **Trigger Source** | SQS, SNS, Kafka, custom | External metrics, resource metrics | CPU/Memory only |
| **Scale to Zero** | ✅ Built-in | ✅ HPAScaleToZero feature gate | ❌ min >= 1 |
| **Queue-Based** | ✅ Best fit | ⚠️ Possible but complex | ❌ Not designed for |
| **HTTP/RPS-Based** | ⚠️ Works but overkill | ✅ Best fit | ⚠️ Indirect via CPU |
| **Operational Overhead** | CRDs + KEDA Operator | Native (no extra components) | Native |
| **AWS Integration** | Built-in SQS/SNS scalers | Requires metrics adapter | N/A |

## Our Implementation

### KEDA-Managed Services (Event-Driven)

#### order-service
```yaml
# Trigger: SQS FIFO Queue (order-queue.fifo)
# Why KEDA: Direct SQS integration, no metrics pipeline needed
# Scaling: 0 → 20 pods, 1 pod per 5 messages
triggers:
  - type: aws-sqs-queue
    metadata:
      queueLength: "5"  # Target messages per pod
```

**Why not HPA?** HPA can't natively poll SQS queue depth. You'd need a custom metrics adapter (Prometheus + CloudWatch exporter) just to expose the metric. KEDA has a built-in SQS scaler that handles this directly.

#### notification-service
```yaml
# Trigger: SQS Standard Queue (notification-queue)
# Why KEDA: Same as order-service — direct SQS integration
# Scaling: 0 → 10 pods, 1 pod per 10 messages
```

### Native HPA Services (Metric-Driven)

#### storefront-api
```yaml
# Trigger: External metric (http_requests_per_second)
# Why HPA: Simple metric threshold, no queue semantics
# Scaling: 0 → 15 pods, target 100 RPS per pod
# K8s 1.36+: HPAScaleToZero feature gate (stable)
metrics:
  - type: External
    external:
      metric:
        name: http_requests_per_second
```

**Why not KEDA?** There's no event queue involved. The scaling trigger is a simple Prometheus metric (HTTP RPS). Using KEDA for this would add unnecessary complexity — a native HPA with an external metric is simpler and has zero extra dependencies.

#### inventory-service
```yaml
# Same pattern as storefront-api
# Scaling: 0 → 10, target 50 RPS
```

### Standard HPA (Always-On)

#### payment-service
```yaml
# Trigger: CPU + Memory utilization
# Why Standard HPA: PCI-DSS requires minimum 2 replicas
# NEVER scales to zero — payment processing must be always-available
minReplicas: 2  # PCI compliance
maxReplicas: 10
metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        averageUtilization: 60
```

**Why not KEDA or scale-to-zero HPA?** PCI-DSS requires payment processing to be always available. Scale-to-zero introduces cold-start latency that's unacceptable for payment flows.

## Scale-to-Zero Comparison

### KEDA Scale-to-Zero
- Built into ScaledObject (`minReplicaCount: 0`)
- Manages its own HPA internally
- Polling interval determines wake-up latency (15-30s)
- No feature gates required

### Native HPA Scale-to-Zero (K8s 1.36+)
- Requires `HPAScaleToZero` feature gate (stable since 1.36)
- Works with any metric type (External, Object, Pods)
- No additional CRDs or operators needed
- Lower operational overhead

## When to Add New Services

```
New Service Needed?
      │
      ├── Does it consume from a message queue (SQS/SNS/Kafka)?
      │   └── YES → Use KEDA ScaledObject
      │
      ├── Does it need to scale on HTTP traffic or custom metrics?
      │   └── YES → Use Native HPA (with External metric)
      │
      ├── Must it always be running (compliance/SLA)?
      │   └── YES → Use Standard HPA (minReplicas >= 2)
      │
      └── Simple CPU/memory scaling?
          └── YES → Use Standard HPA
```

## Configuration Reference

| Parameter | KEDA Default | HPA Default | Notes |
|---|---|---|---|
| `pollingInterval` | 15s | N/A | How often KEDA checks trigger |
| `cooldownPeriod` | 60s | N/A | Wait before scaling to zero |
| `stabilizationWindowSeconds` | N/A | 120s (down), 0s (up) | Prevents flapping |
| `scaleDown.policies.percent` | 25%/60s | 25%/60s | Gradual scale-down |
| `scaleUp.policies.percent` | 100%/15s | 100%/15s | Aggressive scale-up |
