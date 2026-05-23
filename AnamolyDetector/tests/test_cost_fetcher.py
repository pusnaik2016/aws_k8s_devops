"""
test_cost_fetcher.py
---------------------
Unit tests for the Cost Fetcher Lambda function.
Uses moto to mock AWS services (DynamoDB, Cost Explorer).
"""

import json
import os
from datetime import date, timedelta
from decimal import Decimal
from unittest.mock import MagicMock, call, patch

import pytest

# ── Set environment variables BEFORE importing the Lambda ──────────────────
os.environ.setdefault("DYNAMODB_TABLE",  "cost-history-test")
os.environ.setdefault("RETENTION_DAYS", "90")
os.environ.setdefault("LOG_LEVEL",       "WARNING")

# Add lambda dir to path so we can import directly
import sys
sys.path.insert(0, "modules/cost_analyzer/lambda")

import cost_fetcher


###############################################################################
# Fixtures
###############################################################################

MOCK_CE_RESPONSE = {
    "ResultsByTime": [
        {
            "TimePeriod": {"Start": "2026-01-01", "End": "2026-01-02"},
            "Groups": [
                {
                    "Keys": ["Amazon EC2"],
                    "Metrics": {"BlendedCost": {"Amount": "10.50", "Unit": "USD"}},
                },
                {
                    "Keys": ["Amazon S3"],
                    "Metrics": {"BlendedCost": {"Amount": "5.25", "Unit": "USD"}},
                },
                {
                    "Keys": ["AWS Lambda"],
                    "Metrics": {"BlendedCost": {"Amount": "0.00", "Unit": "USD"}},
                },
            ],
        },
        {
            "TimePeriod": {"Start": "2026-01-02", "End": "2026-01-03"},
            "Groups": [
                {
                    "Keys": ["Amazon EC2"],
                    "Metrics": {"BlendedCost": {"Amount": "12.00", "Unit": "USD"}},
                },
            ],
        },
    ],
    "NextPageToken": None,
}


###############################################################################
# Tests — fetch_cost_data
###############################################################################

class TestFetchCostData:
    @patch("cost_fetcher.ce_client")
    def test_returns_non_zero_records_only(self, mock_ce):
        """Zero-cost rows should be filtered out."""
        mock_ce.get_cost_and_usage.return_value = MOCK_CE_RESPONSE

        results = cost_fetcher.fetch_cost_data("2026-01-01", "2026-01-03")

        # AWS Lambda had $0.00 — should not appear
        services = [r["service"] for r in results]
        assert "AWS Lambda" not in services
        assert "Amazon EC2" in services
        assert "Amazon S3" in services

    @patch("cost_fetcher.ce_client")
    def test_handles_pagination(self, mock_ce):
        """Pagination via NextPageToken should fetch all pages."""
        page1 = {
            "ResultsByTime": [
                {
                    "TimePeriod": {"Start": "2026-01-01", "End": "2026-01-02"},
                    "Groups": [
                        {"Keys": ["Amazon EC2"], "Metrics": {"BlendedCost": {"Amount": "5.0", "Unit": "USD"}}},
                    ],
                }
            ],
            "NextPageToken": "TOKEN_PAGE_2",
        }
        page2 = {
            "ResultsByTime": [
                {
                    "TimePeriod": {"Start": "2026-01-02", "End": "2026-01-03"},
                    "Groups": [
                        {"Keys": ["Amazon S3"], "Metrics": {"BlendedCost": {"Amount": "3.0", "Unit": "USD"}}},
                    ],
                }
            ],
        }

        mock_ce.get_cost_and_usage.side_effect = [page1, page2]

        results = cost_fetcher.fetch_cost_data("2026-01-01", "2026-01-03")

        assert mock_ce.get_cost_and_usage.call_count == 2
        assert len(results) == 2

    @patch("cost_fetcher.ce_client")
    def test_result_structure(self, mock_ce):
        """Each result must have service, date, and amount fields."""
        mock_ce.get_cost_and_usage.return_value = MOCK_CE_RESPONSE

        results = cost_fetcher.fetch_cost_data("2026-01-01", "2026-01-03")

        for r in results:
            assert "service" in r
            assert "date" in r
            assert "amount" in r
            assert isinstance(r["amount"], float)

    @patch("cost_fetcher.ce_client")
    def test_empty_response(self, mock_ce):
        """Empty Cost Explorer response returns empty list."""
        mock_ce.get_cost_and_usage.return_value = {"ResultsByTime": []}

        results = cost_fetcher.fetch_cost_data("2026-01-01", "2026-01-02")
        assert results == []


###############################################################################
# Tests — compute_expiry_ts
###############################################################################

class TestComputeExpiryTs:
    def test_returns_future_timestamp(self):
        import time
        ts = cost_fetcher.compute_expiry_ts(90)
        assert ts > int(time.time())

    def test_approximately_90_days_in_future(self):
        import time
        ts = cost_fetcher.compute_expiry_ts(90)
        expected = int(time.time()) + 90 * 86400
        # Allow 5 second tolerance
        assert abs(ts - expected) < 5

    def test_different_retention_periods(self):
        ts_30 = cost_fetcher.compute_expiry_ts(30)
        ts_90 = cost_fetcher.compute_expiry_ts(90)
        assert ts_90 > ts_30


###############################################################################
# Tests — upsert_records
###############################################################################

class TestUpsertRecords:
    @patch("cost_fetcher.table")
    def test_writes_correct_number_of_records(self, mock_table):
        """batch_writer should be called with all records."""
        mock_batch = MagicMock()
        mock_table.batch_writer.return_value.__enter__ = MagicMock(return_value=mock_batch)
        mock_table.batch_writer.return_value.__exit__ = MagicMock(return_value=False)

        records = [
            {"service": "Amazon EC2", "date": "2026-01-01", "amount": 10.5},
            {"service": "Amazon S3", "date": "2026-01-01", "amount": 5.25},
        ]

        count = cost_fetcher.upsert_records(records)

        assert count == 2
        assert mock_batch.put_item.call_count == 2

    @patch("cost_fetcher.table")
    def test_item_has_expiry_ts(self, mock_table):
        """Written items must include expiry_ts for TTL."""
        written_items = []

        mock_batch = MagicMock()
        mock_batch.put_item.side_effect = lambda Item: written_items.append(Item)
        mock_table.batch_writer.return_value.__enter__ = MagicMock(return_value=mock_batch)
        mock_table.batch_writer.return_value.__exit__ = MagicMock(return_value=False)

        cost_fetcher.upsert_records([
            {"service": "Amazon EC2", "date": "2026-01-01", "amount": 10.5},
        ])

        assert len(written_items) == 1
        item = written_items[0]
        assert "expiry_ts" in item
        assert "service" in item
        assert "date" in item
        assert "amount" in item

    @patch("cost_fetcher.table")
    def test_empty_records_returns_zero(self, mock_table):
        mock_batch = MagicMock()
        mock_table.batch_writer.return_value.__enter__ = MagicMock(return_value=mock_batch)
        mock_table.batch_writer.return_value.__exit__ = MagicMock(return_value=False)

        count = cost_fetcher.upsert_records([])
        assert count == 0


###############################################################################
# Tests — lambda_handler
###############################################################################

class TestLambdaHandler:
    @patch("cost_fetcher.upsert_records", return_value=10)
    @patch("cost_fetcher.fetch_cost_data")
    def test_returns_200_on_success(self, mock_fetch, mock_upsert):
        mock_fetch.return_value = [
            {"service": "Amazon EC2", "date": "2026-01-01", "amount": 10.5},
        ]

        result = cost_fetcher.lambda_handler({}, MagicMock())

        assert result["statusCode"] == 200
        assert result["records"] == 10

    @patch("cost_fetcher.fetch_cost_data", side_effect=Exception("API error"))
    def test_reraises_exceptions(self, mock_fetch):
        with pytest.raises(Exception, match="API error"):
            cost_fetcher.lambda_handler({}, MagicMock())

    @patch("cost_fetcher.upsert_records", return_value=5)
    @patch("cost_fetcher.fetch_cost_data")
    def test_date_window_is_correct(self, mock_fetch, mock_upsert):
        """Start date should be RETENTION_DAYS before today."""
        mock_fetch.return_value = []

        cost_fetcher.lambda_handler({}, MagicMock())

        call_args = mock_fetch.call_args
        start, end = call_args[0]

        start_date = date.fromisoformat(start)
        end_date   = date.fromisoformat(end)
        delta      = end_date - start_date

        assert delta.days == int(os.environ["RETENTION_DAYS"])
