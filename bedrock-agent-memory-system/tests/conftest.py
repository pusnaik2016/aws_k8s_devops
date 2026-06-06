"""
conftest.py — Shared Fixtures & Rich Dashboard Generator for AgentCore Memory
"""

import os
import sys
import json
import time
import datetime
from pathlib import Path
from collections import defaultdict
from unittest.mock import MagicMock, patch

import pytest

PROJECT_ROOT = Path(__file__).resolve().parent.parent
LAMBDA_DIR = PROJECT_ROOT / "src" / "lambda" / "memory_writer"
TERRAFORM_DIR = PROJECT_ROOT / "terraform"
REPORTS_DIR = PROJECT_ROOT / "reports"

sys.path.insert(0, str(LAMBDA_DIR))


# ═══════════════════════════════════════════════════════════════════════════════
# Fixtures — Paths
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.fixture(scope="session")
def project_root():
    return PROJECT_ROOT

@pytest.fixture(scope="session")
def terraform_dir():
    return TERRAFORM_DIR

@pytest.fixture(scope="session")
def lambda_dir():
    return LAMBDA_DIR


# ═══════════════════════════════════════════════════════════════════════════════
# Fixtures — Lambda Module (with mocked AWS services)
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.fixture
def mock_env(monkeypatch):
    """Set Lambda environment variables for testing."""
    monkeypatch.setenv("MEMORY_BUCKET", "test-memory-bucket")
    monkeypatch.setenv("DYNAMODB_TABLE", "test-sessions")
    monkeypatch.setenv("KNOWLEDGE_BASE_ID", "KB_TEST_123")
    monkeypatch.setenv("DATA_SOURCE_ID", "DS_TEST_456")
    monkeypatch.setenv("CONFIDENCE_THRESHOLD", "0.7")


@pytest.fixture
def mock_aws():
    """Mock all AWS service clients used by the Lambda."""
    with patch("boto3.client") as mock_client, \
         patch("boto3.resource") as mock_resource:

        # Mock S3
        s3_mock = MagicMock()
        # Mock DynamoDB
        dynamodb_mock = MagicMock()
        table_mock = MagicMock()
        dynamodb_mock.Table.return_value = table_mock
        # Mock Bedrock Agent
        bedrock_mock = MagicMock()
        bedrock_mock.start_ingestion_job.return_value = {
            "ingestionJob": {"ingestionJobId": "ING_TEST_789"}
        }

        def client_factory(service, **kwargs):
            if service == "s3":
                return s3_mock
            elif service == "bedrock-agent":
                return bedrock_mock
            return MagicMock()

        mock_client.side_effect = client_factory
        mock_resource.return_value = dynamodb_mock

        yield {
            "s3": s3_mock,
            "dynamodb": dynamodb_mock,
            "table": table_mock,
            "bedrock": bedrock_mock,
        }


@pytest.fixture
def lambda_module(mock_env, mock_aws):
    """Import the Lambda module with mocked AWS services."""
    # Force re-import to pick up mocked env vars
    if "index" in sys.modules:
        del sys.modules["index"]

    import index
    # Inject mocked clients
    index.s3 = mock_aws["s3"]
    index.dynamodb = mock_aws["dynamodb"]
    index.bedrock_agent = mock_aws["bedrock"]
    index.MEMORY_BUCKET = "test-memory-bucket"
    index.DYNAMODB_TABLE = "test-sessions"
    index.KNOWLEDGE_BASE_ID = "KB_TEST_123"
    index.DATA_SOURCE_ID = "DS_TEST_456"
    index.CONFIDENCE_THRESHOLD = 0.7

    return index


@pytest.fixture
def make_event():
    """Factory for Bedrock action group events."""
    def _make(fact="Test fact", category="preference", confidence="0.9",
              session_id="test-session-001"):
        return {
            "function": "save_to_long_term_memory",
            "sessionId": session_id,
            "parameters": [
                {"name": "fact", "value": fact},
                {"name": "category", "value": category},
                {"name": "confidence", "value": str(confidence)},
            ]
        }
    return _make


# ═══════════════════════════════════════════════════════════════════════════════
# Dashboard Data Collector
# ═══════════════════════════════════════════════════════════════════════════════

class DashboardCollector:
    def __init__(self):
        self.results = []
        self.start_time = None
        self.end_time = None

    def add_result(self, nodeid, outcome, duration, longrepr="", markers=None):
        category = "Other"
        if markers:
            for m in markers:
                if m in ("lambda_handler", "terraform", "integration",
                         "confidence", "s3", "dynamodb"):
                    category = m.replace("_", " ").title()
                    break

        parts = nodeid.split("::")
        file_name = parts[0].replace("tests/", "") if parts else nodeid
        class_name = parts[1] if len(parts) > 1 else ""
        test_name = parts[-1] if parts else nodeid

        self.results.append({
            "nodeid": nodeid, "file": file_name, "class": class_name,
            "test": test_name, "outcome": outcome,
            "duration": round(duration * 1000, 2),
            "longrepr": str(longrepr)[:500] if longrepr else "",
            "category": category,
        })

_collector = DashboardCollector()

def pytest_sessionstart(session):
    _collector.start_time = time.time()

@pytest.hookimpl(hookwrapper=True)
def pytest_runtest_makereport(item, call):
    outcome = yield
    report = outcome.get_result()
    if report.when == "call" or (report.when == "setup" and report.failed):
        markers = [m.name for m in item.iter_markers()]
        longrepr = report.longreprtext if report.failed else ""
        outcome_str = "xfailed" if hasattr(report, "wasxfail") else report.outcome
        _collector.add_result(report.nodeid, outcome_str, report.duration,
                              longrepr, markers)

def pytest_sessionfinish(session, exitstatus):
    _collector.end_time = time.time()
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    _generate_dashboard(REPORTS_DIR / "dashboard.html", _collector)
    print(f"\n📊 Dashboard: file://{REPORTS_DIR / 'dashboard.html'}")


def _generate_dashboard(path, collector):
    """Generate a rich HTML dashboard with Chart.js."""
    results = collector.results
    total_duration = (collector.end_time - collector.start_time) if collector.end_time else 0

    counts = defaultdict(int)
    for r in results:
        counts[r["outcome"]] += 1
    total = len(results)
    passed = counts.get("passed", 0)
    failed = counts.get("failed", 0)
    xfailed = counts.get("xfailed", 0)
    pass_rate = (passed / total * 100) if total > 0 else 0

    cat_stats = defaultdict(lambda: defaultdict(int))
    for r in results:
        cat_stats[r["category"]][r["outcome"]] += 1
    categories = sorted(cat_stats.keys())
    cat_passed = [cat_stats[c].get("passed", 0) for c in categories]
    cat_failed = [cat_stats[c].get("failed", 0) for c in categories]

    file_stats = defaultdict(lambda: defaultdict(int))
    for r in results:
        file_stats[r["file"]][r["outcome"]] += 1
    files = sorted(file_stats.keys())
    file_passed = [file_stats[f].get("passed", 0) for f in files]
    file_failed = [file_stats[f].get("failed", 0) for f in files]

    sorted_dur = sorted(results, key=lambda x: -x["duration"])[:10]
    failed_tests = [r for r in results if r["outcome"] == "failed"]
    now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    max_dur = max((r["duration"] for r in results), default=1) or 1
    rows = ""
    for r in results:
        bw = min(100, r["duration"] / max_dur * 100)
        rows += f'<tr><td class="tn">{r["test"]}</td><td>{r["class"]}</td><td>{r["category"]}</td><td><span class="b {r["outcome"]}">{r["outcome"].upper()}</span></td><td><div style="display:flex;align-items:center;gap:8px"><div class="db"><div class="df" style="width:{bw}%"></div></div><span style="font-size:.8rem;color:#9898b8;min-width:50px">{r["duration"]}ms</span></div></td></tr>'

    fail_rows = ""
    for r in failed_tests:
        reason = r["longrepr"].replace("<", "&lt;").replace(">", "&gt;")
        fail_rows += f'<tr><td class="tn">{r["test"]}</td><td>{r["category"]}</td><td><span class="b failed">FAILED</span></td><td>{r["duration"]}ms</td></tr><tr><td colspan="4"><div class="fr">{reason}</div></td></tr>'

    html = f"""<!DOCTYPE html>
<html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>🧠 AgentCore Memory — Test Dashboard</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.7/dist/chart.umd.min.js"></script>
<style>
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&display=swap');
:root{{--bg:#0a0a1a;--card:#12122a;--border:#2a2a5a;--txt:#e8e8f0;--dim:#9898b8;--green:#00e676;--red:#ff5252;--yellow:#ffd740;--blue:#448aff;--purple:#b388ff;--cyan:#18ffff}}
*{{margin:0;padding:0;box-sizing:border-box}}
body{{font-family:'Inter',sans-serif;background:var(--bg);color:var(--txt);min-height:100vh}}
.c{{max-width:1400px;margin:0 auto;padding:24px}}
.hdr{{text-align:center;padding:48px 24px 36px;border-bottom:1px solid var(--border);margin-bottom:32px}}
.hdr h1{{font-size:2.4rem;font-weight:800;background:linear-gradient(135deg,#667eea,#764ba2);-webkit-background-clip:text;-webkit-text-fill-color:transparent}}
.hdr .sub{{color:var(--dim);font-size:1rem;margin-top:8px}}
.kpi{{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:20px;margin-bottom:32px}}
.k{{background:var(--card);border:1px solid var(--border);border-radius:16px;padding:24px;text-align:center;position:relative;overflow:hidden}}
.k::before{{content:'';position:absolute;top:0;left:0;right:0;height:3px;border-radius:16px 16px 0 0}}
.k.t::before{{background:linear-gradient(135deg,#667eea,#764ba2)}}.k.p::before{{background:linear-gradient(135deg,#43e97b,#38f9d7)}}.k.f::before{{background:linear-gradient(135deg,#f093fb,#f5576c)}}.k.r::before{{background:linear-gradient(135deg,#ffd740,#ff9100)}}.k.tm::before{{background:linear-gradient(135deg,#4facfe,#00f2fe)}}
.kv{{font-size:2.8rem;font-weight:800;line-height:1;margin-bottom:8px}}
.k.t .kv{{color:var(--blue)}}.k.p .kv{{color:var(--green)}}.k.f .kv{{color:var(--red)}}.k.r .kv{{color:var(--cyan)}}.k.tm .kv{{color:var(--purple)}}
.kl{{color:var(--dim);font-size:.85rem;font-weight:500;text-transform:uppercase;letter-spacing:1px}}
.cg{{display:grid;grid-template-columns:1fr 1fr;gap:24px;margin-bottom:32px}}
@media(max-width:900px){{.cg{{grid-template-columns:1fr}}}}
.cc{{background:var(--card);border:1px solid var(--border);border-radius:16px;padding:28px}}
.cc h3{{font-size:1.1rem;font-weight:600;margin-bottom:20px}}
.tc{{background:var(--card);border:1px solid var(--border);border-radius:16px;padding:28px;margin-bottom:24px;overflow-x:auto}}
.tc h3{{font-size:1.1rem;font-weight:600;margin-bottom:16px}}
table{{width:100%;border-collapse:collapse;font-size:.9rem}}
thead th{{text-align:left;padding:12px 16px;border-bottom:2px solid var(--border);color:var(--dim);font-weight:600;text-transform:uppercase;font-size:.75rem;letter-spacing:1px}}
tbody td{{padding:10px 16px;border-bottom:1px solid rgba(42,42,90,.5)}}
tbody tr:hover{{background:#1a1a3e}}
.b{{display:inline-block;padding:3px 10px;border-radius:20px;font-size:.75rem;font-weight:600;text-transform:uppercase}}
.b.passed{{background:rgba(0,230,118,.15);color:var(--green)}}.b.failed{{background:rgba(255,82,82,.15);color:var(--red)}}.b.xfailed{{background:rgba(255,215,64,.15);color:var(--yellow)}}
.tn{{font-family:'SF Mono',monospace;font-size:.85rem}}
.db{{height:6px;border-radius:3px;background:rgba(102,126,234,.2);overflow:hidden;min-width:60px}}
.df{{height:100%;border-radius:3px;background:linear-gradient(135deg,#667eea,#764ba2)}}
.fr{{font-family:monospace;font-size:.8rem;background:rgba(255,82,82,.08);border:1px solid rgba(255,82,82,.2);border-radius:8px;padding:12px;margin-top:8px;color:#ff8a80;white-space:pre-wrap;max-height:200px;overflow-y:auto}}
.ft{{text-align:center;padding:32px;color:var(--dim);font-size:.85rem;border-top:1px solid var(--border);margin-top:32px}}
</style></head><body>
<div class="c">
<div class="hdr"><h1>🧠 AgentCore Memory — Test Dashboard</h1><div class="sub">3-Layer Memory System Verification Suite &nbsp;|&nbsp; {now} &nbsp;|&nbsp; {total_duration:.2f}s</div></div>
<div class="kpi">
<div class="k t"><div class="kv">{total}</div><div class="kl">Total Tests</div></div>
<div class="k p"><div class="kv">{passed}</div><div class="kl">Passed ✅</div></div>
<div class="k f"><div class="kv">{failed}</div><div class="kl">Failed ❌</div></div>
<div class="k r"><div class="kv">{pass_rate:.0f}%</div><div class="kl">Pass Rate</div></div>
<div class="k tm"><div class="kv">{total_duration:.1f}s</div><div class="kl">Duration</div></div>
</div>
<div class="cg">
<div class="cc"><h3>🍩 Result Distribution</h3><canvas id="pie" height="280"></canvas></div>
<div class="cc"><h3>📊 Results by Category</h3><canvas id="catBar" height="280"></canvas></div>
</div>
{"" if not fail_rows else f'<div class="tc"><h3>❌ Failed Tests</h3><table><thead><tr><th>Test</th><th>Category</th><th>Status</th><th>Duration</th></tr></thead><tbody>{fail_rows}</tbody></table></div>'}
<div class="tc"><h3>📋 All Tests</h3><table><thead><tr><th>Test</th><th>Class</th><th>Category</th><th>Status</th><th>Duration</th></tr></thead><tbody>{rows}</tbody></table></div>
<div class="ft">AgentCore Memory Test Dashboard &nbsp;|&nbsp; Built by Pushparaj Naik</div>
</div>
<script>
Chart.defaults.color='#9898b8';Chart.defaults.font.family="'Inter',sans-serif";
new Chart(document.getElementById('pie'),{{type:'doughnut',data:{{labels:['Passed','Failed','XFailed'],datasets:[{{data:[{passed},{failed},{xfailed}],backgroundColor:['rgba(0,230,118,.8)','rgba(255,82,82,.8)','rgba(255,215,64,.8)'],borderColor:'#12122a',borderWidth:3}}]}},options:{{responsive:true,cutout:'60%',plugins:{{legend:{{position:'bottom',labels:{{usePointStyle:true}}}}}}}}}});
new Chart(document.getElementById('catBar'),{{type:'bar',data:{{labels:{json.dumps(categories)},datasets:[{{label:'Passed',data:{json.dumps(cat_passed)},backgroundColor:'rgba(0,230,118,.7)',borderRadius:4}},{{label:'Failed',data:{json.dumps(cat_failed)},backgroundColor:'rgba(255,82,82,.7)',borderRadius:4}}]}},options:{{responsive:true,scales:{{x:{{stacked:true}},y:{{stacked:true,beginAtZero:true,ticks:{{stepSize:1}}}}}},plugins:{{legend:{{position:'bottom',labels:{{usePointStyle:true}}}}}}}}}});
</script></body></html>"""
    path.write_text(html, encoding="utf-8")
