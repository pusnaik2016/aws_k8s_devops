"""
conftest.py — Shared Fixtures & Rich Dashboard Generator
============================================================
Provides:
  - Reusable pytest fixtures for all scanner test suites
  - Custom pytest hooks that generate a premium interactive HTML dashboard
    with pie charts, bar graphs, category breakdowns, and timing analysis
    using Chart.js (embedded, zero external deps at runtime)
"""

import os
import sys
import json
import time
import datetime
from pathlib import Path
from collections import defaultdict

import pytest

# ── Make project scripts importable ──
PROJECT_ROOT = Path(__file__).resolve().parent.parent
SCRIPTS_DIR = PROJECT_ROOT / "scripts"
EXAMPLES_DIR = PROJECT_ROOT / "examples"
REPORTS_DIR = PROJECT_ROOT / "reports"

sys.path.insert(0, str(SCRIPTS_DIR))


# ═══════════════════════════════════════════════════════════════════════════════
# Fixtures — Path Providers
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.fixture(scope="session")
def project_root() -> Path:
    return PROJECT_ROOT

@pytest.fixture(scope="session")
def examples_dir() -> Path:
    return EXAMPLES_DIR

@pytest.fixture(scope="session")
def terraform_dir() -> Path:
    return EXAMPLES_DIR / "terraform"

@pytest.fixture(scope="session")
def k8s_dir() -> Path:
    return EXAMPLES_DIR / "k8s"

@pytest.fixture(scope="session")
def docker_dir() -> Path:
    return EXAMPLES_DIR / "docker"

@pytest.fixture(scope="session")
def cicd_dir() -> Path:
    return EXAMPLES_DIR / ".github" / "workflows"


# ═══════════════════════════════════════════════════════════════════════════════
# Fixtures — Scanner Module Imports
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.fixture(scope="session")
def sec_scanner():
    import sec_scanner
    return sec_scanner

@pytest.fixture(scope="session")
def k8s_helper():
    import k8s_helper
    return k8s_helper

@pytest.fixture(scope="session")
def tf_helper():
    import tf_helper
    return tf_helper

@pytest.fixture(scope="session")
def pr_analyser():
    import pr_analyser
    return pr_analyser


# ═══════════════════════════════════════════════════════════════════════════════
# Fixtures — Pre-built Reports (cached per session)
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.fixture(scope="session")
def security_report(sec_scanner, examples_dir):
    report = sec_scanner.ScanReport(scan_path=str(examples_dir))
    report.files_scanned = len(sec_scanner._iter_files(examples_dir))
    report.findings.extend(sec_scanner.scan_secrets(examples_dir))
    report.findings.extend(sec_scanner.scan_terraform(examples_dir))
    report.findings.extend(sec_scanner.scan_kubernetes(examples_dir))
    report.findings.extend(sec_scanner.scan_dockerfiles(examples_dir))
    report.findings.extend(sec_scanner.scan_cicd(examples_dir))
    return report

@pytest.fixture(scope="session")
def k8s_report(k8s_helper, k8s_dir):
    return k8s_helper.analyse_manifests(k8s_dir)

@pytest.fixture(scope="session")
def tf_report(tf_helper, terraform_dir):
    return tf_helper.analyse_terraform(terraform_dir)


# ═══════════════════════════════════════════════════════════════════════════════
# Dashboard Data Collector (pytest plugin)
# ═══════════════════════════════════════════════════════════════════════════════

class DashboardCollector:
    """Collects test results during the session for dashboard generation."""

    def __init__(self):
        self.results = []
        self.start_time = None
        self.end_time = None

    def add_result(self, nodeid: str, outcome: str, duration: float,
                   longrepr: str = "", markers: list = None):
        # Parse category from markers or file name
        category = "Other"
        if markers:
            for m in markers:
                if m in ("security", "docker", "terraform", "kubernetes", "cicd",
                         "integration", "pr"):
                    category = m.capitalize()
                    break

        # Determine file & class & test name
        parts = nodeid.split("::")
        file_name = parts[0].replace("tests/", "") if parts else nodeid
        class_name = parts[1] if len(parts) > 1 else ""
        test_name = parts[-1] if parts else nodeid

        self.results.append({
            "nodeid": nodeid,
            "file": file_name,
            "class": class_name,
            "test": test_name,
            "outcome": outcome,
            "duration": round(duration * 1000, 2),  # ms
            "longrepr": str(longrepr)[:500] if longrepr else "",
            "category": category,
        })


# Global collector instance
_collector = DashboardCollector()


def pytest_sessionstart(session):
    _collector.start_time = time.time()


@pytest.hookimpl(hookwrapper=True)
def pytest_runtest_makereport(item, call):
    outcome = yield
    report = outcome.get_result()

    if report.when == "call" or (report.when == "setup" and report.failed):
        markers = [m.name for m in item.iter_markers()]
        longrepr = ""
        if report.failed and report.longreprtext:
            longrepr = report.longreprtext

        # Map xfail properly
        outcome_str = report.outcome
        if hasattr(report, "wasxfail"):
            outcome_str = "xfailed"

        _collector.add_result(
            nodeid=report.nodeid,
            outcome=outcome_str,
            duration=report.duration,
            longrepr=longrepr,
            markers=markers,
        )


def pytest_sessionfinish(session, exitstatus):
    _collector.end_time = time.time()
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    dashboard_path = REPORTS_DIR / "dashboard.html"
    _generate_dashboard(dashboard_path, _collector)
    print(f"\n📊 Rich Dashboard: file://{dashboard_path}")


# ═══════════════════════════════════════════════════════════════════════════════
# Dashboard HTML Generator
# ═══════════════════════════════════════════════════════════════════════════════

def _generate_dashboard(path: Path, collector: DashboardCollector):
    """Generate a premium interactive HTML dashboard with charts."""

    results = collector.results
    total_duration = (collector.end_time - collector.start_time) if collector.end_time else 0

    # ── Aggregate stats ──
    counts = defaultdict(int)
    for r in results:
        counts[r["outcome"]] += 1
    total = len(results)
    passed = counts.get("passed", 0)
    failed = counts.get("failed", 0)
    xfailed = counts.get("xfailed", 0)
    skipped = counts.get("skipped", 0)
    errors = counts.get("error", 0)

    # ── Per-category breakdown ──
    cat_stats = defaultdict(lambda: defaultdict(int))
    for r in results:
        cat_stats[r["category"]][r["outcome"]] += 1

    categories = sorted(cat_stats.keys())
    cat_passed = [cat_stats[c].get("passed", 0) for c in categories]
    cat_failed = [cat_stats[c].get("failed", 0) for c in categories]
    cat_xfailed = [cat_stats[c].get("xfailed", 0) for c in categories]

    # ── Per-file breakdown ──
    file_stats = defaultdict(lambda: defaultdict(int))
    for r in results:
        file_stats[r["file"]][r["outcome"]] += 1

    files = sorted(file_stats.keys())
    file_passed = [file_stats[f].get("passed", 0) for f in files]
    file_failed = [file_stats[f].get("failed", 0) for f in files]
    file_xfailed = [file_stats[f].get("xfailed", 0) for f in files]

    # ── Top 10 slowest tests ──
    sorted_by_duration = sorted(results, key=lambda x: -x["duration"])[:10]

    # ── Failed tests detail ──
    failed_tests = [r for r in results if r["outcome"] == "failed"]

    # ── XFailed tests detail ──
    xfailed_tests = [r for r in results if r["outcome"] == "xfailed"]

    now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    pass_rate = (passed / total * 100) if total > 0 else 0

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>🤖 Claude DevOps — Test Dashboard</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.7/dist/chart.umd.min.js"></script>
<style>
  @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&display=swap');

  :root {{
    --bg-primary: #0a0a1a;
    --bg-card: #12122a;
    --bg-card-hover: #1a1a3e;
    --border: #2a2a5a;
    --text-primary: #e8e8f0;
    --text-secondary: #9898b8;
    --accent-green: #00e676;
    --accent-red: #ff5252;
    --accent-yellow: #ffd740;
    --accent-blue: #448aff;
    --accent-purple: #b388ff;
    --accent-cyan: #18ffff;
    --gradient-1: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    --gradient-2: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
    --gradient-3: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
    --gradient-4: linear-gradient(135deg, #43e97b 0%, #38f9d7 100%);
    --shadow: 0 8px 32px rgba(0, 0, 0, 0.4);
    --shadow-glow: 0 0 40px rgba(102, 126, 234, 0.15);
  }}

  * {{ margin: 0; padding: 0; box-sizing: border-box; }}

  body {{
    font-family: 'Inter', -apple-system, sans-serif;
    background: var(--bg-primary);
    color: var(--text-primary);
    min-height: 100vh;
    overflow-x: hidden;
  }}

  .bg-grid {{
    position: fixed; top: 0; left: 0; width: 100%; height: 100%;
    background-image:
      linear-gradient(rgba(102,126,234,0.03) 1px, transparent 1px),
      linear-gradient(90deg, rgba(102,126,234,0.03) 1px, transparent 1px);
    background-size: 60px 60px;
    pointer-events: none; z-index: 0;
  }}

  .container {{
    position: relative; z-index: 1;
    max-width: 1400px; margin: 0 auto; padding: 24px;
  }}

  /* ── Header ── */
  .header {{
    text-align: center; padding: 48px 24px 36px;
    background: linear-gradient(180deg, rgba(102,126,234,0.08) 0%, transparent 100%);
    border-bottom: 1px solid var(--border);
    margin-bottom: 32px;
  }}
  .header h1 {{
    font-size: 2.4rem; font-weight: 800;
    background: var(--gradient-1); -webkit-background-clip: text;
    -webkit-text-fill-color: transparent; margin-bottom: 8px;
  }}
  .header .subtitle {{
    color: var(--text-secondary); font-size: 1rem; font-weight: 400;
  }}
  .header .timestamp {{
    color: var(--text-secondary); font-size: 0.85rem; margin-top: 12px;
    opacity: 0.7;
  }}

  /* ── KPI Cards ── */
  .kpi-grid {{
    display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 20px; margin-bottom: 32px;
  }}
  .kpi-card {{
    background: var(--bg-card); border: 1px solid var(--border);
    border-radius: 16px; padding: 24px; text-align: center;
    box-shadow: var(--shadow); transition: all 0.3s ease;
    position: relative; overflow: hidden;
  }}
  .kpi-card:hover {{
    transform: translateY(-4px); box-shadow: var(--shadow-glow);
    border-color: rgba(102,126,234,0.4);
  }}
  .kpi-card::before {{
    content: ''; position: absolute; top: 0; left: 0; right: 0;
    height: 3px; border-radius: 16px 16px 0 0;
  }}
  .kpi-card.total::before {{ background: var(--gradient-1); }}
  .kpi-card.passed::before {{ background: var(--gradient-4); }}
  .kpi-card.failed::before {{ background: var(--gradient-2); }}
  .kpi-card.xfailed::before {{ background: var(--gradient-3); }}
  .kpi-card.rate::before {{ background: linear-gradient(135deg, #ffd740, #ff9100); }}
  .kpi-card.time::before {{ background: var(--gradient-1); }}

  .kpi-value {{
    font-size: 2.8rem; font-weight: 800; line-height: 1;
    margin-bottom: 8px;
  }}
  .kpi-card.total .kpi-value {{ color: var(--accent-blue); }}
  .kpi-card.passed .kpi-value {{ color: var(--accent-green); }}
  .kpi-card.failed .kpi-value {{ color: var(--accent-red); }}
  .kpi-card.xfailed .kpi-value {{ color: var(--accent-yellow); }}
  .kpi-card.rate .kpi-value {{ color: var(--accent-cyan); }}
  .kpi-card.time .kpi-value {{ color: var(--accent-purple); }}

  .kpi-label {{ color: var(--text-secondary); font-size: 0.85rem; font-weight: 500; text-transform: uppercase; letter-spacing: 1px; }}

  /* ── Charts Grid ── */
  .charts-grid {{
    display: grid; grid-template-columns: 1fr 1fr; gap: 24px; margin-bottom: 32px;
  }}
  @media (max-width: 900px) {{ .charts-grid {{ grid-template-columns: 1fr; }} }}

  .chart-card {{
    background: var(--bg-card); border: 1px solid var(--border);
    border-radius: 16px; padding: 28px; box-shadow: var(--shadow);
  }}
  .chart-card h3 {{
    font-size: 1.1rem; font-weight: 600; margin-bottom: 20px;
    color: var(--text-primary); display: flex; align-items: center; gap: 8px;
  }}
  .chart-card h3 .icon {{ font-size: 1.3rem; }}

  /* ── Tables ── */
  .table-card {{
    background: var(--bg-card); border: 1px solid var(--border);
    border-radius: 16px; padding: 28px; box-shadow: var(--shadow);
    margin-bottom: 24px; overflow-x: auto;
  }}
  .table-card h3 {{
    font-size: 1.1rem; font-weight: 600; margin-bottom: 16px;
    display: flex; align-items: center; gap: 8px;
  }}

  table {{
    width: 100%; border-collapse: collapse; font-size: 0.9rem;
  }}
  thead th {{
    text-align: left; padding: 12px 16px; border-bottom: 2px solid var(--border);
    color: var(--text-secondary); font-weight: 600; text-transform: uppercase;
    font-size: 0.75rem; letter-spacing: 1px;
  }}
  tbody td {{
    padding: 10px 16px; border-bottom: 1px solid rgba(42,42,90,0.5);
    vertical-align: top;
  }}
  tbody tr:hover {{ background: var(--bg-card-hover); }}
  tbody tr:last-child td {{ border-bottom: none; }}

  .badge {{
    display: inline-block; padding: 3px 10px; border-radius: 20px;
    font-size: 0.75rem; font-weight: 600; text-transform: uppercase;
    letter-spacing: 0.5px;
  }}
  .badge.passed {{ background: rgba(0,230,118,0.15); color: var(--accent-green); }}
  .badge.failed {{ background: rgba(255,82,82,0.15); color: var(--accent-red); }}
  .badge.xfailed {{ background: rgba(255,215,64,0.15); color: var(--accent-yellow); }}
  .badge.skipped {{ background: rgba(68,138,255,0.15); color: var(--accent-blue); }}
  .badge.error {{ background: rgba(255,82,82,0.15); color: var(--accent-red); }}

  .duration-bar {{
    height: 6px; border-radius: 3px; background: rgba(102,126,234,0.2);
    overflow: hidden; min-width: 60px;
  }}
  .duration-fill {{
    height: 100%; border-radius: 3px;
    background: var(--gradient-1); transition: width 0.5s ease;
  }}

  .failure-reason {{
    font-family: 'SF Mono', 'Fira Code', monospace; font-size: 0.8rem;
    background: rgba(255,82,82,0.08); border: 1px solid rgba(255,82,82,0.2);
    border-radius: 8px; padding: 12px; margin-top: 8px;
    color: #ff8a80; white-space: pre-wrap; word-break: break-word;
    max-height: 200px; overflow-y: auto; line-height: 1.5;
  }}

  .xfail-reason {{
    font-family: 'SF Mono', 'Fira Code', monospace; font-size: 0.8rem;
    background: rgba(255,215,64,0.08); border: 1px solid rgba(255,215,64,0.2);
    border-radius: 8px; padding: 12px; margin-top: 8px;
    color: #ffe082; white-space: pre-wrap; word-break: break-word;
    max-height: 150px; overflow-y: auto; line-height: 1.5;
  }}

  .test-name {{ font-family: 'SF Mono', monospace; font-size: 0.85rem; }}

  /* ── Footer ── */
  .footer {{
    text-align: center; padding: 32px; color: var(--text-secondary);
    font-size: 0.85rem; border-top: 1px solid var(--border); margin-top: 32px;
  }}
  .footer a {{ color: var(--accent-blue); text-decoration: none; }}

  /* ── Filter Buttons ── */
  .filter-bar {{
    display: flex; gap: 8px; margin-bottom: 16px; flex-wrap: wrap;
  }}
  .filter-btn {{
    background: var(--bg-card); border: 1px solid var(--border);
    color: var(--text-secondary); padding: 6px 16px; border-radius: 20px;
    cursor: pointer; font-size: 0.85rem; font-weight: 500;
    transition: all 0.2s; font-family: inherit;
  }}
  .filter-btn:hover, .filter-btn.active {{
    background: rgba(102,126,234,0.2); border-color: rgba(102,126,234,0.5);
    color: var(--text-primary);
  }}

  /* ── Progress Ring ── */
  .progress-ring-container {{
    display: flex; flex-direction: column; align-items: center; gap: 12px;
  }}
</style>
</head>
<body>
<div class="bg-grid"></div>
<div class="container">

  <!-- Header -->
  <div class="header">
    <h1>🤖 Claude DevOps — Test Dashboard</h1>
    <div class="subtitle">Autonomous Infrastructure Scanner Verification Suite</div>
    <div class="timestamp">Generated: {now} &nbsp;|&nbsp; Duration: {total_duration:.2f}s &nbsp;|&nbsp; Python {sys.version.split()[0]}</div>
  </div>

  <!-- KPI Cards -->
  <div class="kpi-grid">
    <div class="kpi-card total">
      <div class="kpi-value">{total}</div>
      <div class="kpi-label">Total Tests</div>
    </div>
    <div class="kpi-card passed">
      <div class="kpi-value">{passed}</div>
      <div class="kpi-label">Passed ✅</div>
    </div>
    <div class="kpi-card failed">
      <div class="kpi-value">{failed}</div>
      <div class="kpi-label">Failed ❌</div>
    </div>
    <div class="kpi-card xfailed">
      <div class="kpi-value">{xfailed}</div>
      <div class="kpi-label">Expected Fail ⚠️</div>
    </div>
    <div class="kpi-card rate">
      <div class="kpi-value">{pass_rate:.0f}%</div>
      <div class="kpi-label">Pass Rate</div>
    </div>
    <div class="kpi-card time">
      <div class="kpi-value">{total_duration:.1f}s</div>
      <div class="kpi-label">Total Time</div>
    </div>
  </div>

  <!-- Charts -->
  <div class="charts-grid">
    <div class="chart-card">
      <h3><span class="icon">🍩</span> Result Distribution</h3>
      <canvas id="pieChart" height="280"></canvas>
    </div>
    <div class="chart-card">
      <h3><span class="icon">📊</span> Results by Category</h3>
      <canvas id="categoryBar" height="280"></canvas>
    </div>
    <div class="chart-card">
      <h3><span class="icon">📁</span> Results by Test File</h3>
      <canvas id="fileBar" height="280"></canvas>
    </div>
    <div class="chart-card">
      <h3><span class="icon">⏱️</span> Top 10 Slowest Tests</h3>
      <canvas id="slowestBar" height="280"></canvas>
    </div>
  </div>

  <!-- Failed Tests Detail -->
  {"" if not failed_tests else _render_failed_table(failed_tests)}

  <!-- XFailed Tests Detail -->
  {"" if not xfailed_tests else _render_xfailed_table(xfailed_tests)}

  <!-- All Tests Table -->
  {_render_all_tests_table(results)}

  <!-- Footer -->
  <div class="footer">
    <p>Claude DevOps Test Dashboard &nbsp;|&nbsp; Built by <a href="https://github.com/pushparajnaik">Pushparaj Naik</a></p>
    <p style="margin-top:4px;opacity:0.6;">Powered by pytest + Chart.js &nbsp;|&nbsp; {total} tests across {len(files)} files</p>
  </div>
</div>

<script>
// ── Chart.js Configuration ──
Chart.defaults.color = '#9898b8';
Chart.defaults.font.family = "'Inter', sans-serif";
Chart.defaults.plugins.legend.labels.padding = 16;

// 1. Pie / Doughnut Chart
new Chart(document.getElementById('pieChart'), {{
  type: 'doughnut',
  data: {{
    labels: ['Passed', 'Failed', 'XFailed', 'Skipped'],
    datasets: [{{
      data: [{passed}, {failed}, {xfailed}, {skipped}],
      backgroundColor: [
        'rgba(0, 230, 118, 0.8)',
        'rgba(255, 82, 82, 0.8)',
        'rgba(255, 215, 64, 0.8)',
        'rgba(68, 138, 255, 0.8)',
      ],
      borderColor: '#12122a',
      borderWidth: 3,
      hoverOffset: 8,
    }}]
  }},
  options: {{
    responsive: true,
    cutout: '60%',
    plugins: {{
      legend: {{ position: 'bottom', labels: {{ padding: 20, usePointStyle: true, pointStyle: 'circle' }} }},
      tooltip: {{
        callbacks: {{
          label: ctx => `${{ctx.label}}: ${{ctx.raw}} (${{(ctx.raw/{total}*100).toFixed(1)}}%)`
        }}
      }}
    }}
  }}
}});

// 2. Category Stacked Bar
new Chart(document.getElementById('categoryBar'), {{
  type: 'bar',
  data: {{
    labels: {json.dumps(categories)},
    datasets: [
      {{ label: 'Passed', data: {json.dumps(cat_passed)}, backgroundColor: 'rgba(0,230,118,0.7)', borderRadius: 4 }},
      {{ label: 'Failed', data: {json.dumps(cat_failed)}, backgroundColor: 'rgba(255,82,82,0.7)', borderRadius: 4 }},
      {{ label: 'XFailed', data: {json.dumps(cat_xfailed)}, backgroundColor: 'rgba(255,215,64,0.7)', borderRadius: 4 }},
    ]
  }},
  options: {{
    responsive: true,
    scales: {{
      x: {{ stacked: true, grid: {{ color: 'rgba(42,42,90,0.3)' }} }},
      y: {{ stacked: true, grid: {{ color: 'rgba(42,42,90,0.3)' }}, beginAtZero: true,
             ticks: {{ stepSize: 1 }} }}
    }},
    plugins: {{ legend: {{ position: 'bottom', labels: {{ usePointStyle: true, pointStyle: 'circle' }} }} }}
  }}
}});

// 3. File Stacked Bar
new Chart(document.getElementById('fileBar'), {{
  type: 'bar',
  data: {{
    labels: {json.dumps([f.replace("test_", "").replace(".py", "") for f in files])},
    datasets: [
      {{ label: 'Passed', data: {json.dumps(file_passed)}, backgroundColor: 'rgba(0,230,118,0.7)', borderRadius: 4 }},
      {{ label: 'Failed', data: {json.dumps(file_failed)}, backgroundColor: 'rgba(255,82,82,0.7)', borderRadius: 4 }},
      {{ label: 'XFailed', data: {json.dumps(file_xfailed)}, backgroundColor: 'rgba(255,215,64,0.7)', borderRadius: 4 }},
    ]
  }},
  options: {{
    responsive: true, indexAxis: 'y',
    scales: {{
      x: {{ stacked: true, grid: {{ color: 'rgba(42,42,90,0.3)' }}, beginAtZero: true, ticks: {{ stepSize: 5 }} }},
      y: {{ stacked: true, grid: {{ display: false }} }}
    }},
    plugins: {{ legend: {{ position: 'bottom', labels: {{ usePointStyle: true, pointStyle: 'circle' }} }} }}
  }}
}});

// 4. Slowest Tests Horizontal Bar
new Chart(document.getElementById('slowestBar'), {{
  type: 'bar',
  data: {{
    labels: {json.dumps([r["test"][:40] for r in sorted_by_duration])},
    datasets: [{{
      label: 'Duration (ms)',
      data: {json.dumps([r["duration"] for r in sorted_by_duration])},
      backgroundColor: {json.dumps([
          'rgba(179,136,255,0.7)' if r['outcome'] == 'passed' else
          'rgba(255,82,82,0.7)' if r['outcome'] == 'failed' else
          'rgba(255,215,64,0.7)'
          for r in sorted_by_duration
      ])},
      borderRadius: 4,
    }}]
  }},
  options: {{
    responsive: true, indexAxis: 'y',
    scales: {{
      x: {{ grid: {{ color: 'rgba(42,42,90,0.3)' }}, beginAtZero: true,
             title: {{ display: true, text: 'Milliseconds' }} }},
      y: {{ grid: {{ display: false }} }}
    }},
    plugins: {{ legend: {{ display: false }} }}
  }}
}});

// ── Filter Logic ──
document.querySelectorAll('.filter-btn').forEach(btn => {{
  btn.addEventListener('click', () => {{
    const filter = btn.dataset.filter;
    const table = btn.closest('.table-card').querySelector('tbody');
    const rows = table.querySelectorAll('tr');

    document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));

    if (filter === 'all') {{
      rows.forEach(r => r.style.display = '');
    }} else {{
      btn.classList.add('active');
      rows.forEach(r => {{
        const badge = r.querySelector('.badge');
        r.style.display = badge && badge.classList.contains(filter) ? '' : 'none';
      }});
    }}
  }});
}});
</script>
</body>
</html>"""

    path.write_text(html, encoding="utf-8")


def _render_failed_table(failed_tests: list) -> str:
    rows = ""
    for r in failed_tests:
        reason = r['longrepr'].replace('<', '&lt;').replace('>', '&gt;')
        rows += f"""
        <tr>
          <td><span class="test-name">{r['test']}</span></td>
          <td>{r['class']}</td>
          <td>{r['category']}</td>
          <td><span class="badge failed">FAILED</span></td>
          <td>{r['duration']}ms</td>
        </tr>
        <tr>
          <td colspan="5"><div class="failure-reason">{reason}</div></td>
        </tr>"""

    return f"""
    <div class="table-card">
      <h3><span class="icon">❌</span> Failed Tests — Root Cause Analysis</h3>
      <table>
        <thead>
          <tr><th>Test</th><th>Class</th><th>Category</th><th>Status</th><th>Duration</th></tr>
        </thead>
        <tbody>{rows}</tbody>
      </table>
    </div>"""


def _render_xfailed_table(xfailed_tests: list) -> str:
    rows = ""
    for r in xfailed_tests:
        reason = r['longrepr'].replace('<', '&lt;').replace('>', '&gt;') if r['longrepr'] else "Expected failure (intentional demo issue)"
        rows += f"""
        <tr>
          <td><span class="test-name">{r['test']}</span></td>
          <td>{r['class']}</td>
          <td>{r['category']}</td>
          <td><span class="badge xfailed">XFAILED</span></td>
          <td>{r['duration']}ms</td>
        </tr>
        <tr>
          <td colspan="5"><div class="xfail-reason">{reason}</div></td>
        </tr>"""

    return f"""
    <div class="table-card">
      <h3><span class="icon">⚠️</span> Expected Failures — Intentional Demo Issues</h3>
      <table>
        <thead>
          <tr><th>Test</th><th>Class</th><th>Category</th><th>Status</th><th>Duration</th></tr>
        </thead>
        <tbody>{rows}</tbody>
      </table>
    </div>"""


def _render_all_tests_table(results: list) -> str:
    max_duration = max((r["duration"] for r in results), default=1) or 1

    rows = ""
    for r in results:
        badge_class = r["outcome"]
        bar_width = min(100, r["duration"] / max_duration * 100)
        rows += f"""
        <tr>
          <td><span class="test-name">{r['test']}</span></td>
          <td>{r['class']}</td>
          <td>{r['category']}</td>
          <td><span class="badge {badge_class}">{r['outcome'].upper()}</span></td>
          <td>
            <div style="display:flex;align-items:center;gap:8px;">
              <div class="duration-bar"><div class="duration-fill" style="width:{bar_width}%"></div></div>
              <span style="font-size:0.8rem;color:var(--text-secondary);min-width:50px;">{r['duration']}ms</span>
            </div>
          </td>
        </tr>"""

    return f"""
    <div class="table-card">
      <h3><span class="icon">📋</span> All Test Results</h3>
      <div class="filter-bar">
        <button class="filter-btn" data-filter="all">All</button>
        <button class="filter-btn" data-filter="passed">✅ Passed</button>
        <button class="filter-btn" data-filter="failed">❌ Failed</button>
        <button class="filter-btn" data-filter="xfailed">⚠️ XFailed</button>
      </div>
      <table>
        <thead>
          <tr><th>Test</th><th>Class</th><th>Category</th><th>Status</th><th>Duration</th></tr>
        </thead>
        <tbody>{rows}</tbody>
      </table>
    </div>"""
