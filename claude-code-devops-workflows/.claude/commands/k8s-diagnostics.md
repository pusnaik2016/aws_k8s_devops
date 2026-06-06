# /k8s-diagnostics — Kubernetes Manifest Diagnostics

## Usage
```
/k8s-diagnostics $ARGUMENTS
```
Where `$ARGUMENTS` is the path to a directory containing Kubernetes manifests.
Defaults to scanning all `k8s/` directories in the repository.

## Instructions

You are acting as a **Kubernetes Platform Engineer** performing a
comprehensive diagnostic review of Kubernetes manifests for production readiness.

### Step 1: Discover Manifest Files
Find all Kubernetes YAML manifests:
```bash
find ${ARGUMENTS:-.} -name "*.yaml" -o -name "*.yml" | grep -v node_modules | grep -v .terraform
```

### Step 2: Run K8s Helper Diagnostics
Execute the automated diagnostics:
```bash
python3 scripts/k8s_helper.py --path ${ARGUMENTS:-.} --format markdown
```

### Step 3: Workload Security Analysis
For each Deployment, StatefulSet, DaemonSet, and Job manifest, verify:

**Security Context:**
- [ ] `securityContext.runAsNonRoot: true`
- [ ] `securityContext.readOnlyRootFilesystem: true`
- [ ] `securityContext.allowPrivilegeEscalation: false`
- [ ] `securityContext.capabilities.drop: ["ALL"]`
- [ ] No `privileged: true`
- [ ] No `hostNetwork: true`, `hostPID: true`, or `hostIPC: true`

**Resource Management:**
- [ ] `resources.requests.cpu` defined
- [ ] `resources.requests.memory` defined
- [ ] `resources.limits.cpu` defined
- [ ] `resources.limits.memory` defined
- [ ] Limits are reasonable (not excessively large)

**Health Checks:**
- [ ] `readinessProbe` configured
- [ ] `livenessProbe` configured
- [ ] `startupProbe` configured (for slow-starting apps)
- [ ] Probe endpoints are different from application endpoints
- [ ] Failure thresholds are reasonable

**Image Security:**
- [ ] Image tags are specific (no `:latest`)
- [ ] `imagePullPolicy: IfNotPresent` or `Always` (not Never in prod)
- [ ] Private registry credentials configured if needed

### Step 4: Service & Networking Review
- [ ] Services use appropriate type (`ClusterIP`, `NodePort`, `LoadBalancer`)
- [ ] Ingress has TLS configuration
- [ ] Ingress annotations are correct for the ingress controller
- [ ] Network policies exist for each namespace
- [ ] Network policies allow only required traffic

### Step 5: Configuration & Secrets
- [ ] ConfigMaps used for non-sensitive configuration
- [ ] Secrets used for sensitive data (not ConfigMaps)
- [ ] External Secrets Operator used for production secrets
- [ ] No plaintext secrets in YAML files

### Step 6: High Availability & Reliability
- [ ] `PodDisruptionBudget` defined for critical workloads
- [ ] `HorizontalPodAutoscaler` configured where appropriate
- [ ] Replica count >= 2 for production workloads
- [ ] Pod anti-affinity rules for spread across nodes
- [ ] `topologySpreadConstraints` defined

### Step 7: RBAC Review
- [ ] ServiceAccounts defined per workload (not `default`)
- [ ] Roles/ClusterRoles follow least-privilege
- [ ] RoleBindings scoped to specific namespaces
- [ ] `automountServiceAccountToken: false` unless needed

### Step 8: Generate Report
```markdown
## 🎯 Kubernetes Diagnostics Report
**Scan Date:** [current date/time]
**Scope:** [directories scanned]
**Manifests Analyzed:** [count]

### 📦 Workload Summary
| Workload           | Kind        | Replicas | Resources | Probes | Security | Status |
|-------------------|-------------|----------|-----------|--------|----------|--------|
| [name]            | Deployment  | N        | ✅/❌     | ✅/❌  | ✅/❌   | PASS/FAIL |

### 🔐 Security Assessment
[Security context findings for each workload]

### 🌐 Networking Assessment
[Service, Ingress, and NetworkPolicy findings]

### 📈 Scalability & HA
[HPA, PDB, and replica findings]

### 🔑 RBAC Assessment
[ServiceAccount and role findings]

### 📊 Summary
| Category         | Checks | Passed | Warnings | Critical |
|-----------------|--------|--------|----------|----------|
| Security         | N      | N      | N        | N        |
| Resources        | N      | N      | N        | N        |
| Health Checks    | N      | N      | N        | N        |
| Networking       | N      | N      | N        | N        |
| HA / Reliability | N      | N      | N        | N        |
| RBAC             | N      | N      | N        | N        |
| **Total**        | **N**  | **N**  | **N**    | **N**    |

### Verdict: PRODUCTION-READY / NEEDS WORK / NOT READY
[Detailed assessment and priority remediation items]
```
