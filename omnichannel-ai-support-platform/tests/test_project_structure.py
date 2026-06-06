"""
Project Structure Tests — OmniPresenseAI
─────────────────────────────────────────
Validates that all required files exist, scripts are executable,
and documentation is complete.

Run: pytest tests/test_project_structure.py -v
"""
import os
import stat
import pytest

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


class TestRootFiles:
    """Test that essential root files exist."""

    @pytest.mark.parametrize("filename", [
        "README.md", "LICENSE", ".gitignore",
        "sonar-project.properties",
    ])
    def test_root_file_exists(self, filename):
        assert os.path.isfile(os.path.join(PROJECT_ROOT, filename))

    def test_readme_not_empty(self):
        path = os.path.join(PROJECT_ROOT, "README.md")
        assert os.path.getsize(path) > 1000, "README seems too small"


class TestDocumentation:
    """Test that all documentation files exist."""

    @pytest.mark.parametrize("doc", [
        "docs/architecture.md",
        "docs/runbook.md",
        "docs/data-flow.md",
        "docs/security.md",
        "docs/cost-estimation.md",
        "docs/compliance.md",
        "docs/well-architected-review.md",
        "docs/adr/001-pgvector-over-opensearch.md",
        "docs/adr/002-keda-over-hpa.md",
        "docs/adr/003-bedrock-over-openai.md",
        "docs/adr/004-compliance-framework.md",
    ])
    def test_doc_exists(self, doc):
        assert os.path.isfile(os.path.join(PROJECT_ROOT, doc))


class TestScripts:
    """Test that scripts exist and are executable."""

    @pytest.mark.parametrize("script", [
        "scripts/bootstrap.sh",
        "scripts/setup-kubeconfig.sh",
        "scripts/seed-knowledge-base.py",
    ])
    def test_script_exists(self, script):
        assert os.path.isfile(os.path.join(PROJECT_ROOT, script))

    @pytest.mark.parametrize("script", [
        "scripts/bootstrap.sh",
        "scripts/setup-kubeconfig.sh",
        "scripts/seed-knowledge-base.py",
    ])
    def test_script_executable(self, script):
        path = os.path.join(PROJECT_ROOT, script)
        assert os.access(path, os.X_OK), f"{script} is not executable"


class TestCICDPipelines:
    """Test GitHub Actions workflow files."""

    @pytest.mark.parametrize("workflow", [
        ".github/workflows/ci.yml",
        ".github/workflows/cd-app.yml",
        ".github/workflows/cd-infra.yml",
    ])
    def test_workflow_exists(self, workflow):
        assert os.path.isfile(os.path.join(PROJECT_ROOT, workflow))


class TestMicroservices:
    """Test that microservice structure is complete."""

    @pytest.mark.parametrize("service", ["chat-service", "analytics-service"])
    def test_service_has_dockerfile(self, service):
        assert os.path.isfile(os.path.join(PROJECT_ROOT, f"src/{service}/Dockerfile"))

    @pytest.mark.parametrize("service", ["chat-service", "analytics-service"])
    def test_service_has_requirements(self, service):
        assert os.path.isfile(os.path.join(PROJECT_ROOT, f"src/{service}/requirements.txt"))

    @pytest.mark.parametrize("service", ["chat-service", "analytics-service"])
    def test_service_has_main(self, service):
        assert os.path.isfile(os.path.join(PROJECT_ROOT, f"src/{service}/app/main.py"))

    @pytest.mark.parametrize("service", ["chat-service", "analytics-service"])
    def test_service_has_tests(self, service):
        test_dir = os.path.join(PROJECT_ROOT, f"src/{service}/tests")
        assert os.path.isdir(test_dir)
        test_files = [f for f in os.listdir(test_dir) if f.startswith("test_")]
        assert len(test_files) > 0, f"{service} has no test files"


class TestTerraformStructure:
    """Test Terraform module structure."""

    @pytest.mark.parametrize("module", [
        "networking", "security", "compute", "database", "ai_cdn",
        "compliance", "ai_governance",
    ])
    def test_module_exists(self, module):
        assert os.path.isdir(os.path.join(PROJECT_ROOT, f"terraform/modules/{module}"))

    @pytest.mark.parametrize("env", ["prod", "staging"])
    def test_env_has_main(self, env):
        assert os.path.isfile(os.path.join(PROJECT_ROOT, f"terraform/envs/{env}/main.tf"))

    @pytest.mark.parametrize("env", ["prod", "staging"])
    def test_env_has_backend(self, env):
        assert os.path.isfile(os.path.join(PROJECT_ROOT, f"terraform/envs/{env}/backend.tf"))

    @pytest.mark.parametrize("env", ["prod", "staging"])
    def test_env_has_tfvars_example(self, env):
        assert os.path.isfile(os.path.join(PROJECT_ROOT, f"terraform/envs/{env}/terraform.tfvars.example"))


class TestKubernetesStructure:
    """Test K8s manifest structure."""

    def test_base_kustomization_exists(self):
        assert os.path.isfile(os.path.join(PROJECT_ROOT, "k8s/base/kustomization.yaml"))

    @pytest.mark.parametrize("overlay", ["prod", "staging"])
    def test_overlay_exists(self, overlay):
        assert os.path.isfile(os.path.join(PROJECT_ROOT, f"k8s/overlays/{overlay}/kustomization.yaml"))

    @pytest.mark.parametrize("resource", [
        "k8s/base/namespace.yaml",
        "k8s/base/chat-service/deployment.yaml",
        "k8s/base/chat-service/service.yaml",
        "k8s/base/analytics-service/deployment.yaml",
        "k8s/base/analytics-service/service.yaml",
        "k8s/base/ingress.yaml",
        "k8s/base/network-policies.yaml",
        "k8s/base/pdb.yaml",
    ])
    def test_k8s_resource_exists(self, resource):
        assert os.path.isfile(os.path.join(PROJECT_ROOT, resource))
