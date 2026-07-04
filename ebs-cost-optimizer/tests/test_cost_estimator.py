"""
Tests for CostEstimator.
"""

from __future__ import annotations

import pytest

from src.cost_estimator import CostEstimator


def _vol(vol_type: str = "gp2", size_gb: int = 100, iops: int | None = None, state: str = "in-use") -> dict:
    return {
        "volume_type": vol_type,
        "size_gb": size_gb,
        "iops": iops,
        "state": state,
    }


class TestCostEstimator:
    def test_gp2_pricing(self):
        est = CostEstimator()
        assert est.monthly_cost_usd(_vol("gp2", 100)) == pytest.approx(10.0)

    def test_gp3_pricing(self):
        est = CostEstimator()
        assert est.monthly_cost_usd(_vol("gp3", 100)) == pytest.approx(8.0)

    def test_io1_includes_iops(self):
        est = CostEstimator()
        # 100 GB @ $0.125 + 1000 IOPS @ $0.065 = 12.5 + 65 = 77.5
        assert est.monthly_cost_usd(_vol("io1", 100, iops=1000)) == pytest.approx(77.5)

    def test_st1_pricing(self):
        est = CostEstimator()
        assert est.monthly_cost_usd(_vol("st1", 1000)) == pytest.approx(45.0)

    def test_gp3_savings_on_gp2(self):
        est = CostEstimator()
        # 100 GB: gp2=$10, gp3=$8 → savings=$2
        assert est.gp3_savings_usd(_vol("gp2", 100)) == pytest.approx(2.0)

    def test_gp3_savings_zero_for_gp3(self):
        est = CostEstimator()
        assert est.gp3_savings_usd(_vol("gp3", 100)) == 0.0

    def test_recommendation_delete_for_available(self):
        est = CostEstimator()
        assert est.recommendation(_vol(state="available"), []) == "DELETE"

    def test_recommendation_migrate_gp2(self):
        est = CostEstimator()
        assert est.recommendation(_vol("gp2", state="in-use"), []) == "MIGRATE_TO_GP3"

    def test_recommendation_add_tags(self):
        est = CostEstimator()
        assert est.recommendation(_vol("gp3", state="in-use"), ["Owner"]) == "ADD_TAGS"

    def test_recommendation_compliant(self):
        est = CostEstimator()
        assert est.recommendation(_vol("gp3", state="in-use"), []) == "COMPLIANT"

    def test_enrich_adds_monthly_cost(self):
        est = CostEstimator()
        volumes = [_vol("gp2", 50), _vol("gp3", 200)]
        est.enrich(volumes)
        assert volumes[0]["monthly_cost_usd"] == pytest.approx(5.0)
        assert volumes[1]["monthly_cost_usd"] == pytest.approx(16.0)
