"""Tool 4: Incident Triage Analyzer — Analyze logs for root cause analysis."""

from __future__ import annotations

import re
from pathlib import Path
from typing import List, Tuple
from collections import Counter

from core.analyzer import BaseAnalyzer, AnalysisResult, Severity, Category
from core.file_utils import read_file


# Known error patterns with severity and probable cause
ERROR_PATTERNS = [
    (r"(?i)java\.lang\.OutOfMemoryError|MemoryError|OOMKilled|Cannot allocate memory",
     "Out of Memory", Severity.CRITICAL, "Memory exhaustion detected. Application or container exceeded memory limits.",
     "Increase memory limits, investigate memory leaks (heap dump for Java), or optimize memory usage."),

    (r"(?i)Connection\s*(?:refused|timed?\s*out|reset)|ECONNREFUSED|ECONNRESET|ETIMEDOUT",
     "Connection Failure", Severity.HIGH, "Service connectivity issues detected. Downstream dependency may be unavailable.",
     "Check target service health, network policies, security groups, and DNS resolution."),

    (r"(?i)(?:5\d{2}\s+(?:Internal Server|Bad Gateway|Service Unavailable|Gateway Timeout))|HTTP\s+5\d{2}",
     "HTTP 5xx Errors", Severity.HIGH, "Server-side errors detected. Application or upstream proxy returning errors.",
     "Check application logs for stack traces, verify upstream services, check resource utilization."),

    (r"(?i)disk\s*(?:full|space)|No space left on device|ENOSPC",
     "Disk Space Exhaustion", Severity.CRITICAL, "Disk space exhausted. Application may fail to write data.",
     "Clean up old files/logs, increase volume size, add log rotation."),

    (r"(?i)(?:Traceback|Exception|Error|FATAL)[\s\S]{0,500}(?:at\s+\S+|File\s+\"[^\"]+\")",
     "Application Exception", Severity.HIGH, "Application exception or stack trace detected.",
     "Review the stack trace, identify the failing function, check recent code changes."),

    (r"(?i)(?:authentication|auth)\s*(?:failed|error|denied)|401\s+Unauthorized|invalid\s*(?:token|credential)",
     "Authentication Failure", Severity.HIGH, "Authentication failures detected. Credentials may be expired or invalid.",
     "Rotate credentials, check token expiration, verify IAM roles and permissions."),

    (r"(?i)(?:deadlock|lock\s+wait\s+timeout|Lock\s+not\s+available)",
     "Database Deadlock", Severity.HIGH, "Database deadlock or lock contention detected.",
     "Review concurrent transactions, optimize queries, increase lock timeout."),

    (r"(?i)(?:slow\s+query|query\s+took\s+\d+\s*(?:ms|s)|execution\s+time\s*:\s*\d{4,})",
     "Slow Queries", Severity.MEDIUM, "Slow database queries detected. May cause latency spikes.",
     "Add missing indexes, optimize query plans, consider read replicas for read-heavy workloads."),

    (r"(?i)(?:rate\s*limit|throttl|too\s+many\s+requests|429)",
     "Rate Limiting", Severity.MEDIUM, "API rate limiting or throttling detected.",
     "Implement exponential backoff, request quota increase, or optimize API call patterns."),

    (r"(?i)(?:certificate\s*(?:expired|invalid|error)|x509|SSL_ERROR|TLS\s+handshake)",
     "TLS/Certificate Error", Severity.HIGH, "TLS/SSL certificate issue detected.",
     "Renew expired certificates, verify certificate chain, check CA trust store."),
]


class IncidentTriage(BaseAnalyzer):
    """Analyze application/system logs for incident triage and root cause analysis."""

    name = "Incident Triage Analyzer"
    version = "1.0.0"

    def analyze(self, target: str, **kwargs) -> AnalysisResult:
        """Analyze log files for incident triage."""
        target_path = Path(target)

        if not target_path.exists():
            self._add_finding(
                "INC000", Severity.CRITICAL, Category.INCIDENT,
                "Log file not found", f"File not found: {target}",
                recommendation="Provide a valid log file or directory."
            )
            return self._build_result(target)

        if target_path.is_file():
            log_files = [target_path]
        else:
            log_files = sorted(target_path.glob("**/*.log")) + sorted(target_path.glob("**/*.txt"))

        if not log_files:
            self._add_finding(
                "INC001", Severity.INFO, Category.INCIDENT,
                "No log files found", f"No .log or .txt files found in {target}",
            )
            return self._build_result(target)

        all_errors: List[Tuple[str, int]] = []
        total_lines = 0

        for log_file in log_files:
            content = read_file(log_file)
            lines = content.split("\n")
            total_lines += len(lines)
            rel_path = str(log_file.name)

            for pattern, title, severity, message, recommendation in ERROR_PATTERNS:
                matches = list(re.finditer(pattern, content, re.MULTILINE))
                if matches:
                    # Report first occurrence with count
                    first_match = matches[0]
                    line_num = content[:first_match.start()].count("\n") + 1
                    self._add_finding(
                        f"INC-{title[:3].upper()}", severity, Category.INCIDENT,
                        f"{title} ({len(matches)} occurrences)",
                        f"{message} Found {len(matches)} occurrence(s) in {rel_path}.",
                        location=rel_path,
                        line_number=line_num,
                        recommendation=recommendation,
                        occurrences=len(matches),
                        sample=first_match.group(0).strip()[:200],
                    )
                    all_errors.extend([(title, 1)] * len(matches))

        # Build error frequency summary
        error_freq = Counter(e[0] for e in all_errors)

        # Generate timeline (simple)
        if not all_errors:
            self._add_finding(
                "INC099", Severity.INFO, Category.INCIDENT,
                "No known error patterns detected",
                "Log files analyzed but no known error patterns were found.",
                recommendation="If issues persist, check application-specific error codes."
            )

        return self._build_result(
            target,
            files_analyzed=len(log_files),
            total_lines=total_lines,
            total_errors=len(all_errors),
            error_frequency=dict(error_freq.most_common()),
        )
