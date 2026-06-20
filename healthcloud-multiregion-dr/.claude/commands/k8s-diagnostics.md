Act as a **Kubernetes Platform Engineer** reviewing manifests for production
readiness in a HIPAA-compliant, multi-cluster environment (EKS + AKS).

## Workflow

1. **Run K8s diagnostics**: Execute
   `python3 scripts/devops/k8s_helper.py --path $ARGUMENTS --format markdown`

2. **Security review**: For every Deployment/StatefulSet, verify:
   - `securityContext.runAsNonRoot: true`
   - `securityContext.readOnlyRootFilesystem: true`
   - `securityContext.allowPrivilegeEscalation: false`
   - `securityContext.capabilities.drop: ["ALL"]`
   - No `privileged: true` containers

3. **Resource management**: Verify:
   - CPU/memory `requests` defined (for scheduling)
   - CPU/memory `limits` defined (for protection)
   - Requests ≤ Limits
   - No unlimited resource pods in production namespaces

4. **Health checks**: Verify:
   - `readinessProbe` defined (for traffic routing)
   - `livenessProbe` defined (for restart)
   - `startupProbe` for slow-starting apps (Java/Spring Boot)
   - Probe endpoints are different from application endpoints

5. **High availability**: Verify:
   - `replicas >= 2` for production
   - `PodDisruptionBudget` defined
   - `HorizontalPodAutoscaler` configured
   - Pod anti-affinity for zone distribution

6. **Networking**: Verify:
   - NetworkPolicy defined for every namespace
   - Default deny ingress/egress in base policies
   - Service types appropriate (ClusterIP internal, LoadBalancer external)
   - Ingress TLS configured

7. **Image security**: Verify:
   - No `:latest` tags
   - Images from approved registries (ECR, ACR) only
   - `imagePullPolicy: IfNotPresent` or `Always` (not `Never`)

8. **Multi-cluster**: Verify:
   - Manifests work for both EKS and AKS
   - Istio annotations/labels present
   - ArgoCD Application CRDs target correct clusters

9. **Generate report**: Use CLAUDE.md report format with verdict.
