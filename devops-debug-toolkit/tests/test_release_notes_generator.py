"""Tests for Tool 9: Release Notes Generator."""

import pytest
from pathlib import Path
from tools.release_notes_generator import ReleaseNotesGenerator


SAMPLE_COMMITS = """\
feat(api): add user authentication endpoint
fix(db): resolve connection pool exhaustion
docs: update README with deployment instructions
feat(ui): implement dark mode toggle
fix: correct timezone handling in scheduler
chore: update dependencies to latest versions
perf(cache): optimize Redis query batching
ci: add automated security scanning to pipeline
BREAKING CHANGE: remove legacy v1 API endpoints
refactor(auth): migrate to JWT from session tokens
"""


class TestReleaseNotesGenerator:

    def test_generates_changelog(self, tmp_path):
        log_file = tmp_path / "commits.log"
        log_file.write_text(SAMPLE_COMMITS)
        gen = ReleaseNotesGenerator()
        output = str(tmp_path / "CHANGELOG.md")
        result = gen.analyze(str(log_file), output=output, version="v2.0.0")
        assert Path(output).exists()
        content = Path(output).read_text()
        assert "v2.0.0" in content

    def test_categorizes_features(self, tmp_path):
        log_file = tmp_path / "commits.log"
        log_file.write_text(SAMPLE_COMMITS)
        gen = ReleaseNotesGenerator()
        output = str(tmp_path / "CHANGELOG.md")
        gen.analyze(str(log_file), output=output)
        content = Path(output).read_text()
        assert "Features" in content

    def test_categorizes_bug_fixes(self, tmp_path):
        log_file = tmp_path / "commits.log"
        log_file.write_text(SAMPLE_COMMITS)
        gen = ReleaseNotesGenerator()
        output = str(tmp_path / "CHANGELOG.md")
        gen.analyze(str(log_file), output=output)
        content = Path(output).read_text()
        assert "Bug Fixes" in content

    def test_detects_breaking_changes(self, tmp_path):
        log_file = tmp_path / "commits.log"
        log_file.write_text(SAMPLE_COMMITS)
        gen = ReleaseNotesGenerator()
        output = str(tmp_path / "CHANGELOG.md")
        result = gen.analyze(str(log_file), output=output)
        content = Path(output).read_text()
        assert "Breaking" in content
        assert result.summary.get("breaking_changes", 0) >= 1

    def test_empty_input(self):
        gen = ReleaseNotesGenerator()
        result = gen.analyze("/nonexistent/repo")
        assert any(f.rule_id == "REL000" for f in result.findings)

    def test_commit_count(self, tmp_path):
        log_file = tmp_path / "commits.log"
        log_file.write_text(SAMPLE_COMMITS)
        gen = ReleaseNotesGenerator()
        output = str(tmp_path / "CHANGELOG.md")
        result = gen.analyze(str(log_file), output=output)
        assert result.summary.get("total_commits", 0) == 10
