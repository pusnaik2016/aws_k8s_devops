"""
test_integration.py — End-to-end integration tests (mocked AWS)
=================================================================
Tests the full save-flow pipeline: event → Lambda → S3 + DynamoDB + KB ingestion.
"""

import json
import pytest


def _get_body(result):
    """Extract parsed body from Lambda action group response."""
    body_str = result["response"]["functionResponse"]["responseBody"]["TEXT"]["body"]
    return json.loads(body_str)


# ═══════════════════════════════════════════════════════════════════════════════
# Full Save Flow Tests
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.mark.integration
class TestFullSaveFlow:
    """End-to-end save pipeline with mocked AWS services."""

    def test_save_writes_to_s3_and_dynamodb(self, lambda_module, make_event, mock_aws):
        """A high-confidence save writes to both S3 and DynamoDB."""
        event = make_event(
            fact="I use Terraform for all infrastructure",
            category="preference",
            confidence="0.95",
            session_id="integ-session-001",
        )
        result = lambda_module.lambda_handler(event, None)
        body = _get_body(result)

        assert body["status"] == "saved"
        mock_aws["s3"].put_object.assert_called_once()
        mock_aws["table"].put_item.assert_called_once()

    def test_save_triggers_ingestion(self, lambda_module, make_event, mock_aws):
        """Successful save triggers KB ingestion job."""
        event = make_event(confidence="0.9")
        result = lambda_module.lambda_handler(event, None)
        body = _get_body(result)

        assert body["ingestion_job_id"] == "ING_TEST_789"
        mock_aws["bedrock"].start_ingestion_job.assert_called_once()

    def test_skip_does_not_trigger_ingestion(self, lambda_module, make_event, mock_aws):
        """Skipped facts do NOT trigger KB ingestion."""
        event = make_event(confidence="0.3")
        lambda_module.lambda_handler(event, None)

        mock_aws["bedrock"].start_ingestion_job.assert_not_called()
        mock_aws["s3"].put_object.assert_not_called()
        mock_aws["table"].put_item.assert_not_called()


# ═══════════════════════════════════════════════════════════════════════════════
# Category Routing Tests
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.mark.integration
class TestCategoryRouting:
    """Facts are routed to the correct S3 prefix by category."""

    @pytest.mark.parametrize("category,expected_prefix", [
        ("preference", "memories/preference/"),
        ("project_context", "memories/project_context/"),
        ("decision", "memories/decision/"),
        ("user_profile", "memories/user_profile/"),
    ])
    def test_category_routes_to_correct_s3_prefix(
        self, lambda_module, make_event, mock_aws, category, expected_prefix
    ):
        event = make_event(category=category, confidence="0.9")
        lambda_module.lambda_handler(event, None)

        call_args = mock_aws["s3"].put_object.call_args
        key = call_args.kwargs.get("Key", call_args[1].get("Key", ""))
        assert key.startswith(expected_prefix), f"Expected {expected_prefix}, got {key}"


# ═══════════════════════════════════════════════════════════════════════════════
# Multi-Session Tests
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.mark.integration
class TestMultiSession:
    """Verify multiple sessions produce independent records."""

    def test_different_sessions_produce_different_records(
        self, lambda_module, make_event, mock_aws
    ):
        """Two saves from different sessions produce two DynamoDB records."""
        event1 = make_event(
            fact="Fact from session A", session_id="session-A", confidence="0.9"
        )
        event2 = make_event(
            fact="Fact from session B", session_id="session-B", confidence="0.85"
        )

        lambda_module.lambda_handler(event1, None)
        lambda_module.lambda_handler(event2, None)

        assert mock_aws["s3"].put_object.call_count == 2
        assert mock_aws["table"].put_item.call_count == 2

    def test_different_sessions_have_different_document_ids(
        self, lambda_module, make_event, mock_aws
    ):
        """Each save generates a unique document ID."""
        event1 = make_event(fact="Fact A", session_id="s1", confidence="0.9")
        event2 = make_event(fact="Fact B", session_id="s2", confidence="0.9")

        r1 = lambda_module.lambda_handler(event1, None)
        r2 = lambda_module.lambda_handler(event2, None)

        body1 = _get_body(r1)
        body2 = _get_body(r2)

        assert body1["document_id"] != body2["document_id"]


# ═══════════════════════════════════════════════════════════════════════════════
# Lambda Source Code Tests
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.mark.integration
class TestLambdaSourceCode:
    """Verify Lambda source files exist and are well-formed."""

    def test_lambda_index_exists(self, lambda_dir):
        assert (lambda_dir / "index.py").exists()

    def test_lambda_requirements_exists(self, lambda_dir):
        assert (lambda_dir / "requirements.txt").exists()

    def test_lambda_has_handler_function(self, lambda_dir):
        source = (lambda_dir / "index.py").read_text()
        assert "def lambda_handler" in source

    def test_lambda_has_confidence_threshold(self, lambda_dir):
        source = (lambda_dir / "index.py").read_text()
        assert "CONFIDENCE_THRESHOLD" in source

    def test_lambda_has_memory_saved_log(self, lambda_dir):
        """Lambda logs MEMORY_SAVED marker for CloudWatch metric filter."""
        source = (lambda_dir / "index.py").read_text()
        assert "MEMORY_SAVED" in source

    def test_lambda_has_memory_skipped_log(self, lambda_dir):
        """Lambda logs MEMORY_SKIPPED marker for CloudWatch metric filter."""
        source = (lambda_dir / "index.py").read_text()
        assert "MEMORY_SKIPPED" in source


# ═══════════════════════════════════════════════════════════════════════════════
# Demo Script Tests
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.mark.integration
class TestDemoScript:
    """Verify demo script exists and is well-formed."""

    def test_demo_script_exists(self, project_root):
        assert (project_root / "src" / "demo" / "agent_demo.py").exists()

    def test_demo_script_has_layer_demos(self, project_root):
        source = (project_root / "src" / "demo" / "agent_demo.py").read_text()
        assert "demo_layer1" in source
        assert "demo_layer2" in source
        assert "demo_layer3" in source

    def test_demo_script_has_argparse(self, project_root):
        source = (project_root / "src" / "demo" / "agent_demo.py").read_text()
        assert "argparse" in source
        assert "--agent-id" in source
