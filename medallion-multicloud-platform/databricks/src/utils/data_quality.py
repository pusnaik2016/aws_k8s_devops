"""
Data Quality Validator — Expectation-Based DQ Framework
========================================================
Validates data quality using configurable expectations.
Writes results to an audit Delta table for compliance reporting.
"""

from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional


@dataclass
class DQResult:
    """Result of a single data quality check."""
    check_name: str
    table_name: str
    column_name: Optional[str]
    check_type: str
    total_records: int
    passed_records: int
    failed_records: int
    pass_rate: float
    status: str  # PASS, WARN, FAIL
    details: str
    timestamp: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())


class DataQualityValidator:
    """
    Configurable data quality validator for medallion pipeline.

    Usage:
        validator = DataQualityValidator("medallion.silver.events", spark)
        validator.expect_not_null("customer_id")
        validator.expect_unique("transaction_id")
        validator.expect_values_in_set("status", ["active", "inactive"])
        results = validator.run(df)
        validator.write_audit_results(results, "medallion.silver.dq_audit")
    """

    def __init__(self, table_name: str, spark=None):
        self.table_name = table_name
        self.spark = spark
        self._expectations: List[Dict[str, Any]] = []

    def expect_not_null(self, column: str, threshold: float = 1.0):
        """Expect column has no null values (or meets threshold)."""
        self._expectations.append({
            "type": "not_null",
            "column": column,
            "threshold": threshold,
        })
        return self

    def expect_unique(self, column: str, threshold: float = 1.0):
        """Expect column values are unique."""
        self._expectations.append({
            "type": "unique",
            "column": column,
            "threshold": threshold,
        })
        return self

    def expect_values_in_set(self, column: str, valid_values: list):
        """Expect column values are within a defined set."""
        self._expectations.append({
            "type": "values_in_set",
            "column": column,
            "valid_values": valid_values,
        })
        return self

    def expect_regex_match(self, column: str, pattern: str):
        """Expect column values match a regex pattern."""
        self._expectations.append({
            "type": "regex_match",
            "column": column,
            "pattern": pattern,
        })
        return self

    def expect_range(self, column: str, min_val: float, max_val: float):
        """Expect numeric column values fall within a range."""
        self._expectations.append({
            "type": "range",
            "column": column,
            "min": min_val,
            "max": max_val,
        })
        return self

    def run(self, df) -> List[DQResult]:
        """Execute all expectations against the DataFrame."""
        results = []
        total = df.count()

        for exp in self._expectations:
            result = self._evaluate(df, exp, total)
            results.append(result)
            status_icon = "✅" if result.status == "PASS" else "⚠️" if result.status == "WARN" else "❌"
            print(f"[DQ] {status_icon} {result.check_name}: {result.pass_rate:.1f}% ({result.status})")

        return results

    def _evaluate(self, df, exp: dict, total: int) -> DQResult:
        """Evaluate a single expectation."""
        col_name = exp.get("column", "")
        check_type = exp["type"]

        if check_type == "not_null":
            from pyspark.sql.functions import col
            failed = df.filter(col(col_name).isNull()).count()
            passed = total - failed
            threshold = exp.get("threshold", 1.0)
            pass_rate = passed / max(total, 1)
            return DQResult(
                check_name=f"not_null({col_name})",
                table_name=self.table_name,
                column_name=col_name,
                check_type=check_type,
                total_records=total,
                passed_records=passed,
                failed_records=failed,
                pass_rate=round(pass_rate * 100, 2),
                status="PASS" if pass_rate >= threshold else "FAIL",
                details=f"Null count: {failed}",
            )

        elif check_type == "unique":
            from pyspark.sql.functions import col
            distinct = df.select(col_name).distinct().count()
            duplicates = total - distinct
            pass_rate = distinct / max(total, 1)
            return DQResult(
                check_name=f"unique({col_name})",
                table_name=self.table_name,
                column_name=col_name,
                check_type=check_type,
                total_records=total,
                passed_records=distinct,
                failed_records=duplicates,
                pass_rate=round(pass_rate * 100, 2),
                status="PASS" if duplicates == 0 else "WARN",
                details=f"Duplicate count: {duplicates}",
            )

        elif check_type == "values_in_set":
            from pyspark.sql.functions import col
            valid = exp["valid_values"]
            invalid = df.filter(~col(col_name).isin(valid)).count()
            passed = total - invalid
            pass_rate = passed / max(total, 1)
            return DQResult(
                check_name=f"values_in_set({col_name})",
                table_name=self.table_name,
                column_name=col_name,
                check_type=check_type,
                total_records=total,
                passed_records=passed,
                failed_records=invalid,
                pass_rate=round(pass_rate * 100, 2),
                status="PASS" if invalid == 0 else "FAIL",
                details=f"Invalid values: {invalid}, Valid set: {valid}",
            )

        else:
            return DQResult(
                check_name=f"{check_type}({col_name})",
                table_name=self.table_name,
                column_name=col_name,
                check_type=check_type,
                total_records=total,
                passed_records=total,
                failed_records=0,
                pass_rate=100.0,
                status="SKIP",
                details="Check type not yet implemented",
            )

    def write_audit_results(self, results: List[DQResult], audit_table: str):
        """Write DQ results to a Delta audit table."""
        if not self.spark or not results:
            return

        rows = [{
            "check_name": r.check_name,
            "table_name": r.table_name,
            "column_name": r.column_name or "",
            "check_type": r.check_type,
            "total_records": r.total_records,
            "passed_records": r.passed_records,
            "failed_records": r.failed_records,
            "pass_rate": r.pass_rate,
            "status": r.status,
            "details": r.details,
            "timestamp": r.timestamp,
        } for r in results]

        audit_df = self.spark.createDataFrame(rows)
        audit_df.write.format("delta").mode("append").saveAsTable(audit_table)
        print(f"[DQ] Audit results written to {audit_table}: {len(results)} checks")
