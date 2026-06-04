#!/usr/bin/env python3
"""
Test Dashboard Generator — OmniPresenseAI
Parses JUnit XML reports and creates an interactive HTML dashboard with Chart.js.
"""
import os
import sys
import xml.etree.ElementTree as ET
from datetime import datetime
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent
REPORTS_DIR = PROJECT_ROOT / "reports"
OUTPUT = REPORTS_DIR / "dashboard.html"


def parse_junit_xml(filepath):
    """Parse a JUnit XML and return suite data."""
    tree = ET.parse(filepath)
    root = tree.getroot()

    # If root is <testsuites>, the stats are on child <testsuite> element(s)
    if root.tag == "testsuites":
        child_suites = root.findall("testsuite")
        node = child_suites[0] if child_suites else root
    else:
        child_suites = [root]
        node = root

    suite_data = {
        "name": filepath.stem,
        "tests": sum(int(s.get("tests", 0)) for s in child_suites),
        "failures": sum(int(s.get("failures", 0)) for s in child_suites),
        "errors": sum(int(s.get("errors", 0)) for s in child_suites),
        "skipped": sum(int(s.get("skipped", 0)) for s in child_suites),
        "time": sum(float(s.get("time", 0)) for s in child_suites),
        "testcases": [],
    }
    suite_data["passed"] = suite_data["tests"] - suite_data["failures"] - suite_data["errors"] - suite_data["skipped"]

    for tc in root.iter("testcase"):
        status = "passed"
        message = ""
        if tc.find("failure") is not None:
            status = "failed"
            message = tc.find("failure").get("message", "")
        elif tc.find("error") is not None:
            status = "error"
            message = tc.find("error").get("message", "")
        elif tc.find("skipped") is not None:
            status = "skipped"
            message = tc.find("skipped").get("message", "")

        suite_data["testcases"].append({
            "classname": tc.get("classname", ""),
            "name": tc.get("name", ""),
            "time": float(tc.get("time", 0)),
            "status": status,
            "message": message,
        })

    return suite_data


def get_compliance_category(testname):
    """Map test names to compliance categories for the radar chart."""
    name = testname.lower()
    if any(k in name for k in ["hipaa", "encryption", "kms", "ssm", "secure", "transit", "pii", "phi", "macie"]):
        return "HIPAA"
    if any(k in name for k in ["pci", "waf", "sqli", "owasp", "bot", "rate"]):
        return "PCI-DSS"
    if any(k in name for k in ["sox", "cloudtrail", "audit", "access_analyzer", "retention"]):
        return "SOX"
    if any(k in name for k in ["gdpr", "pii", "redaction", "anonymize", "versioning"]):
        return "GDPR"
    if any(k in name for k in ["bedrock", "guardrail", "prompt", "content_filter", "topic", "ai"]):
        return "AI Lens"
    return "General"


def generate_html(suites):
    """Generate the full HTML dashboard."""
    total_tests = sum(s["tests"] for s in suites)
    total_passed = sum(s["passed"] for s in suites)
    total_failed = sum(s["failures"] for s in suites)
    total_errors = sum(s["errors"] for s in suites)
    total_time = sum(s["time"] for s in suites)
    pass_rate = (total_passed / total_tests * 100) if total_tests > 0 else 0
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    # Compliance category counts (from terraform compliance tests)
    compliance_cats = {"HIPAA": 0, "PCI-DSS": 0, "SOX": 0, "GDPR": 0, "AI Lens": 0, "General": 0}
    compliance_passed = {"HIPAA": 0, "PCI-DSS": 0, "SOX": 0, "GDPR": 0, "AI Lens": 0, "General": 0}
    for s in suites:
        if "terraform" in s["name"].lower() or "compliance" in s["name"].lower():
            for tc in s["testcases"]:
                cat = get_compliance_category(tc["name"])
                compliance_cats[cat] += 1
                if tc["status"] == "passed":
                    compliance_passed[cat] += 1

    # Suite breakdown for bar chart
    suite_names = [s["name"].replace("tests.", "").replace("test_", "") for s in suites]
    suite_passed = [s["passed"] for s in suites]
    suite_failed = [s["failures"] + s["errors"] for s in suites]

    # Test duration data
    slowest_tests = []
    for s in suites:
        for tc in s["testcases"]:
            slowest_tests.append({"name": tc["name"], "suite": s["name"], "time": tc["time"]})
    slowest_tests.sort(key=lambda x: x["time"], reverse=True)
    slowest_10 = slowest_tests[:10]

    # Category distribution
    categories = {}
    for s in suites:
        for tc in s["testcases"]:
            cls = tc["classname"].split(".")[-1] if tc["classname"] else "Uncategorized"
            categories.setdefault(cls, {"passed": 0, "failed": 0})
            if tc["status"] == "passed":
                categories[cls]["passed"] += 1
            else:
                categories[cls]["failed"] += 1

    html = f'''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OmniPresenseAI — Test Report Dashboard</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"></script>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
        :root {{
            --bg-primary: #0f0f1a;
            --bg-secondary: #1a1a2e;
            --bg-card: #16213e;
            --bg-card-hover: #1a2744;
            --text-primary: #e8e8f0;
            --text-secondary: #9a9ab0;
            --text-muted: #6b6b82;
            --accent-green: #00d68f;
            --accent-green-glow: rgba(0, 214, 143, 0.15);
            --accent-red: #ff3d71;
            --accent-red-glow: rgba(255, 61, 113, 0.15);
            --accent-blue: #3366ff;
            --accent-blue-glow: rgba(51, 102, 255, 0.15);
            --accent-amber: #ffaa00;
            --accent-amber-glow: rgba(255, 170, 0, 0.15);
            --accent-purple: #b366ff;
            --border: rgba(255, 255, 255, 0.06);
            --shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
            --radius: 16px;
            --transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
        }}

        * {{ margin: 0; padding: 0; box-sizing: border-box; }}

        body {{
            font-family: 'Inter', system-ui, -apple-system, sans-serif;
            background: var(--bg-primary);
            color: var(--text-primary);
            min-height: 100vh;
            line-height: 1.6;
        }}

        .container {{
            max-width: 1440px;
            margin: 0 auto;
            padding: 32px 40px;
        }}

        /* Header */
        .header {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 40px;
            padding-bottom: 24px;
            border-bottom: 1px solid var(--border);
        }}
        .header h1 {{
            font-size: 28px;
            font-weight: 800;
            background: linear-gradient(135deg, var(--accent-blue), var(--accent-purple));
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            letter-spacing: -0.5px;
        }}
        .header .meta {{
            text-align: right;
            color: var(--text-secondary);
            font-size: 13px;
        }}
        .header .meta .badge {{
            display: inline-block;
            padding: 4px 12px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 600;
            margin-left: 8px;
        }}
        .badge-pass {{ background: var(--accent-green-glow); color: var(--accent-green); border: 1px solid rgba(0,214,143,0.3); }}
        .badge-fail {{ background: var(--accent-red-glow); color: var(--accent-red); border: 1px solid rgba(255,61,113,0.3); }}

        /* KPI Cards */
        .kpi-grid {{
            display: grid;
            grid-template-columns: repeat(5, 1fr);
            gap: 20px;
            margin-bottom: 32px;
        }}
        .kpi-card {{
            background: var(--bg-card);
            border: 1px solid var(--border);
            border-radius: var(--radius);
            padding: 24px;
            position: relative;
            overflow: hidden;
            transition: var(--transition);
        }}
        .kpi-card:hover {{
            background: var(--bg-card-hover);
            transform: translateY(-2px);
            box-shadow: var(--shadow);
        }}
        .kpi-card .label {{
            font-size: 12px;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 1px;
            color: var(--text-muted);
            margin-bottom: 8px;
        }}
        .kpi-card .value {{
            font-size: 36px;
            font-weight: 800;
            letter-spacing: -1px;
        }}
        .kpi-card .subtext {{
            font-size: 12px;
            color: var(--text-secondary);
            margin-top: 4px;
        }}
        .kpi-card::after {{
            content: '';
            position: absolute;
            top: 0; left: 0; right: 0;
            height: 3px;
        }}
        .kpi-green::after {{ background: linear-gradient(90deg, var(--accent-green), #00e6a0); }}
        .kpi-green .value {{ color: var(--accent-green); }}
        .kpi-red::after {{ background: linear-gradient(90deg, var(--accent-red), #ff6b8a); }}
        .kpi-red .value {{ color: var(--accent-red); }}
        .kpi-blue::after {{ background: linear-gradient(90deg, var(--accent-blue), #5c85ff); }}
        .kpi-blue .value {{ color: var(--accent-blue); }}
        .kpi-amber::after {{ background: linear-gradient(90deg, var(--accent-amber), #ffcc44); }}
        .kpi-amber .value {{ color: var(--accent-amber); }}
        .kpi-purple::after {{ background: linear-gradient(90deg, var(--accent-purple), #cc88ff); }}
        .kpi-purple .value {{ color: var(--accent-purple); }}

        /* Charts grid */
        .charts-grid {{
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 24px;
            margin-bottom: 32px;
        }}
        .chart-card {{
            background: var(--bg-card);
            border: 1px solid var(--border);
            border-radius: var(--radius);
            padding: 28px;
            transition: var(--transition);
        }}
        .chart-card:hover {{
            box-shadow: var(--shadow);
        }}
        .chart-card h3 {{
            font-size: 16px;
            font-weight: 600;
            margin-bottom: 20px;
            color: var(--text-primary);
        }}
        .chart-card h3 span {{
            font-size: 12px;
            color: var(--text-muted);
            font-weight: 400;
            margin-left: 8px;
        }}

        /* Test detail table */
        .table-card {{
            background: var(--bg-card);
            border: 1px solid var(--border);
            border-radius: var(--radius);
            padding: 28px;
            margin-bottom: 32px;
            overflow-x: auto;
        }}
        .table-card h3 {{
            font-size: 16px;
            font-weight: 600;
            margin-bottom: 16px;
        }}
        table {{
            width: 100%;
            border-collapse: collapse;
            font-size: 13px;
        }}
        th {{
            text-align: left;
            padding: 12px 16px;
            font-weight: 600;
            font-size: 11px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            color: var(--text-muted);
            border-bottom: 1px solid var(--border);
        }}
        td {{
            padding: 10px 16px;
            border-bottom: 1px solid var(--border);
            color: var(--text-secondary);
        }}
        tr:hover td {{
            background: rgba(255,255,255,0.02);
        }}
        .status-dot {{
            display: inline-block;
            width: 8px;
            height: 8px;
            border-radius: 50%;
            margin-right: 8px;
        }}
        .dot-pass {{ background: var(--accent-green); box-shadow: 0 0 8px var(--accent-green-glow); }}
        .dot-fail {{ background: var(--accent-red); box-shadow: 0 0 8px var(--accent-red-glow); }}

        .progress-bar {{
            width: 100%;
            height: 6px;
            background: rgba(255,255,255,0.06);
            border-radius: 3px;
            overflow: hidden;
        }}
        .progress-fill {{
            height: 100%;
            border-radius: 3px;
            transition: width 1s ease;
        }}
        .fill-green {{ background: linear-gradient(90deg, var(--accent-green), #00e6a0); }}

        .footer {{
            text-align: center;
            padding: 24px;
            color: var(--text-muted);
            font-size: 12px;
            border-top: 1px solid var(--border);
            margin-top: 32px;
        }}

        @media (max-width: 1024px) {{
            .kpi-grid {{ grid-template-columns: repeat(3, 1fr); }}
            .charts-grid {{ grid-template-columns: 1fr; }}
        }}
        @media (max-width: 640px) {{
            .kpi-grid {{ grid-template-columns: repeat(2, 1fr); }}
            .container {{ padding: 16px; }}
        }}
    </style>
</head>
<body>
    <div class="container">
        <!-- Header -->
        <div class="header">
            <div>
                <h1>🧪 OmniPresenseAI — Test Report</h1>
            </div>
            <div class="meta">
                <div>Generated: {now}</div>
                <div style="margin-top:4px">
                    <span class="badge {"badge-pass" if total_failed == 0 else "badge-fail"}">
                        {"✅ ALL PASSED" if total_failed == 0 else f"❌ {total_failed} FAILED"}
                    </span>
                </div>
            </div>
        </div>

        <!-- KPI Cards -->
        <div class="kpi-grid">
            <div class="kpi-card kpi-blue">
                <div class="label">Total Tests</div>
                <div class="value">{total_tests}</div>
                <div class="subtext">across {len(suites)} test suites</div>
            </div>
            <div class="kpi-card kpi-green">
                <div class="label">Passed</div>
                <div class="value">{total_passed}</div>
                <div class="subtext">{pass_rate:.1f}% pass rate</div>
            </div>
            <div class="kpi-card {"kpi-red" if total_failed > 0 else "kpi-green"}">
                <div class="label">Failed</div>
                <div class="value">{total_failed}</div>
                <div class="subtext">{total_errors} errors</div>
            </div>
            <div class="kpi-card kpi-amber">
                <div class="label">Duration</div>
                <div class="value">{total_time:.1f}s</div>
                <div class="subtext">total execution time</div>
            </div>
            <div class="kpi-card kpi-purple">
                <div class="label">Suites</div>
                <div class="value">{len(suites)}</div>
                <div class="subtext">test categories</div>
            </div>
        </div>

        <!-- Charts Row 1 -->
        <div class="charts-grid">
            <div class="chart-card">
                <h3>Test Results by Suite <span>pass / fail breakdown</span></h3>
                <canvas id="suiteChart" height="260"></canvas>
            </div>
            <div class="chart-card">
                <h3>Overall Pass Rate <span>donut distribution</span></h3>
                <canvas id="donutChart" height="260"></canvas>
            </div>
        </div>

        <!-- Charts Row 2 -->
        <div class="charts-grid">
            <div class="chart-card">
                <h3>Compliance Coverage <span>regulatory framework tests</span></h3>
                <canvas id="radarChart" height="280"></canvas>
            </div>
            <div class="chart-card">
                <h3>Test Class Distribution <span>tests per class</span></h3>
                <canvas id="classChart" height="280"></canvas>
            </div>
        </div>

        <!-- Charts Row 3 -->
        <div class="charts-grid">
            <div class="chart-card">
                <h3>Slowest Tests <span>top 10 by execution time</span></h3>
                <canvas id="durationChart" height="280"></canvas>
            </div>
            <div class="chart-card">
                <h3>Suite Duration Breakdown <span>seconds per suite</span></h3>
                <canvas id="timePieChart" height="280"></canvas>
            </div>
        </div>

        <!-- Suite Details -->
        <div class="table-card">
            <h3>Suite Summary</h3>
            <table>
                <thead>
                    <tr>
                        <th>Suite</th>
                        <th>Tests</th>
                        <th>Passed</th>
                        <th>Failed</th>
                        <th>Duration</th>
                        <th>Pass Rate</th>
                        <th style="width:200px">Progress</th>
                    </tr>
                </thead>
                <tbody>'''

    for s in suites:
        pct = (s["passed"] / s["tests"] * 100) if s["tests"] > 0 else 0
        html += f'''
                    <tr>
                        <td><strong>{s["name"]}</strong></td>
                        <td>{s["tests"]}</td>
                        <td style="color:var(--accent-green)">{s["passed"]}</td>
                        <td style="color:{"var(--accent-red)" if s["failures"] > 0 else "var(--text-muted)"}">{s["failures"]}</td>
                        <td>{s["time"]:.2f}s</td>
                        <td style="color:var(--accent-green)">{pct:.0f}%</td>
                        <td>
                            <div class="progress-bar">
                                <div class="progress-fill fill-green" style="width:{pct}%"></div>
                            </div>
                        </td>
                    </tr>'''

    html += '''
                </tbody>
            </table>
        </div>

        <!-- Detailed Test Cases -->'''

    for s in suites:
        html += f'''
        <div class="table-card">
            <h3>{s["name"]} <span style="color:var(--text-muted);font-weight:400;font-size:13px">— {s["tests"]} tests, {s["time"]:.2f}s</span></h3>
            <table>
                <thead>
                    <tr>
                        <th style="width:30px">Status</th>
                        <th>Test Name</th>
                        <th>Class</th>
                        <th style="width:80px">Duration</th>
                    </tr>
                </thead>
                <tbody>'''
        for tc in s["testcases"]:
            dot = "dot-pass" if tc["status"] == "passed" else "dot-fail"
            cls = tc["classname"].split(".")[-1] if tc["classname"] else ""
            html += f'''
                    <tr>
                        <td><span class="status-dot {dot}"></span></td>
                        <td>{tc["name"]}</td>
                        <td style="color:var(--text-muted)">{cls}</td>
                        <td>{tc["time"]*1000:.0f}ms</td>
                    </tr>'''
        html += '''
                </tbody>
            </table>
        </div>'''

    # Chart.js scripts
    cat_labels = list(compliance_cats.keys())
    cat_values = [compliance_passed.get(c, 0) for c in cat_labels]
    cat_totals = [compliance_cats.get(c, 0) for c in cat_labels]
    cat_pcts = [(compliance_passed[c] / compliance_cats[c] * 100) if compliance_cats[c] > 0 else 0 for c in cat_labels]

    class_labels = list(categories.keys())[:12]
    class_passed = [categories[c]["passed"] for c in class_labels]
    class_failed = [categories[c]["failed"] for c in class_labels]

    slow_labels = [t["name"][:35] for t in slowest_10]
    slow_values = [t["time"] * 1000 for t in slowest_10]

    suite_times = [s["time"] for s in suites]

    html += f'''

        <div class="footer">
            OmniPresenseAI Test Dashboard — Generated by pytest + Chart.js — {now}
        </div>
    </div>

    <script>
        Chart.defaults.color = '#9a9ab0';
        Chart.defaults.borderColor = 'rgba(255,255,255,0.06)';
        Chart.defaults.font.family = "'Inter', system-ui, sans-serif";

        // 1. Suite Bar Chart
        new Chart(document.getElementById('suiteChart'), {{
            type: 'bar',
            data: {{
                labels: {suite_names},
                datasets: [
                    {{
                        label: 'Passed',
                        data: {suite_passed},
                        backgroundColor: 'rgba(0, 214, 143, 0.8)',
                        borderRadius: 6,
                        borderSkipped: false,
                    }},
                    {{
                        label: 'Failed',
                        data: {suite_failed},
                        backgroundColor: 'rgba(255, 61, 113, 0.8)',
                        borderRadius: 6,
                        borderSkipped: false,
                    }}
                ]
            }},
            options: {{
                responsive: true,
                plugins: {{
                    legend: {{ position: 'top', labels: {{ usePointStyle: true, pointStyle: 'circle' }} }}
                }},
                scales: {{
                    y: {{ beginAtZero: true, grid: {{ color: 'rgba(255,255,255,0.04)' }} }},
                    x: {{ grid: {{ display: false }} }}
                }}
            }}
        }});

        // 2. Donut Chart
        new Chart(document.getElementById('donutChart'), {{
            type: 'doughnut',
            data: {{
                labels: ['Passed', 'Failed', 'Errors'],
                datasets: [{{
                    data: [{total_passed}, {total_failed}, {total_errors}],
                    backgroundColor: ['rgba(0,214,143,0.85)', 'rgba(255,61,113,0.85)', 'rgba(255,170,0,0.85)'],
                    borderWidth: 0,
                    hoverOffset: 8,
                }}]
            }},
            options: {{
                responsive: true,
                cutout: '65%',
                plugins: {{
                    legend: {{ position: 'bottom', labels: {{ usePointStyle: true, pointStyle: 'circle', padding: 20 }} }}
                }}
            }}
        }});

        // 3. Compliance Radar
        new Chart(document.getElementById('radarChart'), {{
            type: 'radar',
            data: {{
                labels: {cat_labels},
                datasets: [{{
                    label: 'Pass Rate %',
                    data: {[round(p, 1) for p in cat_pcts]},
                    backgroundColor: 'rgba(51, 102, 255, 0.15)',
                    borderColor: 'rgba(51, 102, 255, 0.8)',
                    pointBackgroundColor: 'rgba(51, 102, 255, 1)',
                    pointRadius: 5,
                    borderWidth: 2,
                }},
                {{
                    label: 'Tests Count',
                    data: {cat_totals},
                    backgroundColor: 'rgba(179, 102, 255, 0.1)',
                    borderColor: 'rgba(179, 102, 255, 0.6)',
                    pointBackgroundColor: 'rgba(179, 102, 255, 1)',
                    pointRadius: 4,
                    borderWidth: 2,
                }}]
            }},
            options: {{
                responsive: true,
                scales: {{
                    r: {{
                        beginAtZero: true,
                        grid: {{ color: 'rgba(255,255,255,0.06)' }},
                        angleLines: {{ color: 'rgba(255,255,255,0.06)' }},
                        pointLabels: {{ font: {{ size: 12 }} }}
                    }}
                }},
                plugins: {{
                    legend: {{ position: 'bottom', labels: {{ usePointStyle: true, pointStyle: 'circle' }} }}
                }}
            }}
        }});

        // 4. Class Distribution
        new Chart(document.getElementById('classChart'), {{
            type: 'bar',
            data: {{
                labels: {class_labels},
                datasets: [{{
                    label: 'Passed',
                    data: {class_passed},
                    backgroundColor: 'rgba(0, 214, 143, 0.7)',
                    borderRadius: 4,
                }},
                {{
                    label: 'Failed',
                    data: {class_failed},
                    backgroundColor: 'rgba(255, 61, 113, 0.7)',
                    borderRadius: 4,
                }}]
            }},
            options: {{
                indexAxis: 'y',
                responsive: true,
                plugins: {{
                    legend: {{ display: false }}
                }},
                scales: {{
                    x: {{ stacked: true, grid: {{ color: 'rgba(255,255,255,0.04)' }} }},
                    y: {{ stacked: true, grid: {{ display: false }}, ticks: {{ font: {{ size: 11 }} }} }}
                }}
            }}
        }});

        // 5. Slowest Tests
        new Chart(document.getElementById('durationChart'), {{
            type: 'bar',
            data: {{
                labels: {slow_labels},
                datasets: [{{
                    label: 'Duration (ms)',
                    data: {[round(v, 1) for v in slow_values]},
                    backgroundColor: (ctx) => {{
                        const g = ctx.chart.ctx.createLinearGradient(0, 0, ctx.chart.width, 0);
                        g.addColorStop(0, 'rgba(255, 170, 0, 0.7)');
                        g.addColorStop(1, 'rgba(255, 61, 113, 0.7)');
                        return g;
                    }},
                    borderRadius: 4,
                }}]
            }},
            options: {{
                indexAxis: 'y',
                responsive: true,
                plugins: {{ legend: {{ display: false }} }},
                scales: {{
                    x: {{ grid: {{ color: 'rgba(255,255,255,0.04)' }}, title: {{ display: true, text: 'milliseconds' }} }},
                    y: {{ grid: {{ display: false }}, ticks: {{ font: {{ size: 10 }} }} }}
                }}
            }}
        }});

        // 6. Suite Duration Pie
        new Chart(document.getElementById('timePieChart'), {{
            type: 'polarArea',
            data: {{
                labels: {suite_names},
                datasets: [{{
                    data: {[round(t, 2) for t in suite_times]},
                    backgroundColor: [
                        'rgba(51, 102, 255, 0.7)',
                        'rgba(0, 214, 143, 0.7)',
                        'rgba(255, 170, 0, 0.7)',
                        'rgba(179, 102, 255, 0.7)'
                    ],
                    borderWidth: 0,
                }}]
            }},
            options: {{
                responsive: true,
                scales: {{
                    r: {{ grid: {{ color: 'rgba(255,255,255,0.06)' }}, ticks: {{ display: false }} }}
                }},
                plugins: {{
                    legend: {{ position: 'bottom', labels: {{ usePointStyle: true, pointStyle: 'circle', padding: 16 }} }}
                }}
            }}
        }});
    </script>
</body>
</html>'''

    return html


def main():
    xml_files = sorted(REPORTS_DIR.glob("*.xml"))
    if not xml_files:
        print("❌ No XML reports found in reports/. Run tests first.")
        sys.exit(1)

    suites = []
    for f in xml_files:
        print(f"  📄 Parsing {f.name}")
        suites.append(parse_junit_xml(f))

    html = generate_html(suites)
    OUTPUT.write_text(html)
    print(f"\n✅ Dashboard generated: {OUTPUT}")
    print(f"   Open: file://{OUTPUT}")


if __name__ == "__main__":
    main()
