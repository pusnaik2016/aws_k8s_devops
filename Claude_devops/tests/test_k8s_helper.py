"""
test_k8s_helper.py — Kubernetes Diagnostics Test Suite
========================================================
Tests the K8s manifest analyser against the examples/k8s/ directory.
Validates workload detection, security checks, resource limits, probes, and HA config.
"""

import pytest
from pathlib import Path


# ═══════════════════════════════════════════════════════════════════════════════
# Workload Discovery Tests
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.mark.kubernetes
class TestWorkloadDiscovery:
    """Tests that the scanner correctly discovers K8s workloads."""

    def test_discovers_all_manifests(self, k8s_report):
        """Scanner must find both YAML manifest files in examples/k8s/."""
        assert k8s_report.manifests_analysed >= 2, (
            f"Only {k8s_report.manifests_analysed} manifests found — expected >= 2. "
            f"Check _find_yaml_files() logic."
        )

    def test_discovers_all_workloads(self, k8s_report):
        """Scanner must detect both Deployment workloads (frontend + backend)."""
        workload_names = [w.name for w in k8s_report.workloads]
        assert "frontend" in workload_names, (
            "Frontend Deployment not found. "
            "Check examples/k8s/frontend.yaml exists and has kind: Deployment."
        )
        assert "backend" in workload_names, (
            "Backend Deployment not found. "
            "Check examples/k8s/backend.yaml exists and has kind: Deployment."
        )

    def test_detects_correct_namespace(self, k8s_report):
        """All workloads should be in the 'sample-app' namespace."""
        assert "sample-app" in k8s_report.namespaces, (
            f"Expected namespace 'sample-app' but found: {k8s_report.namespaces}. "
            f"Check namespace field in example manifests."
        )


# ═══════════════════════════════════════════════════════════════════════════════
# Security Context Tests
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.mark.kubernetes
class TestK8sSecurity:
    """Tests for Kubernetes security context validation."""

    def test_backend_runs_as_non_root(self, k8s_report):
        """Backend deployment MUST run as non-root (it has securityContext)."""
        backend = next((w for w in k8s_report.workloads if w.name == "backend"), None)
        assert backend is not None, "Backend workload not found"
        assert backend.runs_as_non_root, (
            "Backend deployment should have runAsNonRoot: true set. "
            "The examples/k8s/backend.yaml includes this setting."
        )

    def test_frontend_flagged_for_root(self, k8s_report):
        """Frontend deployment should be flagged for missing runAsNonRoot."""
        frontend = next((w for w in k8s_report.workloads if w.name == "frontend"), None)
        assert frontend is not None, "Frontend workload not found"
        assert not frontend.runs_as_non_root, (
            "Frontend should be detected as potentially running as root. "
            "The examples/k8s/frontend.yaml intentionally omits securityContext."
        )

    def test_backend_disables_privilege_escalation(self, k8s_report):
        """Backend must have allowPrivilegeEscalation: false."""
        backend = next((w for w in k8s_report.workloads if w.name == "backend"), None)
        assert backend is not None, "Backend workload not found"
        assert backend.no_privilege_escalation, (
            "Backend should have allowPrivilegeEscalation: false. "
            "This is set in examples/k8s/backend.yaml."
        )

    def test_frontend_missing_privilege_escalation_block(self, k8s_report):
        """Frontend should be flagged for missing privilege escalation control."""
        frontend = next((w for w in k8s_report.workloads if w.name == "frontend"), None)
        assert frontend is not None, "Frontend workload not found"
        assert not frontend.no_privilege_escalation, (
            "Frontend should be flagged: allowPrivilegeEscalation not set. "
            "Intentional omission in examples/ for scanner demonstration."
        )

    def test_backend_has_read_only_root_fs(self, k8s_report):
        """Backend should have readOnlyRootFilesystem: true."""
        backend = next((w for w in k8s_report.workloads if w.name == "backend"), None)
        assert backend is not None, "Backend workload not found"
        assert backend.read_only_root_fs, (
            "Backend should have readOnlyRootFilesystem: true. "
            "This hardens the container against filesystem-based attacks."
        )


# ═══════════════════════════════════════════════════════════════════════════════
# Resource Limits Tests
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.mark.kubernetes
class TestK8sResources:
    """Tests for resource requests and limits."""

    def test_backend_has_resource_limits(self, k8s_report):
        """Backend deployment must define CPU/memory limits."""
        backend = next((w for w in k8s_report.workloads if w.name == "backend"), None)
        assert backend is not None, "Backend workload not found"
        assert backend.has_resources, (
            "Backend deployment missing resource requests. "
            "Define resources.requests.cpu and resources.requests.memory."
        )
        assert backend.has_limits, (
            "Backend deployment missing resource limits. "
            "Define resources.limits.cpu and resources.limits.memory to prevent noisy-neighbour issues."
        )

    def test_frontend_has_resource_limits(self, k8s_report):
        """Frontend deployment must define CPU/memory limits."""
        frontend = next((w for w in k8s_report.workloads if w.name == "frontend"), None)
        assert frontend is not None, "Frontend workload not found"
        assert frontend.has_resources, "Frontend missing resource requests."
        assert frontend.has_limits, "Frontend missing resource limits."


# ═══════════════════════════════════════════════════════════════════════════════
# Health Probe Tests
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.mark.kubernetes
class TestK8sProbes:
    """Tests for readiness, liveness, and startup probes."""

    def test_backend_has_readiness_probe(self, k8s_report):
        """Backend must have a readinessProbe for proper traffic routing."""
        backend = next((w for w in k8s_report.workloads if w.name == "backend"), None)
        assert backend is not None, "Backend workload not found"
        assert backend.has_readiness, (
            "Backend missing readinessProbe. Without it, traffic may be routed to "
            "pods that haven't finished starting up."
        )

    def test_backend_has_liveness_probe(self, k8s_report):
        """Backend must have a livenessProbe for automatic recovery."""
        backend = next((w for w in k8s_report.workloads if w.name == "backend"), None)
        assert backend is not None, "Backend workload not found"
        assert backend.has_liveness, (
            "Backend missing livenessProbe. Without it, kubelet cannot detect "
            "and restart unhealthy pods."
        )

    def test_frontend_has_readiness_probe(self, k8s_report):
        """Frontend must have a readinessProbe."""
        frontend = next((w for w in k8s_report.workloads if w.name == "frontend"), None)
        assert frontend is not None, "Frontend workload not found"
        assert frontend.has_readiness, "Frontend missing readinessProbe."

    def test_frontend_has_liveness_probe(self, k8s_report):
        """Frontend must have a livenessProbe."""
        frontend = next((w for w in k8s_report.workloads if w.name == "frontend"), None)
        assert frontend is not None, "Frontend workload not found"
        assert frontend.has_liveness, "Frontend missing livenessProbe."


# ═══════════════════════════════════════════════════════════════════════════════
# Image Tag Tests
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.mark.kubernetes
class TestK8sImages:
    """Tests for container image tag pinning."""

    def test_backend_image_is_pinned(self, k8s_report):
        """Backend image must be pinned to a specific version."""
        backend = next((w for w in k8s_report.workloads if w.name == "backend"), None)
        assert backend is not None, "Backend workload not found"
        for img in backend.images:
            assert ":latest" not in img, (
                f"Backend uses :latest tag: {img}. "
                f"Pin to a specific version or SHA digest."
            )

    def test_frontend_latest_tag_detected(self, k8s_report):
        """Frontend intentionally uses :latest — scanner must detect it."""
        frontend = next((w for w in k8s_report.workloads if w.name == "frontend"), None)
        assert frontend is not None, "Frontend workload not found"
        has_latest = any(":latest" in img for img in frontend.images)
        assert has_latest, (
            "Frontend should use :latest tag (intentional in examples/). "
            "If this fails, the example may have been modified."
        )


# ═══════════════════════════════════════════════════════════════════════════════
# High Availability Tests
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.mark.kubernetes
class TestK8sHA:
    """Tests for high availability configuration."""

    def test_backend_has_minimum_replicas(self, k8s_report):
        """Backend should have >= 2 replicas for HA."""
        backend = next((w for w in k8s_report.workloads if w.name == "backend"), None)
        assert backend is not None, "Backend workload not found"
        assert backend.replicas >= 2, (
            f"Backend has only {backend.replicas} replica(s). "
            f"Production workloads need >= 2 replicas for high availability."
        )

    def test_frontend_single_replica_flagged(self, k8s_report):
        """Frontend has 1 replica (intentional) — verify scanner detects it."""
        frontend = next((w for w in k8s_report.workloads if w.name == "frontend"), None)
        assert frontend is not None, "Frontend workload not found"
        assert frontend.replicas == 1, (
            f"Frontend expected 1 replica for demo but has {frontend.replicas}."
        )

    def test_network_policies_exist(self, k8s_report):
        """At least one NetworkPolicy should be defined."""
        assert len(k8s_report.network_policies) > 0, (
            "No NetworkPolicies found. Zero-trust networking requires NetworkPolicies "
            "to control pod-to-pod traffic."
        )


# ═══════════════════════════════════════════════════════════════════════════════
# Report Output Tests
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.mark.kubernetes
class TestK8sReportOutput:
    """Tests for report generation quality."""

    def test_markdown_output_has_workload_table(self, k8s_helper, k8s_report):
        """Markdown report must include the workload summary table."""
        output = k8s_helper.format_markdown(k8s_report)
        assert "### 📦 Workload Summary" in output, "Missing workload summary section"
        assert "frontend" in output, "Frontend not in report output"
        assert "backend" in output, "Backend not in report output"

    def test_json_output_is_valid(self, k8s_helper, k8s_report):
        """JSON output must be valid and parseable."""
        import json
        output = k8s_helper.format_json(k8s_report)
        data = json.loads(output)
        assert "workloads" in data, "JSON missing workloads array"
        assert "diagnostics" in data, "JSON missing diagnostics array"
        assert "verdict" in data, "JSON missing verdict"

    def test_verdict_is_needs_work(self, k8s_report):
        """With intentional issues in examples, verdict should be NEEDS WORK."""
        assert k8s_report.verdict in ("NEEDS WORK", "NOT READY"), (
            f"Expected verdict 'NEEDS WORK' or 'NOT READY' for examples/ but got '{k8s_report.verdict}'. "
            f"The frontend has intentional security issues that should trigger failures."
        )
