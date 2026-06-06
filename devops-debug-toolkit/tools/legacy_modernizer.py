"""Tool 6: Legacy Code Modernizer — Detect anti-patterns and suggest modernization."""

from __future__ import annotations

import re
from pathlib import Path

from core.analyzer import BaseAnalyzer, AnalysisResult, Severity, Category
from core.file_utils import discover_files, read_file


LEGACY_PATTERNS = [
    # Python 2 patterns
    ("PY2-PRINT", r'\bprint\s+["\']', "Python 2 print statement",
     Severity.MEDIUM, "Use print() function (Python 3).", "Replace `print \"text\"` with `print(\"text\")`"),
    ("PY2-URLLIB", r'from\s+urllib\s+import', "Python 2 urllib import",
     Severity.MEDIUM, "Use urllib.request (Python 3) or the requests library.", "Replace with `import requests` or `from urllib.request import urlopen`"),
    ("PY2-RAWSTR", r'(?<!\w)unicode\s*\(', "Python 2 unicode() call",
     Severity.LOW, "unicode() doesn't exist in Python 3.", "Remove unicode() calls; all strings are unicode in Python 3."),

    # Security anti-patterns
    ("SEC-EVAL", r'\beval\s*\(', "Use of eval() — arbitrary code execution",
     Severity.CRITICAL, "eval() executes arbitrary code. Major security risk.", "Use ast.literal_eval() for safe parsing, or JSON for data exchange."),
    ("SEC-PICKLE", r'\bpickle\.(?:loads?|dump)\s*\(', "Insecure pickle deserialization",
     Severity.HIGH, "pickle.load() can execute arbitrary code from untrusted data.", "Use JSON, MessagePack, or protobuf for serialization."),
    ("SEC-SHELL", r'\bos\.system\s*\(', "Shell command via os.system()",
     Severity.HIGH, "os.system() is vulnerable to shell injection.", "Use subprocess.run() with shell=False and a list of arguments."),
    ("SEC-SHELL2", r'subprocess\.\w+\(.*shell\s*=\s*True', "subprocess with shell=True",
     Severity.HIGH, "shell=True enables shell injection attacks.", "Use subprocess.run(['cmd', 'arg1'], shell=False)."),
    ("SEC-HARDCRED", r'(?i)(?:password|secret|api_key|db_pass|passwd|token)\s*=\s*["\'][^"\']{6,}["\']', "Hardcoded credentials",
     Severity.CRITICAL, "Credentials hardcoded in source code.", "Use environment variables or a secrets manager."),

    # Code quality
    ("QUAL-BARE-EXCEPT", r'\bexcept\s*:', "Bare except clause",
     Severity.MEDIUM, "Catches all exceptions including SystemExit and KeyboardInterrupt.", "Catch specific exceptions: except ValueError, except OSError."),
    ("QUAL-PASS-EXCEPT", r'except.*:\s*\n\s*pass\b', "Silenced exception (except: pass)",
     Severity.MEDIUM, "Exception silently ignored. Hides bugs.", "Log the exception or handle it appropriately."),
    ("QUAL-NO-CTX", r'\w+\s*=\s*open\s*\(', "File open without context manager",
     Severity.LOW, "File opened without `with` statement. May leak file handles.", "Use `with open(filename) as f:` pattern."),
    ("QUAL-MUTABLE-DEFAULT", r'def\s+\w+\s*\([^)]*=\s*(?:\[\]|\{\})\s*[,)]', "Mutable default argument",
     Severity.LOW, "Mutable default arguments are shared across calls.", "Use `None` as default and create inside function."),
    ("QUAL-TYPE-CHECK", r'type\s*\(\s*\w+\s*\)\s*==\s*type\s*\(', "Type checking with type()",
     Severity.LOW, "Using type() for type checking is fragile.", "Use isinstance() instead."),

    # Deprecated patterns
    ("DEP-PERCENT-FMT", r'%\s*\(', "Old-style % string formatting",
     Severity.LOW, "%-formatting is legacy. Less readable than f-strings.", "Use f-strings: f\"Hello {name}\" or str.format()."),
    ("DEP-RANGE-LIST", r'\brange\s*\(\s*\d{5,}', "Large range() call (Python 2 creates list)",
     Severity.LOW, "In Python 2, range() creates a full list in memory.", "Use range() in Python 3 (lazy iterator) or xrange() in Python 2."),
]

SHELL_PATTERNS = [
    ("SH-BACKTICK", r'`[^`]+`', "Backtick command substitution",
     Severity.LOW, "Backticks are deprecated in modern shell.", "Use $(command) instead of `command`."),
    ("SH-NOQUOTE", r'\$\w+(?!\w|["\'])', "Unquoted variable expansion",
     Severity.MEDIUM, "Unquoted variable may cause word splitting or globbing.", 'Quote variables: "$VAR" instead of $VAR.'),
    ("SH-NOEXIT", r'^(?!.*set -e).*#!/bin/(?:bash|sh)', "Missing set -e (exit on error)",
     Severity.MEDIUM, "Script doesn't exit on first error. Failures may go unnoticed.", "Add 'set -euo pipefail' at the top."),
]


class LegacyModernizer(BaseAnalyzer):
    """Analyze code for legacy patterns and suggest modernization."""

    name = "Legacy Code Modernizer"
    version = "1.0.0"

    def analyze(self, target: str, **kwargs) -> AnalysisResult:
        """Analyze code for legacy/anti-patterns."""
        target_path = Path(target)
        extensions = kwargs.get("extensions", [".py", ".sh", ".bash"])

        files = discover_files(target_path, extensions=extensions)
        if not files:
            if target_path.is_file():
                files = [target_path]
            else:
                self._add_finding(
                    "MOD000", Severity.INFO, Category.MODERNIZATION,
                    "No source files found", f"No matching files in {target}",
                )
                return self._build_result(target)

        files_scanned = 0
        for fpath in files:
            content = read_file(fpath)
            rel_path = str(fpath.name) if target_path.is_dir() else fpath.name
            is_python = fpath.suffix in (".py",)
            is_shell = fpath.suffix in (".sh", ".bash")

            patterns = LEGACY_PATTERNS if is_python else SHELL_PATTERNS if is_shell else LEGACY_PATTERNS
            files_scanned += 1

            for rule_id, pattern, title, severity, message, recommendation in patterns:
                matches = list(re.finditer(pattern, content, re.MULTILINE))
                if matches:
                    line_num = content[:matches[0].start()].count("\n") + 1
                    self._add_finding(
                        rule_id, severity, Category.MODERNIZATION,
                        f"{title} ({len(matches)} found)",
                        message,
                        location=rel_path,
                        line_number=line_num,
                        recommendation=recommendation,
                        occurrences=len(matches),
                    )

        return self._build_result(
            target,
            files_scanned=files_scanned,
            patterns_checked=len(LEGACY_PATTERNS) + len(SHELL_PATTERNS),
        )
