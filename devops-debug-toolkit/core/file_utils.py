"""File I/O utilities — discovery, parsing, git helpers."""

from __future__ import annotations

import os
import re
import json
import subprocess
from pathlib import Path
from typing import List, Dict, Any, Optional

import yaml


def discover_files(
    root: str | Path,
    extensions: Optional[List[str]] = None,
    exclude_dirs: Optional[List[str]] = None,
) -> List[Path]:
    """Recursively find files matching given extensions."""
    root = Path(root)
    exclude = set(exclude_dirs or [".git", "node_modules", "__pycache__", ".terraform", "venv", ".venv"])
    results = []

    if root.is_file():
        return [root]

    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in exclude]
        for fname in filenames:
            fpath = Path(dirpath) / fname
            if extensions:
                if fpath.suffix in extensions:
                    results.append(fpath)
            else:
                results.append(fpath)
    return sorted(results)


def read_file(path: str | Path) -> str:
    """Read a file and return its content."""
    return Path(path).read_text(encoding="utf-8", errors="replace")


def parse_yaml(path: str | Path) -> Any:
    """Parse a YAML file."""
    content = read_file(path)
    return yaml.safe_load(content)


def parse_json(path: str | Path) -> Any:
    """Parse a JSON file."""
    content = read_file(path)
    return json.loads(content)


def parse_hcl_basic(content: str) -> Dict[str, Any]:
    """Basic HCL parser — extracts resource blocks and key-value pairs.
    This is NOT a full HCL parser, but handles common Terraform patterns.
    """
    resources = []
    # Match resource "type" "name" { ... }
    resource_pattern = re.compile(
        r'resource\s+"([^"]+)"\s+"([^"]+)"\s*\{', re.MULTILINE
    )
    for m in resource_pattern.finditer(content):
        resources.append({
            "type": m.group(1),
            "name": m.group(2),
            "line": content[:m.start()].count("\n") + 1,
        })

    # Extract variables
    variables = []
    var_pattern = re.compile(r'variable\s+"([^"]+)"\s*\{', re.MULTILINE)
    for m in var_pattern.finditer(content):
        variables.append({
            "name": m.group(1),
            "line": content[:m.start()].count("\n") + 1,
        })

    return {"resources": resources, "variables": variables}


def get_git_log(
    repo_path: str | Path,
    max_commits: int = 50,
    since: Optional[str] = None,
) -> List[Dict[str, str]]:
    """Get git log as structured data."""
    repo_path = Path(repo_path)
    cmd = [
        "git", "-C", str(repo_path), "log",
        f"--max-count={max_commits}",
        "--pretty=format:%H|%h|%an|%ae|%ad|%s",
        "--date=iso",
    ]
    if since:
        cmd.append(f"--since={since}")

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        if result.returncode != 0:
            return []
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return []

    commits = []
    for line in result.stdout.strip().split("\n"):
        if not line:
            continue
        parts = line.split("|", 5)
        if len(parts) == 6:
            commits.append({
                "hash": parts[0],
                "short_hash": parts[1],
                "author": parts[2],
                "email": parts[3],
                "date": parts[4],
                "message": parts[5],
            })
    return commits


def get_git_diff(repo_path: str | Path, ref: str = "HEAD~1") -> str:
    """Get git diff output."""
    try:
        result = subprocess.run(
            ["git", "-C", str(repo_path), "diff", ref],
            capture_output=True, text=True, timeout=10,
        )
        return result.stdout
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return ""
