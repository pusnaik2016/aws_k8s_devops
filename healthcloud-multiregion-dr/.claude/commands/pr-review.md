Act as a **Senior DevOps Engineer** conducting a comprehensive PR review for a
HIPAA-compliant, multi-cloud healthcare platform (AWS primary + Azure DR).

## Workflow

1. **Identify changed files**: Run `git diff --name-only $ARGUMENTS` to list all
   changed files between the current branch and the target branch.

2. **Categorise changes**: Group files into:
   - Infrastructure (`.tf` files)
   - Kubernetes (`.yaml`/`.yml` in `kubernetes/`)
   - Application (Dockerfiles, Java/Python source)
   - CI/CD (`.github/workflows/`)
   - Documentation (`.md` files)

3. **Run security scan**: Execute `python3 scripts/devops/sec_scanner.py --path . --format markdown`
   to check for secrets, Docker issues, Terraform misconfigurations, K8s security
   gaps, and CI/CD hygiene problems.

4. **Run Terraform validation**: If `.tf` files changed, execute
   `python3 scripts/devops/tf_helper.py --path ./terraform --format markdown`

5. **Run K8s diagnostics**: If K8s manifests changed, execute
   `python3 scripts/devops/k8s_helper.py --path ./kubernetes --format markdown`

6. **Run compliance check**: Execute
   `python3 scripts/devops/compliance_checker.py --path . --format markdown`
   to verify HIPAA/GDPR compliance of all changes.

7. **Generate structured report**: Compile all findings into a single report
   using the format defined in CLAUDE.md. Include:
   - Summary of changes by category
   - Security findings (critical → warnings)
   - Compliance status (HIPAA, GDPR)
   - DR impact assessment (does this change affect failover?)
   - Clear `### Verdict: APPROVE / REQUEST CHANGES`
