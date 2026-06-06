"""Tests for Tool 10: Cost Optimizer."""

import pytest
from tools.cost_optimizer import CostOptimizer


class TestCostOptimizer:

    def test_detects_oversized_instance(self, terraform_samples):
        optimizer = CostOptimizer()
        result = optimizer.analyze(str(terraform_samples))
        rule_ids = [f.rule_id for f in result.findings]
        assert "COST001" in rule_ids

    def test_detects_previous_gen_instance(self, terraform_samples):
        optimizer = CostOptimizer()
        result = optimizer.analyze(str(terraform_samples))
        rule_ids = [f.rule_id for f in result.findings]
        assert "COST002" in rule_ids

    def test_detects_gp2_volumes(self, terraform_samples):
        optimizer = CostOptimizer()
        result = optimizer.analyze(str(terraform_samples))
        rule_ids = [f.rule_id for f in result.findings]
        assert "COST003" in rule_ids

    def test_detects_nat_gateway(self, terraform_samples):
        optimizer = CostOptimizer()
        result = optimizer.analyze(str(terraform_samples))
        rule_ids = [f.rule_id for f in result.findings]
        assert "COST004" in rule_ids

    def test_detects_multi_az_non_prod(self, terraform_samples):
        optimizer = CostOptimizer()
        result = optimizer.analyze(str(terraform_samples))
        rule_ids = [f.rule_id for f in result.findings]
        assert "COST008" in rule_ids

    def test_estimates_savings(self, terraform_samples):
        optimizer = CostOptimizer()
        result = optimizer.analyze(str(terraform_samples))
        savings = result.summary.get("estimated_monthly_savings", "$0")
        assert savings != "$0"  # Should have found some savings

    def test_no_tf_files(self, tmp_path):
        optimizer = CostOptimizer()
        result = optimizer.analyze(str(tmp_path))
        assert len(result.findings) >= 1
