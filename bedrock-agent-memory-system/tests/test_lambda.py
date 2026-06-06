"""
test_lambda.py — Unit tests for the Memory Writer Lambda handler
=================================================================
Tests confidence gating, document format, action group response
format, and S3/DynamoDB interactions.
"""

import json
import pytest


def _get_body(result):
    """Extract parsed body from Lambda action group response."""
    body_str = result["response"]["functionResponse"]["responseBody"]["TEXT"]["body"]
    return json.loads(body_str)


# ═══════════════════════════════════════════════════════════════════════════════
# Confidence Gate Tests
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.mark.lambda_handler
@pytest.mark.confidence
class TestConfidenceGate:
    """Verify the confidence threshold quality gate."""

    def test_high_confidence_saves(self, lambda_module, make_event, mock_aws):
        """Facts with confidence >= 0.7 are saved."""
        event = make_event(fact="Important preference", confidence="0.9")
        result = lambda_module.lambda_handler(event, None)

        body = _get_body(result)
        assert body["status"] == "saved"
        mock_aws["s3"].put_object.assert_called_once()

    def test_low_confidence_skips(self, lambda_module, make_event, mock_aws):
        """Facts with confidence < 0.7 are skipped (not saved to S3)."""
        event = make_event(fact="Casual remark", confidence="0.3")
        result = lambda_module.lambda_handler(event, None)

        body = _get_body(result)
        assert body["status"] == "skipped"
        mock_aws["s3"].put_object.assert_not_called()

    def test_exact_threshold_saves(self, lambda_module, make_event, mock_aws):
        """Facts at exactly 0.7 are saved (threshold is inclusive boundary)."""
        event = make_event(fact="Borderline fact", confidence="0.7")
        result = lambda_module.lambda_handler(event, None)

        body = _get_body(result)
        assert body["status"] == "saved"

    def test_zero_confidence_skips(self, lambda_module, make_event, mock_aws):
        """Zero confidence is always skipped."""
        event = make_event(fact="No confidence fact", confidence="0.0")
        result = lambda_module.lambda_handler(event, None)

        body = _get_body(result)
        assert body["status"] == "skipped"

    def test_skip_reason_contains_threshold(self, lambda_module, make_event, mock_aws):
        """Skip reason includes the actual threshold value."""
        event = make_event(fact="Low fact", confidence="0.5")
        result = lambda_module.lambda_handler(event, None)

        body = _get_body(result)
        assert "0.7" in body["reason"]
        assert "0.50" in body["reason"]


# ═══════════════════════════════════════════════════════════════════════════════
# Action Group Response Format Tests
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.mark.lambda_handler
class TestActionGroupResponseFormat:
    """Verify response format matches Bedrock action group contract."""

    def test_response_has_message_version(self, lambda_module, make_event, mock_aws):
        result = lambda_module.lambda_handler(make_event(), None)
        assert result["messageVersion"] == "1.0"

    def test_response_has_action_group(self, lambda_module, make_event, mock_aws):
        result = lambda_module.lambda_handler(make_event(), None)
        assert result["response"]["actionGroup"] == "MemoryActions"

    def test_response_has_function_name(self, lambda_module, make_event, mock_aws):
        result = lambda_module.lambda_handler(make_event(), None)
        assert result["response"]["function"] == "save_to_long_term_memory"

    def test_response_body_is_json(self, lambda_module, make_event, mock_aws):
        result = lambda_module.lambda_handler(make_event(), None)
        body = _get_body(result)
        assert isinstance(body, dict)

    def test_saved_response_has_document_key(self, lambda_module, make_event, mock_aws):
        result = lambda_module.lambda_handler(make_event(confidence="0.9"), None)
        body = _get_body(result)
        assert body["status"] == "saved"
        assert "document_key" in body
        assert body["document_key"].startswith("memories/")


# ═══════════════════════════════════════════════════════════════════════════════
# S3 Document Tests
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.mark.lambda_handler
@pytest.mark.s3
class TestS3Document:
    """Verify S3 document structure and key paths."""

    def test_s3_key_includes_category(self, lambda_module, make_event, mock_aws):
        """S3 key includes the category folder."""
        lambda_module.lambda_handler(make_event(category="decision"), None)
        call_args = mock_aws["s3"].put_object.call_args
        assert "memories/decision/" in call_args.kwargs.get("Key", call_args[1].get("Key", ""))

    def test_s3_content_type_is_markdown(self, lambda_module, make_event, mock_aws):
        """Document is written as text/markdown."""
        lambda_module.lambda_handler(make_event(), None)
        call_args = mock_aws["s3"].put_object.call_args
        assert call_args.kwargs.get("ContentType", call_args[1].get("ContentType")) == "text/markdown"

    def test_s3_body_contains_yaml_frontmatter(self, lambda_module, make_event, mock_aws):
        """Document body starts with YAML frontmatter."""
        lambda_module.lambda_handler(make_event(fact="My test fact"), None)
        call_args = mock_aws["s3"].put_object.call_args
        body = call_args.kwargs.get("Body", call_args[1].get("Body"))
        if isinstance(body, bytes):
            body = body.decode("utf-8")
        assert body.startswith("---\n")
        assert "category:" in body

    def test_s3_body_contains_fact(self, lambda_module, make_event, mock_aws):
        """Document body contains the actual fact text."""
        fact = "I prefer eu-west-1 for production"
        lambda_module.lambda_handler(make_event(fact=fact), None)
        call_args = mock_aws["s3"].put_object.call_args
        body = call_args.kwargs.get("Body", call_args[1].get("Body"))
        if isinstance(body, bytes):
            body = body.decode("utf-8")
        assert fact in body

    def test_s3_metadata_has_session_id(self, lambda_module, make_event, mock_aws):
        """S3 object metadata includes session_id."""
        lambda_module.lambda_handler(make_event(session_id="sess-abc"), None)
        call_args = mock_aws["s3"].put_object.call_args
        metadata = call_args.kwargs.get("Metadata", call_args[1].get("Metadata", {}))
        assert metadata["session_id"] == "sess-abc"

    def test_preference_category_path(self, lambda_module, make_event, mock_aws):
        lambda_module.lambda_handler(make_event(category="preference"), None)
        call_args = mock_aws["s3"].put_object.call_args
        key = call_args.kwargs.get("Key", call_args[1].get("Key", ""))
        assert key.startswith("memories/preference/")

    def test_invalid_category_defaults_to_general(self, lambda_module, make_event, mock_aws):
        lambda_module.lambda_handler(make_event(category="invalid_cat"), None)
        call_args = mock_aws["s3"].put_object.call_args
        key = call_args.kwargs.get("Key", call_args[1].get("Key", ""))
        assert "memories/general/" in key


# ═══════════════════════════════════════════════════════════════════════════════
# DynamoDB Tests
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.mark.lambda_handler
@pytest.mark.dynamodb
class TestDynamoDB:
    """Verify DynamoDB audit record structure."""

    def test_dynamodb_put_called_on_save(self, lambda_module, make_event, mock_aws):
        """DynamoDB PutItem is called when a fact is saved."""
        lambda_module.lambda_handler(make_event(confidence="0.9"), None)
        mock_aws["table"].put_item.assert_called_once()

    def test_dynamodb_not_called_on_skip(self, lambda_module, make_event, mock_aws):
        """DynamoDB PutItem is NOT called when a fact is skipped."""
        lambda_module.lambda_handler(make_event(confidence="0.2"), None)
        mock_aws["table"].put_item.assert_not_called()

    def test_dynamodb_record_has_session_id(self, lambda_module, make_event, mock_aws):
        """DynamoDB record partition key is session_id."""
        lambda_module.lambda_handler(make_event(session_id="sess-xyz"), None)
        call_args = mock_aws["table"].put_item.call_args
        item = call_args.kwargs.get("Item", call_args[1].get("Item", {}))
        assert item["session_id"] == "sess-xyz"

    def test_dynamodb_record_has_ttl(self, lambda_module, make_event, mock_aws):
        """DynamoDB record includes TTL attribute."""
        lambda_module.lambda_handler(make_event(), None)
        call_args = mock_aws["table"].put_item.call_args
        item = call_args.kwargs.get("Item", call_args[1].get("Item", {}))
        assert "ttl" in item
        assert item["ttl"] > 0


# ═══════════════════════════════════════════════════════════════════════════════
# Edge Cases
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.mark.lambda_handler
class TestEdgeCases:
    """Test edge cases and error handling."""

    def test_empty_fact_returns_error(self, lambda_module, make_event, mock_aws):
        """Empty fact should return error status."""
        event = make_event(fact="", confidence="0.9")
        result = lambda_module.lambda_handler(event, None)
        body = _get_body(result)
        assert body["status"] == "error"

    def test_whitespace_only_fact_returns_error(self, lambda_module, make_event, mock_aws):
        """Whitespace-only fact should return error."""
        event = make_event(fact="   ", confidence="0.9")
        result = lambda_module.lambda_handler(event, None)
        body = _get_body(result)
        assert body["status"] == "error"

    def test_ingestion_job_id_returned(self, lambda_module, make_event, mock_aws):
        """Successful save returns ingestion job ID."""
        result = lambda_module.lambda_handler(make_event(confidence="0.9"), None)
        body = _get_body(result)
        assert body["ingestion_job_id"] == "ING_TEST_789"
