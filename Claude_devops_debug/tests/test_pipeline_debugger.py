"""Tests for Tool 2: CI/CD Pipeline Debugger."""

import pytest
from tools.pipeline_debugger import PipelineDebugger


class TestPipelineDebugger:

    def test_detect_dependency_failure(self, pipeline_samples):
        debugger = PipelineDebugger()
        result = debugger.analyze(str(pipeline_samples / "github_actions_fail.log"))
        assert not result.passed
        rule_ids = [f.rule_id for f in result.findings]
        assert "PIPE001" in rule_ids  # Dependency failure

    def test_detect_pipeline_type(self, pipeline_samples):
        debugger = PipelineDebugger()
        result = debugger.analyze(str(pipeline_samples / "github_actions_fail.log"))
        assert result.summary.get("pipeline_type") == "GitHub Actions"

    def test_counts_errors_and_warnings(self, pipeline_samples):
        debugger = PipelineDebugger()
        result = debugger.analyze(str(pipeline_samples / "github_actions_fail.log"))
        assert result.summary.get("error_lines", 0) > 0

    def test_missing_log_file(self):
        debugger = PipelineDebugger()
        result = debugger.analyze("/nonexistent/build.log")
        rule_ids = [f.rule_id for f in result.findings]
        assert "PIPE000" in rule_ids

    def test_result_serializable(self, pipeline_samples):
        debugger = PipelineDebugger()
        result = debugger.analyze(str(pipeline_samples / "github_actions_fail.log"))
        json_str = result.to_json()
        assert "CI/CD Pipeline Debugger" in json_str
