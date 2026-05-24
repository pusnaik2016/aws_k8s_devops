# /pr-review — Automated Pull Request Review

## Usage
```
/pr-review $ARGUMENTS
```
Where `$ARGUMENTS` is the target branch to compare against (default: `main`).

## Instructions

You are acting as a **Senior DevOps Engineer** conducting a comprehensive PR review.
Execute the following steps in order:

### Step 1: Git Diff Analysis
Run the following command to get the changed files:
```bash
git diff --name-only origin/$ARGUMENTS...HEAD 2>/dev/null || git diff --name-only HEAD~5
```
Parse the output and categorize changed files by type:
- **Infrastructure** (`.tf`, `.tfvars`)
- **Kubernetes** (`.yaml`, `.yml` in `k8s/` directories)
- **Application** (`*.py`, `*.js`, `*.ts`, `*.jsx`, `*.tsx`)
- **CI/CD** (`.github/workflows/*.yml`)
- **Docker** (`Dockerfile*`, `docker-compose*.yml`)
- **Documentation** (`*.md`, `*.txt`)

### Step 2: Security Scanning
Run the security scanner on all changed files:
```bash
python3 scripts/sec_scanner.py --path . --format markdown
```
Flag any findings of severity HIGH or CRITICAL as blocking issues.

### Step 3: Terraform Validation (if applicable)
For any changed `.tf` files, identify their parent module directory and run:
```bash
python3 scripts/tf_helper.py --path <module_dir> --format markdown
```
Check for:
- Missing required tags (`Environment`, `Project`, `ManagedBy`, `Owner`)
- Use of `sensitive = true` for secret variables
- Proper module structure (`main.tf`, `variables.tf`, `outputs.tf`)
- No hardcoded AWS account IDs or regions

### Step 4: Docker Security (if applicable)
For any changed Dockerfiles, check:
- [ ] Base images are pinned (no `:latest` tag)
- [ ] Multi-stage builds are used where appropriate
- [ ] No `ADD` when `COPY` suffices
- [ ] `USER` directive is set (not running as root)
- [ ] No secrets passed via `ARG` or `ENV`
- [ ] `.dockerignore` exists in the same directory

### Step 5: Kubernetes Manifest Review (if applicable)
For changed K8s manifests, run:
```bash
python3 scripts/k8s_helper.py --path <manifest_dir> --format markdown
```

### Step 6: CI/CD Pipeline Review (if applicable)
For any changed GitHub Actions workflows, verify:
- [ ] `permissions` block is present and scoped
- [ ] Secrets use `${{ secrets.* }}` — no hardcoded values
- [ ] OIDC is used for cloud provider auth (no long-lived credentials)
- [ ] Actions are pinned to SHA or specific version (not `@main` / `@master`)
- [ ] Appropriate `concurrency` groups are set

### Step 7: Generate Report
Compile all findings into a structured report using this format:

```markdown
## 📋 PR Review Report
**Branch:** `HEAD` → `origin/$ARGUMENTS`
**Review Date:** [current date/time]
**Changed Files:** [count]

### 📁 Changed Files Summary
| Category       | Files Changed | Issues Found |
|---------------|--------------|-------------|
| Infrastructure | N            | N           |
| Kubernetes     | N            | N           |
| Application    | N            | N           |
| CI/CD          | N            | N           |
| Docker         | N            | N           |

### ✅ Passed Checks
[List all checks that passed]

### ⚠️ Warnings
[List warnings with file:line references]

### ❌ Critical / Blocking Issues
[List critical findings that must be fixed before merge]

### 💡 Recommendations
[Suggestions for improvement that are non-blocking]

### 📊 Overall Summary
| Metric          | Value        |
|----------------|-------------|
| Total Checks    | N           |
| Passed          | N           |
| Warnings        | N           |
| Critical        | N           |
| Blocking Issues | N           |

---

### Verdict: APPROVE / REQUEST CHANGES
[Clear reasoning for the verdict]
```
