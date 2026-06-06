"""Shared pytest fixtures and HTML dashboard generation."""

import sys
import json
from pathlib import Path

import pytest

# Add project root to path
PROJECT_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

SAMPLES_DIR = PROJECT_ROOT / "samples"
REPORTS_DIR = PROJECT_ROOT / "reports"


@pytest.fixture
def samples_dir():
    return SAMPLES_DIR


@pytest.fixture
def terraform_samples():
    return SAMPLES_DIR / "terraform"


@pytest.fixture
def k8s_samples():
    return SAMPLES_DIR / "kubernetes"


@pytest.fixture
def pipeline_samples():
    return SAMPLES_DIR / "pipelines"


@pytest.fixture
def server_config_samples():
    return SAMPLES_DIR / "server_configs"


@pytest.fixture
def legacy_code_samples():
    return SAMPLES_DIR / "legacy_code"


@pytest.fixture
def service_desc_samples():
    return SAMPLES_DIR / "service_descriptions"


@pytest.fixture
def reports_dir():
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    return REPORTS_DIR


@pytest.fixture
def output_dir(tmp_path):
    """Temporary output directory for generated files."""
    d = tmp_path / "output"
    d.mkdir()
    return d
