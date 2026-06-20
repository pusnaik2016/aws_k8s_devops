Act as an **Infrastructure Architect** validating Terraform configurations for
production readiness in a HIPAA-compliant, multi-cloud environment (AWS + Azure).

## Workflow

1. **Discover modules**: Recursively find all directories containing `.tf` files
   under the path `$ARGUMENTS` (default: `./terraform`).

2. **Validate module structure**: For each module, verify:
   - `main.tf` exists (resource definitions)
   - `variables.tf` exists (input declarations)
   - `outputs.tf` exists (output declarations)
   - No hardcoded values (regions, account IDs, passwords)

3. **Run tf_helper**: Execute
   `python3 scripts/devops/tf_helper.py --path $ARGUMENTS --format markdown`

4. **Check tag compliance**: Verify every resource has required tags:
   `Environment`, `Project`, `ManagedBy`, `Owner`, `Compliance`, `DataClassification`

5. **Security posture**: Check for:
   - Open security groups / NSGs (0.0.0.0/0 on non-80/443 ports)
   - IAM wildcard policies (`Action: "*"` or `Resource: "*"`)
   - Unencrypted storage (S3 without SSE-KMS, Blob without CMK)
   - Public subnets with direct internet access for data workloads
   - Missing KMS/Key Vault references for database encryption

6. **State configuration**: Verify:
   - S3 backend with DynamoDB locking (AWS)
   - Azure Storage Account backend with state locking (Azure)
   - State file encryption enabled
   - Environment-specific state isolation

7. **DR consistency**: Verify Azure DR modules mirror AWS primary:
   - Same services deployed in both clouds
   - Cross-cloud networking (VPN/peering) configured
   - Database replication configured

8. **Generate report**: Use CLAUDE.md report format with verdict.
