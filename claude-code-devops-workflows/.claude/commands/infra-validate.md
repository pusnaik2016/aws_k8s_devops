# /infra-validate — Infrastructure Validation

## Usage
```
/infra-validate $ARGUMENTS
```
Where `$ARGUMENTS` is the path to a Terraform directory to validate.
Defaults to scanning all directories containing `.tf` files.

## Instructions

You are acting as an **Infrastructure Architect** validating Terraform
configurations for production readiness.

### Step 1: Discover Terraform Directories
If no specific path is given, find all directories containing `.tf` files:
```bash
find . -name "*.tf" -not -path "*/.terraform/*" | xargs -I{} dirname {} | sort -u
```

### Step 2: Structural Validation
For each discovered directory, verify the required file structure:
- [ ] `main.tf` exists (resource definitions)
- [ ] `variables.tf` exists (input variable declarations)
- [ ] `outputs.tf` exists (output value declarations)
- [ ] `providers.tf` or provider blocks exist
- [ ] `terraform.tfvars` or `.auto.tfvars` exist for variable values
- [ ] `versions.tf` or version constraints are defined
- [ ] `backend` configuration exists (for root modules)

### Step 3: Run Terraform Validate (if available)
If `terraform` CLI is installed, run:
```bash
cd <terraform_dir> && terraform init -backend=false && terraform validate
```
If not installed, run the Python helper:
```bash
python3 scripts/tf_helper.py --path <terraform_dir> --format markdown
```

### Step 4: Security & Compliance Checks
Run the security scanner against the Terraform files:
```bash
python3 scripts/sec_scanner.py --path <terraform_dir> --type terraform --format markdown
```

Verify the following compliance rules:
- [ ] All resources have required tags: `Environment`, `Project`, `ManagedBy`, `Owner`
- [ ] No hardcoded credentials or account IDs
- [ ] S3 buckets have encryption enabled
- [ ] Security groups have justified ingress/egress rules
- [ ] RDS instances use encryption at rest
- [ ] IAM policies follow least-privilege
- [ ] KMS keys are used for encryption where applicable
- [ ] VPC flow logs are enabled
- [ ] CloudTrail logging is configured

### Step 5: State & Backend Check
Verify remote state configuration:
- [ ] S3 backend is configured
- [ ] DynamoDB locking is enabled
- [ ] State file encryption is enabled
- [ ] State bucket versioning is enabled

### Step 6: Module Dependency Analysis
Map the module dependency tree and verify:
- [ ] No circular dependencies
- [ ] All module sources are valid (local paths or versioned registry)
- [ ] Module outputs are consumed or can be removed
- [ ] Variable defaults are appropriate for the environment

### Step 7: Generate Report
```markdown
## 📋 Infrastructure Validation Report
**Scan Date:** [current date/time]
**Scope:** [directories validated]

### 🏗️ Module Structure
| Directory       | main.tf | variables.tf | outputs.tf | providers | Status |
|----------------|---------|-------------|-----------|----------|--------|
| [dir]          | ✅/❌   | ✅/❌        | ✅/❌      | ✅/❌     | PASS/FAIL |

### 🔐 Security Compliance
[List of security check results]

### 📦 State Configuration
[State backend verification results]

### 🔗 Module Dependencies
[Dependency tree visualization]

### 📊 Summary
| Metric              | Value |
|--------------------|-------|
| Modules Scanned     | N     |
| Structure Passes    | N     |
| Security Passes     | N     |
| Warnings            | N     |
| Critical Issues     | N     |

### Verdict: PASS / FAIL
[Reasoning]
```
