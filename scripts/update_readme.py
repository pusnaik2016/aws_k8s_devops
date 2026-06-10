#!/usr/bin/env python3
"""
Auto-update root README.md when projects are added/removed.

This script:
1. Scans all project directories (excluding hidden dirs, scripts, docs, etc.)
2. Reads each project's README.md to extract the title and description
3. Updates the "Repository Structure" section in the root README.md
4. Optionally converts the Enterprise Architect Playbook to PDF via pandoc

Usage:
    python3 scripts/update_readme.py                  # Update README only
    python3 scripts/update_readme.py --generate-pdf   # Update README + generate PDFs

Designed to run in GitHub Actions on every push, or locally.
"""

import os
import re
import sys
import subprocess
import argparse
from pathlib import Path

# ─── Configuration ───────────────────────────────────────────────────────────

REPO_ROOT = Path(__file__).resolve().parent.parent
README_PATH = REPO_ROOT / "README.md"
PLAYBOOK_PATH = REPO_ROOT / "interview-prep-docs" / "Enterprise_Principal_Cloud_Architect_Playbook.md"
PDF_OUTPUT_DIR = REPO_ROOT / "docs" / "pdf"

# Directories to SKIP when scanning for projects
SKIP_DIRS = {
    ".git", ".github", ".vscode", ".venv", ".sixth", ".DS_Store",
    "scripts", "docs", "node_modules", "__pycache__",
}

# Emoji map for project categorization (based on keywords in README)
CATEGORY_EMOJI = {
    "eks": "🌐",
    "kubernetes": "🌐",
    "devsecops": "🛡️",
    "security": "🛡️",
    "java": "☕",
    "bedrock": "🤖",
    "rag": "💬",
    "anomaly": "🔍",
    "cost": "🔍",
    "iot": "📡",
    "greengrass": "📡",
    "claude": "🤖",
    "devops": "🔧",
    "toolkit": "🔧",
    "debug": "🔧",
    "multicloud": "🏗️",
    "clearing": "🏗️",
    "ai": "🤖",
    "support": "🤖",
    "omnichannel": "🤖",
    "memory": "🧠",
    "agent": "🧠",
    "interview": "📚",
    "docs": "📚",
    "prep": "📚",
}


# ─── Project Discovery ──────────────────────────────────────────────────────

def discover_projects() -> list[dict]:
    """Scan repo root for project directories and extract metadata."""
    projects = []

    for entry in sorted(REPO_ROOT.iterdir()):
        if not entry.is_dir():
            continue
        if entry.name.startswith("."):
            continue
        if entry.name in SKIP_DIRS:
            continue

        project = {
            "name": entry.name,
            "path": entry,
            "title": None,
            "description": None,
            "emoji": "📁",
        }

        # Try to read the project's README.md
        readme_path = entry / "README.md"
        if readme_path.exists():
            try:
                content = readme_path.read_text(encoding="utf-8", errors="ignore")
                project["title"], project["description"] = extract_readme_info(content)
            except Exception:
                pass

        # Assign emoji based on directory name keywords
        name_lower = entry.name.lower()
        for keyword, emoji in CATEGORY_EMOJI.items():
            if keyword in name_lower:
                project["emoji"] = emoji
                break

        projects.append(project)

    return projects


def extract_readme_info(content: str) -> tuple[str | None, str | None]:
    """Extract the first H1 title and first blockquote/paragraph as description."""
    title = None
    description = None

    # Extract first H1
    h1_match = re.search(r"^#\s+(.+)$", content, re.MULTILINE)
    if h1_match:
        title = h1_match.group(1).strip()

    # Extract first blockquote (> ...) as description
    bq_match = re.search(r"^>\s+(.+)$", content, re.MULTILINE)
    if bq_match:
        description = bq_match.group(1).strip()

    # Fallback: first non-empty paragraph after the title
    if not description:
        paragraphs = re.findall(r"\n\n([A-Z][^\n]+)", content)
        if paragraphs:
            description = paragraphs[0].strip()[:200]

    return title, description


# ─── README Update ───────────────────────────────────────────────────────────

def generate_structure_block(projects: list[dict]) -> str:
    """Generate the repository structure tree block."""
    lines = ["```", "aws_k8s_devops/", "│"]

    for i, p in enumerate(projects):
        is_last = i == len(projects) - 1
        prefix = "└──" if is_last else "├──"
        # Truncate description for tree view
        short_desc = (p["description"] or p["title"] or "Project directory")[:60]
        lines.append(f"{prefix} {p['name'] + '/':45s} # {p['emoji']} {short_desc}")

    lines.extend(["└── README.md" + " " * 37 + "# ← You are here", "```"])
    return "\n".join(lines)


def update_readme(projects: list[dict]) -> bool:
    """Update the Repository Structure section in the root README.md."""
    if not README_PATH.exists():
        print(f"❌ README not found at {README_PATH}")
        return False

    content = README_PATH.read_text(encoding="utf-8")

    # ── Update the repository structure tree ──
    # Find the section between "## 🗂️ Repository Structure" and the next "---"
    structure_pattern = re.compile(
        r"(## 🗂️ Repository Structure\s*\n\s*\n)```[\s\S]*?```",
        re.MULTILINE,
    )
    new_structure = generate_structure_block(projects)

    if structure_pattern.search(content):
        content = structure_pattern.sub(
            rf"\g<1>{new_structure}",
            content,
        )
        print(f"✅ Updated Repository Structure ({len(projects)} projects)")
    else:
        print("⚠️  Could not find '## 🗂️ Repository Structure' section — skipping tree update")

    README_PATH.write_text(content, encoding="utf-8")
    return True


# ─── PDF Generation ──────────────────────────────────────────────────────────

def generate_pdf(input_md: Path, output_pdf: Path) -> bool:
    """Convert a Markdown file to PDF using pandoc."""
    # Check if pandoc is available
    try:
        subprocess.run(["pandoc", "--version"], capture_output=True, check=True)
    except (FileNotFoundError, subprocess.CalledProcessError):
        print("⚠️  pandoc not found — skipping PDF generation")
        print("   Install: brew install pandoc (macOS) or apt install pandoc (Linux)")
        return False

    # Create output directory
    output_pdf.parent.mkdir(parents=True, exist_ok=True)

    cmd = [
        "pandoc",
        str(input_md),
        "-o", str(output_pdf),
        "--pdf-engine=pdflatex",
        "-V", "geometry:margin=1in",
        "-V", "fontsize=11pt",
        "-V", "colorlinks=true",
        "-V", "linkcolor=blue",
        "-V", "urlcolor=blue",
        "--toc",
        "--toc-depth=3",
        f"--metadata=title:Enterprise Cloud Architect Playbook",
        f"--metadata=author:Pushparaj Naik",
    ]

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        if result.returncode == 0:
            size_kb = output_pdf.stat().st_size / 1024
            print(f"✅ PDF generated: {output_pdf} ({size_kb:.0f} KB)")
            return True
        else:
            # Fallback: try without pdflatex (use wkhtmltopdf or basic HTML)
            print(f"⚠️  pdflatex failed, trying HTML-based PDF...")
            return generate_pdf_html_fallback(input_md, output_pdf)
    except subprocess.TimeoutExpired:
        print("❌ PDF generation timed out")
        return False


def generate_pdf_html_fallback(input_md: Path, output_pdf: Path) -> bool:
    """Fallback: Convert MD → HTML → PDF using pandoc's built-in HTML support."""
    html_path = output_pdf.with_suffix(".html")

    # Step 1: MD → HTML with embedded CSS
    cmd_html = [
        "pandoc",
        str(input_md),
        "-o", str(html_path),
        "--standalone",
        "--toc",
        "--toc-depth=3",
        "--css", "",  # Use pandoc default styles
        f"--metadata=title:Enterprise Cloud Architect Playbook",
    ]

    try:
        result = subprocess.run(cmd_html, capture_output=True, text=True, timeout=60)
        if result.returncode == 0:
            print(f"✅ HTML generated: {html_path}")
            # Try wkhtmltopdf if available
            try:
                cmd_pdf = ["wkhtmltopdf", "--quiet", str(html_path), str(output_pdf)]
                result2 = subprocess.run(cmd_pdf, capture_output=True, text=True, timeout=60)
                if result2.returncode == 0:
                    print(f"✅ PDF generated via wkhtmltopdf: {output_pdf}")
                    html_path.unlink(missing_ok=True)
                    return True
            except FileNotFoundError:
                pass

            # If wkhtmltopdf not available, keep the HTML as the deliverable
            print(f"ℹ️  wkhtmltopdf not found — HTML version available at: {html_path}")
            print(f"   The GitHub Actions workflow will generate the PDF automatically.")
            return True
        else:
            print(f"❌ HTML generation failed: {result.stderr[:200]}")
            return False
    except subprocess.TimeoutExpired:
        print("❌ HTML generation timed out")
        return False


# ─── Main ────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Auto-update README.md and generate PDFs")
    parser.add_argument("--generate-pdf", action="store_true", help="Also generate PDF from playbook")
    parser.add_argument("--pdf-only", action="store_true", help="Only generate PDF, skip README update")
    args = parser.parse_args()

    print("=" * 60)
    print("📖 README & PDF Auto-Updater")
    print("=" * 60)

    if not args.pdf_only:
        # Step 1: Discover projects
        projects = discover_projects()
        print(f"\n📂 Discovered {len(projects)} project directories:")
        for p in projects:
            print(f"   {p['emoji']} {p['name']}")

        # Step 2: Update README
        print()
        update_readme(projects)

    if args.generate_pdf or args.pdf_only:
        # Step 3: Generate PDF
        print()
        if PLAYBOOK_PATH.exists():
            pdf_path = PDF_OUTPUT_DIR / "Enterprise_Principal_Cloud_Architect_Playbook.pdf"
            generate_pdf(PLAYBOOK_PATH, pdf_path)
        else:
            print(f"❌ Playbook not found at {PLAYBOOK_PATH}")

    print("\n✅ Done!")


if __name__ == "__main__":
    main()
