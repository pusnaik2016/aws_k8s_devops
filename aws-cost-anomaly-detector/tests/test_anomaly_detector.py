"""
test_anomaly_detector.py
------------------------
Unit tests for the Anomaly Detector Lambda function.
Mocks DynamoDB, Bedrock, and SNS — no real AWS calls made.
"""

import json
import math
import os
from unittest.mock import MagicMock, patch

import pytest

# ── Environment variables BEFORE import ────────────────────────────────────
os.environ.setdefault("DYNAMODB_TABLE",   "cost-history-test")
os.environ.setdefault("SNS_TOPIC_ARN",    "arn:aws:sns:us-east-1:123456789012:test-topic")
os.environ.setdefault("BEDROCK_MODEL_ID", "anthropic.claude-3-5-sonnet-20241022-v2:0")
os.environ.setdefault("ZSCORE_THRESHOLD", "2.5")
os.environ.setdefault("MIN_HISTORY_DAYS", "14")
os.environ.setdefault("AWS_REGION_NAME",  "us-east-1")
os.environ.setdefault("LOG_LEVEL",        "WARNING")

import sys
sys.path.insert(0, "modules/cost_analyzer/lambda")

import anomaly_detector


###############################################################################
# Fixtures
###############################################################################

def make_history(days: int, base_cost: float, spike_cost: float | None = None):
    """
    Build a synthetic cost history list of (date, amount) tuples.
    If spike_cost is provided, the last entry is the spike.
    """
    entries = []
    for i in range(days):
        date_str = f"2026-01-{i+1:02d}"
        cost = spike_cost if (spike_cost is not None and i == days - 1) else base_cost
        entries.append((date_str, cost))
    return entries


###############################################################################
# Tests — zscore
###############################################################################

class TestZscore:
    def test_positive_spike(self):
        """A large spike should produce a high positive Z-score."""
        history = [10.0] * 30
        z = anomaly_detector.zscore(100.0, history)
        assert z > 2.5

    def test_negative_spike(self):
        """A large drop should produce a high negative Z-score."""
        history = [100.0] * 30
        z = anomaly_detector.zscore(10.0, history)
        assert z < -2.5

    def test_no_change(self):
        """Value equal to the mean should produce Z-score of 0."""
        history = [10.0] * 30
        z = anomaly_detector.zscore(10.0, history)
        assert z == 0.0

    def test_empty_history_returns_zero(self):
        z = anomaly_detector.zscore(50.0, [])
        assert z == 0.0

    def test_constant_history_returns_zero(self):
        """Zero std_dev should return 0.0 to avoid division by zero."""
        z = anomaly_detector.zscore(10.0, [10.0, 10.0, 10.0])
        assert z == 0.0

    def test_mathematical_correctness(self):
        """Verify Z-score calculation matches manual computation."""
        history = [1.0, 2.0, 3.0, 4.0, 5.0]
        value   = 10.0
        mean    = sum(history) / len(history)       # 3.0
        std     = math.sqrt(sum((x - mean)**2 for x in history) / len(history))  # ~1.414
        expected_z = (value - mean) / std

        z = anomaly_detector.zscore(value, history)
        assert abs(z - expected_z) < 1e-9

    def test_single_value_history(self):
        """Single-value history has std_dev = 0 → returns 0."""
        z = anomaly_detector.zscore(5.0, [3.0])
        assert z == 0.0


###############################################################################
# Tests — detect_anomalies
###############################################################################

class TestDetectAnomalies:
    def test_detects_obvious_spike(self):
        """A 10,000% spike should clearly be flagged."""
        history = {"Amazon EC2": make_history(30, 10.0, spike_cost=10000.0)}
        anomalies = anomaly_detector.detect_anomalies(history)

        assert len(anomalies) == 1
        assert anomalies[0]["service"] == "Amazon EC2"
        assert anomalies[0]["zscore"] > 2.5

    def test_ignores_stable_costs(self):
        """Costs with no variation should not be flagged."""
        history = {"Amazon EC2": make_history(30, 10.0)}
        anomalies = anomaly_detector.detect_anomalies(history)
        assert len(anomalies) == 0

    def test_skips_insufficient_history(self):
        """Services with fewer than MIN_HISTORY_DAYS+1 entries are skipped."""
        history = {"Amazon EC2": make_history(5, 10.0, spike_cost=1000.0)}
        anomalies = anomaly_detector.detect_anomalies(history)
        assert len(anomalies) == 0

    def test_sorted_by_zscore_descending(self):
        """Anomalies should be sorted so highest Z-score is first."""
        history = {
            "Amazon EC2":  make_history(30, 10.0,  spike_cost=100.0),
            "Amazon S3":   make_history(30, 10.0,  spike_cost=5000.0),
            "AWS Lambda":  make_history(30, 5.0,   spike_cost=50.0),
        }
        anomalies = anomaly_detector.detect_anomalies(history)
        z_scores = [abs(a["zscore"]) for a in anomalies]
        assert z_scores == sorted(z_scores, reverse=True)

    def test_result_structure(self):
        """Each anomaly dict must have all required keys."""
        history = {"Amazon EC2": make_history(30, 10.0, spike_cost=1000.0)}
        anomalies = anomaly_detector.detect_anomalies(history)

        assert len(anomalies) == 1
        a = anomalies[0]
        for key in ["service", "date", "cost_usd", "mean_usd", "delta_pct", "zscore", "history_30d"]:
            assert key in a, f"Missing key: {key}"

    def test_excludes_today_from_baseline(self):
        """The last entry (today) should NOT be included in the mean calculation."""
        # Build 29 stable days + 1 spike
        entries = [(f"2026-01-{i+1:02d}", 10.0) for i in range(29)]
        entries.append(("2026-01-30", 10000.0))
        history = {"Amazon EC2": entries}

        anomalies = anomaly_detector.detect_anomalies(history)

        assert len(anomalies) == 1
        # Mean should be ~10.0 (baseline of stable days), not influenced by spike
        assert abs(anomalies[0]["mean_usd"] - 10.0) < 0.01

    def test_negative_spike_flagged(self):
        """A large cost DROP is also anomalous (|z| >= threshold)."""
        history = {"Amazon EC2": make_history(30, 100.0, spike_cost=1.0)}
        anomalies = anomaly_detector.detect_anomalies(history)
        assert len(anomalies) == 1
        assert anomalies[0]["zscore"] < 0   # negative Z means cost dropped

    def test_multiple_services(self):
        """Multiple anomalous services should all be returned."""
        history = {
            "Amazon EC2": make_history(30, 10.0, spike_cost=1000.0),
            "Amazon S3":  make_history(30, 5.0,  spike_cost=500.0),
            "AWS Lambda": make_history(30, 1.0),  # no spike
        }
        anomalies = anomaly_detector.detect_anomalies(history)
        services = [a["service"] for a in anomalies]

        assert "Amazon EC2" in services
        assert "Amazon S3"  in services
        assert "AWS Lambda" not in services


###############################################################################
# Tests — build_prompt
###############################################################################

class TestBuildPrompt:
    def get_sample_anomaly(self):
        return {
            "service"    : "Amazon EC2",
            "date"       : "2026-03-15",
            "cost_usd"   : 500.0,
            "mean_usd"   : 10.0,
            "delta_pct"  : 4900.0,
            "zscore"     : 45.5,
            "history_30d": [9.5, 10.1, 9.8, 10.2, 10.0],
        }

    def test_prompt_contains_service_name(self):
        anomaly = self.get_sample_anomaly()
        prompt = anomaly_detector.build_prompt([anomaly])
        assert "Amazon EC2" in prompt

    def test_prompt_contains_zscore(self):
        anomaly = self.get_sample_anomaly()
        prompt = anomaly_detector.build_prompt([anomaly])
        assert "45.5" in prompt or "45.50" in prompt

    def test_prompt_contains_cost_figures(self):
        anomaly = self.get_sample_anomaly()
        prompt = anomaly_detector.build_prompt([anomaly])
        assert "$500.0000" in prompt or "500.0000" in prompt

    def test_prompt_includes_finops_role(self):
        """Prompt must establish the FinOps role for the LLM."""
        anomaly = self.get_sample_anomaly()
        prompt = anomaly_detector.build_prompt([anomaly])
        assert "FinOps" in prompt or "AWS" in prompt

    def test_prompt_with_multiple_anomalies(self):
        a1 = self.get_sample_anomaly()
        a2 = {**a1, "service": "Amazon S3", "zscore": 10.2}
        prompt = anomaly_detector.build_prompt([a1, a2])
        assert "Amazon EC2" in prompt
        assert "Amazon S3" in prompt


###############################################################################
# Tests — format_email
###############################################################################

class TestFormatEmail:
    def get_sample_anomaly(self):
        return {
            "service"    : "Amazon EC2",
            "date"       : "2026-03-15",
            "cost_usd"   : 500.0,
            "mean_usd"   : 10.0,
            "delta_pct"  : 4900.0,
            "zscore"     : 45.5,
            "history_30d": [10.0, 10.0],
        }

    def test_subject_contains_count(self):
        anomalies = [self.get_sample_anomaly(), self.get_sample_anomaly()]
        subject, _ = anomaly_detector.format_email(anomalies, "AI analysis here")
        assert "2" in subject

    def test_subject_contains_date(self):
        import datetime
        today = datetime.date.today().isoformat()
        anomalies = [self.get_sample_anomaly()]
        subject, _ = anomaly_detector.format_email(anomalies, "AI analysis")
        assert today in subject

    def test_body_contains_ai_analysis(self):
        anomalies = [self.get_sample_anomaly()]
        _, body = anomaly_detector.format_email(anomalies, "SEVERITY: HIGH\nLIKELY CAUSE: NAT Gateway")
        assert "NAT Gateway" in body

    def test_body_contains_service_name(self):
        anomalies = [self.get_sample_anomaly()]
        _, body = anomaly_detector.format_email(anomalies, "analysis")
        assert "Amazon EC2" in body

    def test_subject_max_100_chars(self):
        """SNS subject limit is 100 characters."""
        anomalies = [self.get_sample_anomaly()]
        subject, _ = anomaly_detector.format_email(anomalies, "analysis")
        assert len(subject) <= 100


###############################################################################
# Tests — lambda_handler
###############################################################################

class TestLambdaHandler:
    @patch("anomaly_detector.publish_alert")
    @patch("anomaly_detector.invoke_bedrock", return_value="SEVERITY: HIGH\nLIKELY CAUSE: NAT Gateway")
    @patch("anomaly_detector.detect_anomalies")
    @patch("anomaly_detector.load_history", return_value={})
    def test_no_anomalies_no_alert(self, mock_load, mock_detect, mock_bedrock, mock_sns):
        mock_detect.return_value = []

        result = anomaly_detector.lambda_handler({}, MagicMock())

        assert result["statusCode"] == 200
        assert result["anomalies_found"] == 0
        assert result["alert_sent"] is False
        mock_bedrock.assert_not_called()
        mock_sns.assert_not_called()

    @patch("anomaly_detector.publish_alert")
    @patch("anomaly_detector.invoke_bedrock", return_value="Analysis text")
    @patch("anomaly_detector.detect_anomalies")
    @patch("anomaly_detector.load_history", return_value={})
    def test_anomalies_trigger_bedrock_and_sns(self, mock_load, mock_detect, mock_bedrock, mock_sns):
        mock_detect.return_value = [{
            "service"    : "Amazon EC2",
            "date"       : "2026-03-15",
            "cost_usd"   : 500.0,
            "mean_usd"   : 10.0,
            "delta_pct"  : 4900.0,
            "zscore"     : 45.5,
            "history_30d": [10.0],
        }]

        result = anomaly_detector.lambda_handler({}, MagicMock())

        assert result["statusCode"] == 200
        assert result["anomalies_found"] == 1
        assert result["alert_sent"] is True
        mock_bedrock.assert_called_once()
        mock_sns.assert_called_once()

    @patch("anomaly_detector.load_history", side_effect=Exception("DynamoDB error"))
    def test_reraises_exceptions(self, mock_load):
        with pytest.raises(Exception, match="DynamoDB error"):
            anomaly_detector.lambda_handler({}, MagicMock())
