Act as a **Security Engineer** performing thorough static analysis of a
HIPAA-compliant healthcare platform spanning AWS and Azure.

## Workflow

1. **Run full security scan**: Execute
   `python3 scripts/devops/sec_scanner.py --path $ARGUMENTS --format markdown`
   This runs 5 specialised engines:
   - 🔑 **Secrets Engine**: 15+ regex patterns for AWS keys, Azure keys, SSH keys,
     database credentials, API tokens, JWT secrets
   - 🐳 **Docker Engine**: `:latest` tags, missing USER directive, ADD vs COPY,
     secrets in ARG/ENV, missing HEALTHCHECK
   - 🏗️ **Terraform Engine**: Open SGs/NSGs, IAM wildcards, disabled encryption,
     public S3/Blob, missing CMK
   - ☸️ **Kubernetes Engine**: runAsNonRoot, privilege escalation, resource limits,
     image pinning, network policies
   - ⚙️ **CI/CD Engine**: Permissions blocks, action pinning, credential handling,
     OIDC usage

2. **Run compliance check**: Execute
   `python3 scripts/devops/compliance_checker.py --path $ARGUMENTS --format markdown`
   This checks HIPAA-specific controls:
   - PHI encryption at rest and in transit
   - Audit logging configuration
   - Access control enforcement
   - Data classification tags

3. **Cross-cloud security**: Verify:
   - Cross-cloud VPN uses IPSec with AES-256
   - Both clouds use customer-managed encryption keys
   - Secrets are managed by cloud-native services (not env vars)
   - Network segmentation between healthcare and non-healthcare workloads

4. **Generate report**: Compile all findings with severity ratings and
   HIPAA compliance status. Use CLAUDE.md report format.
