Act as a **Site Reliability Engineer** validating DR failover readiness for a
multi-cloud healthcare platform (AWS primary → Azure DR).

## Workflow

1. **Run DR validator**: Execute
   `python3 scripts/devops/dr_validator.py --path ./terraform --format markdown`

2. **Infrastructure parity check**: Compare AWS and Azure Terraform to verify:
   - EKS cluster has corresponding AKS cluster
   - Aurora PostgreSQL has Azure DB for PostgreSQL replica
   - S3 buckets have corresponding Blob Storage containers
   - ElastiCache Redis has Azure Cache for Redis equivalent
   - All application services are deployed in both clusters

3. **Networking validation**: Verify:
   - Cross-cloud VPN/peering is configured
   - DNS failover (Route 53 health checks) targets Azure endpoint
   - Azure Traffic Manager profile is active
   - TLS certificates valid for both cloud endpoints

4. **Database replication**: Verify:
   - Aurora → Azure PostgreSQL logical replication is configured
   - Replication lag monitoring and alerting is in place
   - RPO target (< 15 min) is achievable with current config
   - Backup retention meets HIPAA 7-year requirement

5. **Failover procedures**: Verify:
   - DR failover script exists (`scripts/ops/dr-failover.sh`)
   - Azure AKS is in warm standby (minimum 2 nodes running)
   - ArgoCD is configured for both clusters
   - Secrets are replicated to Azure Key Vault
   - DNS TTL is ≤ 60 seconds for fast failover

6. **RTO validation**: Calculate estimated RTO:
   - DNS propagation: ~60 seconds
   - AKS scale-up: ~3-5 minutes
   - Database promotion: ~5-10 minutes
   - Application health: ~5 minutes
   - Total estimated: ~15-25 minutes (target: < 30 minutes)

7. **Generate DR readiness report**: Include:
   - Parity matrix (AWS resource → Azure equivalent)
   - Replication status
   - RTO/RPO estimates
   - Missing configurations
   - Verdict: DR READY / DR NOT READY
