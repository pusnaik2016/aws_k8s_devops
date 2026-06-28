"""Unit tests for the data quality validation framework."""

import pytest
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))
from utils.data_quality import DataQualityValidator, DQResult


class TestDQResult:
    def test_result_fields(self):
        result = DQResult(
            check_name="not_null(id)",
            table_name="test_table",
            column_name="id",
            check_type="not_null",
            total_records=100,
            passed_records=95,
            failed_records=5,
            pass_rate=95.0,
            status="WARN",
            details="Null count: 5"
        )
        assert result.pass_rate == 95.0
        assert result.status == "WARN"
        assert result.timestamp is not None


class TestDataQualityValidator:
    def test_validator_initialization(self):
        v = DataQualityValidator("test.table")
        assert v.table_name == "test.table"
        assert len(v._expectations) == 0

    def test_expect_not_null_adds_expectation(self):
        v = DataQualityValidator("test.table")
        v.expect_not_null("id")
        assert len(v._expectations) == 1
        assert v._expectations[0]["type"] == "not_null"

    def test_expect_unique_adds_expectation(self):
        v = DataQualityValidator("test.table")
        v.expect_unique("email")
        assert v._expectations[0]["type"] == "unique"

    def test_expect_values_in_set(self):
        v = DataQualityValidator("test.table")
        v.expect_values_in_set("status", ["active", "inactive"])
        assert v._expectations[0]["valid_values"] == ["active", "inactive"]

    def test_chaining(self):
        v = DataQualityValidator("test.table")
        result = v.expect_not_null("id").expect_unique("email").expect_range("amount", 0, 1000)
        assert result is v
        assert len(v._expectations) == 3
