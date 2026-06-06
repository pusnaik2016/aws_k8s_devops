# /security-scan — Comprehensive Security Scanner

## Usage
```
/security-scan $ARGUMENTS
```
Where `$ARGUMENTS` is the path to scan. Defaults to the repository root `.`.

## Instructions

You are acting as a **Security Engineer** performing a thorough static
analysis of the codebase for vulnerabilities and misconfigurations.

### Step 1: Run the Automated Security Scanner
Execute the Python security scanner:
```bash
python3 scripts/sec_scanner.py --path ${ARGUMENTS:-.} --format markdown
```

### Step 2: Credential & Secret Scanning
Manually verify the scanner's results and additionally check for:
- AWS Access Key IDs (`AKIA[0-9A-Z]{16}`)
- AWS Secret Access Keys (40-character base64 strings)
- GitHub tokens (`ghp_`, `gho_`, `ghs_`, `ghr_`)
- Generic API keys and tokens in config files
- Private SSH keys (`-----BEGIN RSA PRIVATE KEY-----`)
- Database connection strings with embedded passwords
- `.env` files committed to version control
- `terraform.tfstate` files (should never be in git)

### Step 3: Docker Security Analysis
For all Dockerfiles in the repository:
- [ ] Base images pinned to digest or specific version (no `:latest`)
- [ ] `USER` directive present (non-root execution)
- [ ] No `ADD` for remote URLs (use `COPY` + `RUN curl`)
- [ ] No secrets in `ARG` or `ENV` instructions
- [ ] `.dockerignore` exists and excludes sensitive files
- [ ] Multi-stage builds used to minimize attack surface
- [ ] `HEALTHCHECK` instruction defined

### Step 4: Infrastructure Security
For Terraform files:
- [ ] No `0.0.0.0/0` in security group ingress (except 80/443)
- [ ] Encryption at rest enabled (S3, RDS, EBS)
- [ ] Encryption in transit enabled (TLS/SSL)
- [ ] IAM policies scoped to specific resources
- [ ] No wildcard (`*`) actions in IAM policies
- [ ] KMS keys configured with rotation
- [ ] VPC endpoints used for AWS service access

For Kubernetes manifests:
- [ ] `securityContext.runAsNonRoot: true`
- [ ] `securityContext.readOnlyRootFilesystem: true`
- [ ] `securityContext.allowPrivilegeEscalation: false`
- [ ] Resource limits defined
- [ ] No `hostNetwork: true` or `hostPID: true`
- [ ] ServiceAccount tokens auto-mounted only when needed
- [ ] Network policies restrict pod-to-pod traffic

### Step 5: CI/CD Pipeline Security
For GitHub Actions workflows:
- [ ] `permissions` blocks are minimal and scoped
- [ ] Third-party actions pinned to SHA
- [ ] No secrets in workflow logs (no `echo ${{ secrets.* }}`)
- [ ] OIDC used for cloud authentication
- [ ] `pull_request_target` used carefully (if at all)

### Step 6: Generate Report
```markdown
## 🔒 Security Scan Report
**Scan Date:** [current date/time]
**Scope:** [path scanned]
**Scanner Version:** Claude DevOps v1.0

### 🚨 Critical Findings (Immediate Action Required)
| # | Severity | Category    | File:Line        | Description          |
|---|----------|-------------|-----------------|---------------------|
| 1 | CRITICAL | [category]  | [file:line]     | [description]       |

### ⚠️ High Findings
[Table of high-severity findings]

### 📝 Medium Findings
[Table of medium-severity findings]

### 💡 Low / Informational
[Table of low-severity findings]

### 📊 Summary
| Severity     | Count |
|-------------|-------|
| 🚨 Critical  | N     |
| ⚠️ High      | N     |
| 📝 Medium    | N     |
| 💡 Low       | N     |
| **Total**    | **N** |

### Verdict: SECURE / AT RISK / CRITICAL
[Assessment and recommended remediation priorities]
```
