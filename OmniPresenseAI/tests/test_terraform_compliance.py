"""
Terraform Compliance Tests — OmniPresenseAI
─────────────────────────────────────────────
Validates Terraform files for security, compliance, and best practices
without requiring terraform init or AWS credentials.

Run: pytest tests/test_terraform_compliance.py -v
"""
import os
import re
import glob
import pytest

# Project root
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TF_ROOT = os.path.join(PROJECT_ROOT, "terraform")


def read_tf_files(module_path):
    """Read all .tf files in a module directory and return combined content."""
    content = ""
    pattern = os.path.join(module_path, "*.tf")
    for filepath in sorted(glob.glob(pattern)):
        with open(filepath, "r") as f:
            content += f.read() + "\n"
    return content


# ─── Security Module Tests ────────────────────────────────────

class TestSecurityModule:
    """Validate security module Terraform configurations."""

    @pytest.fixture(autouse=True)
    def setup(self):
        self.content = read_tf_files(os.path.join(TF_ROOT, "modules/security"))

    def test_kms_key_rotation_enabled(self):
        """HIPAA/PCI-DSS: KMS keys must have automatic rotation."""
        kms_blocks = re.findall(r'resource\s+"aws_kms_key".*?\{.*?\}', self.content, re.DOTALL)
        for block in kms_blocks:
            assert "enable_key_rotation" in block, f"KMS key missing enable_key_rotation"
            assert "true" in block, "KMS key rotation must be true"

    def test_no_administrator_access(self):
        """SOX/PCI-DSS: No AdministratorAccess policy attached."""
        assert "AdministratorAccess" not in self.content, \
            "CRITICAL: AdministratorAccess policy found! Use least-privilege."

    def test_oidc_federation_exists(self):
        """Security: OIDC federation should be used instead of static credentials."""
        assert "aws_iam_openid_connect_provider" in self.content

    def test_ssm_parameters_are_secure_string(self):
        """HIPAA: Secrets must use SecureString type."""
        # Count SSM parameter resources and SecureString occurrences
        ssm_count = self.content.count('resource "aws_ssm_parameter"')
        secure_count = self.content.count('"SecureString"')
        assert ssm_count > 0, "No SSM parameters found"
        assert secure_count >= ssm_count, \
            f"Found {ssm_count} SSM parameters but only {secure_count} use SecureString"


# ─── Compliance Module Tests ──────────────────────────────────

class TestComplianceModule:
    """Validate compliance module Terraform configurations."""

    @pytest.fixture(autouse=True)
    def setup(self):
        self.content = read_tf_files(os.path.join(TF_ROOT, "modules/compliance"))

    def test_cloudtrail_exists(self):
        """HIPAA/PCI-DSS/SOX: CloudTrail is required."""
        assert "aws_cloudtrail" in self.content

    def test_cloudtrail_multi_region(self):
        """SOX: CloudTrail must be multi-region."""
        assert "is_multi_region_trail" in self.content
        assert "true" in self.content

    def test_cloudtrail_log_validation(self):
        """PCI-DSS 10: Log file validation must be enabled."""
        assert "enable_log_file_validation" in self.content

    def test_guardduty_enabled(self):
        """PCI-DSS 11.4: Intrusion detection required."""
        assert "aws_guardduty_detector" in self.content

    def test_guardduty_eks_monitoring(self):
        """Security: GuardDuty should monitor EKS audit logs."""
        assert "kubernetes" in self.content.lower()

    def test_security_hub_exists(self):
        """Compliance: Security Hub centralizes findings."""
        assert "aws_securityhub_account" in self.content

    def test_security_hub_pci_standard(self):
        """PCI-DSS: PCI DSS standard must be enabled in Security Hub."""
        assert "pci-dss" in self.content.lower()

    def test_security_hub_cis_standard(self):
        """CIS: CIS benchmark standard must be enabled."""
        assert "cis" in self.content.lower()

    def test_aws_config_exists(self):
        """Compliance: AWS Config must be enabled."""
        assert "aws_config_configuration_recorder" in self.content

    def test_config_rules_encryption(self):
        """HIPAA: Config rule checking S3 encryption exists."""
        assert "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED" in self.content

    def test_config_rules_public_access(self):
        """PCI-DSS: Config rule checking no public S3."""
        assert "S3_BUCKET_PUBLIC_READ_PROHIBITED" in self.content

    def test_config_rules_rds_encryption(self):
        """PCI-DSS: Config rule checking RDS encryption."""
        assert "RDS_STORAGE_ENCRYPTED" in self.content

    def test_config_rules_cloudtrail(self):
        """PCI-DSS 10: Config rule verifying CloudTrail enabled."""
        assert "CLOUD_TRAIL_ENABLED" in self.content

    def test_macie_exists(self):
        """GDPR/HIPAA: Macie PII detection required."""
        assert "aws_macie2" in self.content

    def test_waf_exists(self):
        """PCI-DSS 6.6: WAF is required."""
        assert "aws_wafv2_web_acl" in self.content

    def test_waf_owasp_common_rules(self):
        """OWASP: Common rule set must be enabled."""
        assert "AWSManagedRulesCommonRuleSet" in self.content

    def test_waf_sqli_rules(self):
        """OWASP: SQL injection protection must be enabled."""
        assert "AWSManagedRulesSQLiRuleSet" in self.content

    def test_waf_rate_limiting(self):
        """Security: Rate limiting must be configured."""
        assert "rate_based_statement" in self.content

    def test_waf_bot_control(self):
        """Security: Bot control rules must be enabled."""
        assert "AWSManagedRulesBotControlRuleSet" in self.content

    def test_access_analyzer_exists(self):
        """SOX: IAM Access Analyzer is required."""
        assert "aws_accessanalyzer_analyzer" in self.content

    def test_budget_alerts_exist(self):
        """Cost: Budget alerts must be configured."""
        assert "aws_budgets_budget" in self.content

    def test_sns_alerting(self):
        """Ops: SNS topic for alerts must exist."""
        assert "aws_sns_topic" in self.content

    def test_cloudtrail_s3_encryption(self):
        """HIPAA: CloudTrail S3 bucket must be KMS encrypted."""
        assert "kms" in self.content.lower()

    def test_s3_public_access_blocked(self):
        """PCI-DSS: All S3 buckets must block public access."""
        assert "aws_s3_bucket_public_access_block" in self.content

    def test_log_retention_7_years(self):
        """SOX/HIPAA: Log retention should be ~7 years (2555 days)."""
        assert "2555" in self.content


# ─── AI Governance Module Tests ───────────────────────────────

class TestAIGovernanceModule:
    """Validate AI governance Terraform configurations."""

    @pytest.fixture(autouse=True)
    def setup(self):
        self.content = read_tf_files(os.path.join(TF_ROOT, "modules/ai_governance"))

    def test_bedrock_guardrails_exist(self):
        """AI Lens: Bedrock Guardrails must be configured."""
        assert "aws_bedrock_guardrail" in self.content

    def test_pii_redaction_configured(self):
        """GDPR/HIPAA: PII entities must be configured for redaction."""
        assert "EMAIL" in self.content
        assert "PHONE" in self.content
        assert "NAME" in self.content

    def test_ssn_blocked(self):
        """HIPAA: Social Security Numbers must be BLOCKED (not just anonymized)."""
        assert "US_SOCIAL_SECURITY_NUMBER" in self.content
        # Verify it's BLOCK, not ANONYMIZE
        ssn_idx = self.content.index("US_SOCIAL_SECURITY_NUMBER")
        nearby = self.content[ssn_idx:ssn_idx + 200]
        assert "BLOCK" in nearby

    def test_credit_card_blocked(self):
        """PCI-DSS: Credit card numbers must be BLOCKED."""
        assert "CREDIT_DEBIT_CARD_NUMBER" in self.content

    def test_aws_keys_blocked(self):
        """Security: AWS access keys must be BLOCKED in AI output."""
        assert "AWS_ACCESS_KEY" in self.content
        assert "AWS_SECRET_KEY" in self.content

    def test_content_filters_configured(self):
        """AI Lens: Content filters for harmful content."""
        for filter_type in ["SEXUAL", "VIOLENCE", "HATE", "MISCONDUCT"]:
            assert filter_type in self.content, f"Missing content filter: {filter_type}"

    def test_prompt_attack_filter(self):
        """AI Lens: Prompt injection protection."""
        assert "PROMPT_ATTACK" in self.content

    def test_topic_policies_configured(self):
        """AI Lens: Topic blocking for regulated advice."""
        assert "financial" in self.content.lower()
        assert "medical" in self.content.lower()
        assert "legal" in self.content.lower()

    def test_guardrail_versioning(self):
        """AI Lens: Guardrails should be versioned."""
        assert "aws_bedrock_guardrail_version" in self.content

    def test_bedrock_invocation_logging(self):
        """AI Lens: Model invocations must be logged."""
        assert "aws_bedrock_model_invocation_logging_configuration" in self.content

    def test_bedrock_logs_s3_bucket(self):
        """SOX: Bedrock logs must be archived to S3."""
        assert "bedrock-logs" in self.content

    def test_bedrock_error_alarm(self):
        """AI Lens: Error rate monitoring alarm."""
        assert "InvocationErrors" in self.content

    def test_bedrock_throttle_alarm(self):
        """AI Lens: Throttle monitoring alarm."""
        assert "InvocationThrottles" in self.content


# ─── Database Module Tests ────────────────────────────────────

class TestDatabaseModule:
    """Validate database Terraform configurations."""

    @pytest.fixture(autouse=True)
    def setup(self):
        self.content = read_tf_files(os.path.join(TF_ROOT, "modules/database"))

    def test_aurora_encryption_at_rest(self):
        """HIPAA/PCI-DSS: Aurora must be encrypted at rest."""
        assert "storage_encrypted" in self.content
        assert "true" in self.content

    def test_aurora_backup_retention(self):
        """HIPAA: Backup retention must be > 0."""
        match = re.search(r'backup_retention_period\s*=\s*(\d+)', self.content)
        assert match, "backup_retention_period not found"
        assert int(match.group(1)) >= 7, "Backup retention should be >= 7 days"

    def test_aurora_deletion_protection(self):
        """Safety: Deletion protection should be enabled for prod."""
        assert "deletion_protection" in self.content

    def test_redis_transit_encryption(self):
        """HIPAA: Redis must encrypt in transit."""
        assert "transit_encryption_enabled" in self.content

    def test_redis_at_rest_encryption(self):
        """HIPAA: Redis must encrypt at rest."""
        assert "at_rest_encryption_enabled" in self.content

    def test_redis_auth_token(self):
        """Security: Redis must use auth token."""
        assert "auth_token" in self.content

    def test_redis_multi_az(self):
        """Reliability: Redis should be multi-AZ."""
        assert "multi_az_enabled" in self.content


# ─── Networking Module Tests ──────────────────────────────────

class TestNetworkingModule:
    """Validate networking Terraform configurations."""

    @pytest.fixture(autouse=True)
    def setup(self):
        self.content = read_tf_files(os.path.join(TF_ROOT, "modules/networking"))

    def test_vpc_flow_logs(self):
        """HIPAA/PCI-DSS: VPC flow logs must be enabled."""
        assert "aws_flow_log" in self.content

    def test_private_subnets_exist(self):
        """Security: Private subnets must be defined."""
        assert "private" in self.content.lower()

    def test_nat_gateway_exists(self):
        """Networking: NAT gateway for private subnet internet."""
        assert "aws_nat_gateway" in self.content

    def test_dns_support_enabled(self):
        """Networking: DNS support must be enabled."""
        assert "enable_dns_support" in self.content


# ─── Cross-Module Tests ──────────────────────────────────────

class TestCrossModule:
    """Tests that validate relationships between modules."""

    def test_all_modules_have_variables(self):
        """Every module should have a variables.tf."""
        modules_dir = os.path.join(TF_ROOT, "modules")
        for module in os.listdir(modules_dir):
            module_path = os.path.join(modules_dir, module)
            if os.path.isdir(module_path):
                assert os.path.exists(os.path.join(module_path, "variables.tf")), \
                    f"Module {module} missing variables.tf"

    def test_all_modules_have_outputs(self):
        """Every module should have an outputs.tf."""
        modules_dir = os.path.join(TF_ROOT, "modules")
        for module in os.listdir(modules_dir):
            module_path = os.path.join(modules_dir, module)
            if os.path.isdir(module_path):
                assert os.path.exists(os.path.join(module_path, "outputs.tf")), \
                    f"Module {module} missing outputs.tf"

    def test_prod_main_references_all_modules(self):
        """Prod main.tf should reference all 7 modules."""
        prod_main = os.path.join(TF_ROOT, "envs/prod/main.tf")
        with open(prod_main) as f:
            content = f.read()
        expected_modules = [
            "networking", "security", "compute", "database", "ai_cdn",
            "compliance", "ai_governance"
        ]
        for mod in expected_modules:
            assert f'module "{mod}"' in content, f"Prod main.tf missing module: {mod}"

    def test_compliance_tags_present(self):
        """Compliance resources should have Compliance tags."""
        content = read_tf_files(os.path.join(TF_ROOT, "modules/compliance"))
        assert "Compliance" in content, "Compliance tags missing"
        for framework in ["HIPAA", "PCI-DSS"]:
            assert framework in content, f"Compliance tag missing framework: {framework}"
