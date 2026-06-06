"""Report formatters — JSON, Markdown, HTML, and Rich terminal output."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Optional
from datetime import datetime

from core.analyzer import AnalysisResult, Severity


# ── Terminal Colors (Rich-free fallback) ──────────────────────────────────────

SEVERITY_COLORS = {
    "CRITICAL": "\033[91m",  # Red
    "HIGH": "\033[93m",      # Yellow
    "MEDIUM": "\033[33m",    # Orange
    "LOW": "\033[96m",       # Cyan
    "INFO": "\033[90m",      # Gray
}
RESET = "\033[0m"
BOLD = "\033[1m"
GREEN = "\033[92m"
RED = "\033[91m"


def print_terminal(result: AnalysisResult) -> None:
    """Print a colorized summary to the terminal."""
    status = f"{GREEN}PASSED{RESET}" if result.passed else f"{RED}FAILED{RESET}"
    print(f"\n{BOLD}{'═' * 70}{RESET}")
    print(f"{BOLD}  {result.tool_name} v{result.tool_version}{RESET}")
    print(f"  Target: {result.target}")
    print(f"  Status: {status}  |  Total Findings: {len(result.findings)}")
    print(f"{BOLD}{'═' * 70}{RESET}")

    counts = result.severity_counts
    print(f"  {SEVERITY_COLORS['CRITICAL']}CRITICAL: {counts['CRITICAL']}{RESET}"
          f"  {SEVERITY_COLORS['HIGH']}HIGH: {counts['HIGH']}{RESET}"
          f"  {SEVERITY_COLORS['MEDIUM']}MEDIUM: {counts['MEDIUM']}{RESET}"
          f"  {SEVERITY_COLORS['LOW']}LOW: {counts['LOW']}{RESET}"
          f"  {SEVERITY_COLORS['INFO']}INFO: {counts['INFO']}{RESET}")
    print(f"{'─' * 70}")

    for f in result.findings:
        color = SEVERITY_COLORS.get(f.severity.value, "")
        loc = f"  @ {f.location}" if f.location else ""
        line = f":{f.line_number}" if f.line_number else ""
        print(f"  {color}[{f.severity.value:8s}]{RESET} {f.title}{loc}{line}")
        print(f"             {f.message}")
        if f.recommendation:
            print(f"          {GREEN}→ {f.recommendation}{RESET}")
        print()


# ── JSON Output ───────────────────────────────────────────────────────────────

def to_json(result: AnalysisResult, output_path: Optional[str] = None) -> str:
    """Export result as JSON."""
    data = result.to_json(indent=2)
    if output_path:
        Path(output_path).parent.mkdir(parents=True, exist_ok=True)
        Path(output_path).write_text(data, encoding="utf-8")
    return data


# ── Markdown Output ───────────────────────────────────────────────────────────

def to_markdown(result: AnalysisResult, output_path: Optional[str] = None) -> str:
    """Export result as a Markdown report."""
    sev_icons = {
        "CRITICAL": "🔴", "HIGH": "🟠", "MEDIUM": "🟡", "LOW": "🔵", "INFO": "⚪"
    }
    status_icon = "✅" if result.passed else "❌"
    lines = [
        f"# {status_icon} {result.tool_name} Report",
        "",
        f"**Target:** `{result.target}`  ",
        f"**Date:** {datetime.now().strftime('%Y-%m-%d %H:%M')}  ",
        f"**Status:** {'PASSED' if result.passed else 'FAILED'}  ",
        f"**Total Findings:** {len(result.findings)}",
        "",
        "## Severity Summary",
        "",
        "| Severity | Count |",
        "|----------|-------|",
    ]
    for sev, count in result.severity_counts.items():
        lines.append(f"| {sev_icons.get(sev, '')} {sev} | {count} |")

    if result.category_counts:
        lines += [
            "",
            "## Category Breakdown",
            "",
            "| Category | Count |",
            "|----------|-------|",
        ]
        for cat, count in sorted(result.category_counts.items()):
            lines.append(f"| {cat} | {count} |")

    lines += ["", "## Findings", ""]
    for i, f in enumerate(result.findings, 1):
        icon = sev_icons.get(f.severity.value, "")
        lines.append(f"### {i}. {icon} [{f.severity.value}] {f.title}")
        if f.location:
            loc = f"`{f.location}`"
            if f.line_number:
                loc += f" (line {f.line_number})"
            lines.append(f"**Location:** {loc}  ")
        lines.append(f"**Category:** {f.category.value}  ")
        lines.append(f"\n{f.message}")
        if f.recommendation:
            lines.append(f"\n> **Recommendation:** {f.recommendation}")
        lines.append("")

    md = "\n".join(lines)
    if output_path:
        Path(output_path).parent.mkdir(parents=True, exist_ok=True)
        Path(output_path).write_text(md, encoding="utf-8")
    return md


# ── HTML Dashboard ────────────────────────────────────────────────────────────

def to_html(result: AnalysisResult, output_path: Optional[str] = None) -> str:
    """Export result as an HTML dashboard with Chart.js visualizations."""
    sev_colors_html = {
        "CRITICAL": "#dc3545", "HIGH": "#fd7e14", "MEDIUM": "#ffc107",
        "LOW": "#17a2b8", "INFO": "#6c757d",
    }
    counts = result.severity_counts
    status_class = "pass" if result.passed else "fail"
    status_text = "PASSED" if result.passed else "FAILED"

    findings_rows = ""
    for f in result.findings:
        color = sev_colors_html.get(f.severity.value, "#333")
        findings_rows += f"""
        <tr>
          <td><span class="badge" style="background:{color}">{f.severity.value}</span></td>
          <td>{f.category.value}</td>
          <td><strong>{f.title}</strong><br><small>{f.message}</small></td>
          <td><code>{f.location or 'N/A'}</code></td>
          <td>{f.recommendation or '—'}</td>
        </tr>"""

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{result.tool_name} — Report</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4"></script>
<style>
  :root {{ --bg: #0f1117; --card: #1a1d29; --text: #e1e4e8; --border: #2d3139; }}
  * {{ margin:0;padding:0;box-sizing:border-box; }}
  body {{ font-family:'Segoe UI',system-ui,sans-serif;background:var(--bg);color:var(--text);padding:2rem; }}
  .header {{ text-align:center;margin-bottom:2rem; }}
  .header h1 {{ font-size:1.8rem;margin-bottom:.5rem; }}
  .status {{ display:inline-block;padding:.4rem 1.2rem;border-radius:8px;font-weight:700;font-size:1.1rem; }}
  .status.pass {{ background:#28a745;color:#fff; }}
  .status.fail {{ background:#dc3545;color:#fff; }}
  .grid {{ display:grid;grid-template-columns:1fr 1fr;gap:1.5rem;margin-bottom:2rem; }}
  .card {{ background:var(--card);border:1px solid var(--border);border-radius:12px;padding:1.5rem; }}
  .card h3 {{ margin-bottom:1rem;font-size:1rem;color:#8b949e; }}
  canvas {{ max-height:250px; }}
  table {{ width:100%;border-collapse:collapse;margin-top:1rem; }}
  th,td {{ padding:.75rem 1rem;text-align:left;border-bottom:1px solid var(--border);font-size:.85rem; }}
  th {{ color:#8b949e;font-weight:600;text-transform:uppercase;font-size:.75rem; }}
  .badge {{ display:inline-block;padding:.2rem .6rem;border-radius:4px;color:#fff;font-size:.75rem;font-weight:600; }}
  small {{ color:#8b949e; }}
  @media(max-width:768px) {{ .grid {{ grid-template-columns:1fr; }} }}
</style>
</head>
<body>
<div class="header">
  <h1>🔧 {result.tool_name}</h1>
  <p>Target: <code>{result.target}</code> &nbsp;|&nbsp; Findings: {len(result.findings)}</p>
  <p style="margin-top:.5rem"><span class="status {status_class}">{status_text}</span></p>
</div>
<div class="grid">
  <div class="card"><h3>Severity Distribution</h3><canvas id="sevChart"></canvas></div>
  <div class="card"><h3>Category Breakdown</h3><canvas id="catChart"></canvas></div>
</div>
<div class="card">
  <h3>Findings Detail</h3>
  <table>
    <thead><tr><th>Severity</th><th>Category</th><th>Finding</th><th>Location</th><th>Recommendation</th></tr></thead>
    <tbody>{findings_rows}</tbody>
  </table>
</div>
<script>
const sevData = {{
  labels: {json.dumps(list(counts.keys()))},
  datasets: [{{ data: {json.dumps(list(counts.values()))},
    backgroundColor: {json.dumps([sev_colors_html[s] for s in counts.keys()])},
    borderWidth: 0 }}]
}};
new Chart(document.getElementById('sevChart'), {{
  type: 'doughnut', data: sevData,
  options: {{ plugins: {{ legend: {{ labels: {{ color: '#e1e4e8' }} }} }}, responsive: true }}
}});
const catCounts = {json.dumps(result.category_counts)};
new Chart(document.getElementById('catChart'), {{
  type: 'bar',
  data: {{ labels: Object.keys(catCounts),
           datasets: [{{ data: Object.values(catCounts), backgroundColor: '#58a6ff', borderRadius: 6 }}] }},
  options: {{
    plugins: {{ legend: {{ display: false }} }},
    scales: {{ x: {{ ticks: {{ color:'#8b949e' }} }}, y: {{ ticks: {{ color:'#8b949e' }}, beginAtZero: true }} }},
    responsive: true
  }}
}});
</script>
</body>
</html>"""
    if output_path:
        Path(output_path).parent.mkdir(parents=True, exist_ok=True)
        Path(output_path).write_text(html, encoding="utf-8")
    return html
