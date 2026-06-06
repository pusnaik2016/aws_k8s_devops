"""
test_terraform.py — Terraform module structure validation
===========================================================
Validates that all 5 Terraform modules have the expected file structure,
required variables, and output definitions — no AWS credentials needed.
"""

import os
from pathlib import Path
import pytest


# ═══════════════════════════════════════════════════════════════════════════════
# Module Structure Tests
# ═══════════════════════════════════════════════════════════════════════════════

MODULES = [
    "aurora-pgvector",
    "knowledge-base",
    "agent",
    "session-memory",
    "observability",
]

@pytest.mark.terraform
class TestModuleStructure:
    """Every module must have main.tf, variables.tf, and outputs.tf."""

    @pytest.mark.parametrize("module_name", MODULES)
    def test_module_has_main_tf(self, terraform_dir, module_name):
        path = terraform_dir / "main" / "modules" / module_name / "main.tf"
        assert path.exists(), f"Missing main.tf in module {module_name}"

    @pytest.mark.parametrize("module_name", MODULES)
    def test_module_has_variables_tf(self, terraform_dir, module_name):
        path = terraform_dir / "main" / "modules" / module_name / "variables.tf"
        assert path.exists(), f"Missing variables.tf in module {module_name}"

    @pytest.mark.parametrize("module_name", MODULES)
    def test_module_has_outputs_tf(self, terraform_dir, module_name):
        path = terraform_dir / "main" / "modules" / module_name / "outputs.tf"
        assert path.exists(), f"Missing outputs.tf in module {module_name}"


# ═══════════════════════════════════════════════════════════════════════════════
# Root Module Tests
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.mark.terraform
class TestRootModule:
    """Root terraform/main/ must have all required configuration files."""

    def test_root_main_tf_exists(self, terraform_dir):
        assert (terraform_dir / "main" / "main.tf").exists()

    def test_root_variables_tf_exists(self, terraform_dir):
        assert (terraform_dir / "main" / "variables.tf").exists()

    def test_root_outputs_tf_exists(self, terraform_dir):
        assert (terraform_dir / "main" / "outputs.tf").exists()

    def test_root_providers_tf_exists(self, terraform_dir):
        assert (terraform_dir / "main" / "providers.tf").exists()

    def test_root_backend_tf_exists(self, terraform_dir):
        assert (terraform_dir / "main" / "backend.tf").exists()


# ═══════════════════════════════════════════════════════════════════════════════
# Bootstrap Module Tests
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.mark.terraform
class TestBootstrapModule:
    """Bootstrap module creates S3 state bucket + DynamoDB lock table."""

    def test_bootstrap_main_tf_exists(self, terraform_dir):
        assert (terraform_dir / "bootstrap" / "main.tf").exists()

    def test_bootstrap_variables_tf_exists(self, terraform_dir):
        assert (terraform_dir / "bootstrap" / "variables.tf").exists()

    def test_bootstrap_outputs_tf_exists(self, terraform_dir):
        assert (terraform_dir / "bootstrap" / "outputs.tf").exists()


# ═══════════════════════════════════════════════════════════════════════════════
# Content Validation Tests
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.mark.terraform
class TestContentValidation:
    """Verify critical Terraform configurations exist in source code."""

    def test_aurora_enables_http_endpoint(self, terraform_dir):
        """enable_http_endpoint = true is REQUIRED for Bedrock Data API."""
        main_tf = (terraform_dir / "main" / "modules" / "aurora-pgvector" / "main.tf").read_text()
        assert "enable_http_endpoint" in main_tf
        assert "true" in main_tf

    def test_aurora_uses_postgresql_15(self, terraform_dir):
        """Aurora must use PostgreSQL 15+ for pgvector support."""
        main_tf = (terraform_dir / "main" / "modules" / "aurora-pgvector" / "main.tf").read_text()
        assert "aurora-postgresql" in main_tf
        assert "15." in main_tf

    def test_aurora_uses_serverless_v2(self, terraform_dir):
        """Aurora must use Serverless v2 (db.serverless instance class)."""
        main_tf = (terraform_dir / "main" / "modules" / "aurora-pgvector" / "main.tf").read_text()
        assert "db.serverless" in main_tf

    def test_kb_uses_hierarchical_chunking(self, terraform_dir):
        """Knowledge Base uses HIERARCHICAL chunking strategy."""
        main_tf = (terraform_dir / "main" / "modules" / "knowledge-base" / "main.tf").read_text()
        assert "HIERARCHICAL" in main_tf

    def test_kb_uses_rds_storage(self, terraform_dir):
        """Knowledge Base storage type is RDS (Aurora pgvector)."""
        main_tf = (terraform_dir / "main" / "modules" / "knowledge-base" / "main.tf").read_text()
        assert '"RDS"' in main_tf

    def test_agent_uses_correct_model(self, terraform_dir):
        """Agent foundation model does NOT use eu. prefix."""
        vars_tf = (terraform_dir / "main" / "modules" / "agent" / "variables.tf").read_text()
        assert "anthropic.claude" in vars_tf
        # Must NOT have the eu. prefix — causes validation errors
        assert 'default     = "eu.' not in vars_tf

    def test_agent_has_session_summary(self, terraform_dir):
        """Agent memory config includes SESSION_SUMMARY."""
        main_tf = (terraform_dir / "main" / "modules" / "agent" / "main.tf").read_text()
        assert "SESSION_SUMMARY" in main_tf

    def test_agent_has_save_function(self, terraform_dir):
        """Agent action group defines save_to_long_term_memory function."""
        main_tf = (terraform_dir / "main" / "modules" / "agent" / "main.tf").read_text()
        assert "save_to_long_term_memory" in main_tf

    def test_observability_has_memory_saved_filter(self, terraform_dir):
        """CloudWatch metric filter for MEMORY_SAVED exists."""
        main_tf = (terraform_dir / "main" / "modules" / "observability" / "main.tf").read_text()
        assert "MEMORY_SAVED" in main_tf

    def test_observability_has_memory_skipped_filter(self, terraform_dir):
        """CloudWatch metric filter for MEMORY_SKIPPED exists."""
        main_tf = (terraform_dir / "main" / "modules" / "observability" / "main.tf").read_text()
        assert "MEMORY_SKIPPED" in main_tf

    def test_observability_has_dlq_alarm(self, terraform_dir):
        """DLQ alarm is configured."""
        main_tf = (terraform_dir / "main" / "modules" / "observability" / "main.tf").read_text()
        assert "dlq" in main_tf.lower()

    def test_backend_uses_s3(self, terraform_dir):
        """Backend uses S3 for remote state."""
        backend_tf = (terraform_dir / "main" / "backend.tf").read_text()
        assert 's3' in backend_tf
        assert 'dynamodb_table' in backend_tf

    def test_root_wires_all_modules(self, terraform_dir):
        """Root main.tf references all 5 modules."""
        main_tf = (terraform_dir / "main" / "main.tf").read_text()
        for module in ["aurora", "knowledge_base", "session_memory", "agent", "observability"]:
            assert f'module "{module}"' in main_tf, f"Module {module} not wired in root main.tf"

    def test_session_memory_has_dynamodb(self, terraform_dir):
        """Session memory module provisions DynamoDB table."""
        main_tf = (terraform_dir / "main" / "modules" / "session-memory" / "main.tf").read_text()
        assert "aws_dynamodb_table" in main_tf

    def test_session_memory_has_sqs(self, terraform_dir):
        """Session memory module provisions SQS queue + DLQ."""
        main_tf = (terraform_dir / "main" / "modules" / "session-memory" / "main.tf").read_text()
        assert "aws_sqs_queue" in main_tf
        assert "dlq" in main_tf.lower()

    def test_pgvector_schema_creation(self, terraform_dir):
        """Aurora module creates the bedrock_integration schema with pgvector."""
        main_tf = (terraform_dir / "main" / "modules" / "aurora-pgvector" / "main.tf").read_text()
        assert "bedrock_integration" in main_tf
        assert "vector" in main_tf
