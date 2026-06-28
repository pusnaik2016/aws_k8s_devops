"""Unit tests for the Silver transformation pipeline logic."""

import pytest
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))
from utils.encryption import PIITokenizer


class TestSilverTransformation:
    """Tests verifying Silver layer PII tokenization compliance."""

    def setup_method(self):
        self.key = "test-silver-transform-key-abcdef"
        self.tokenizer = PIITokenizer(self.key)

    def test_ssn_is_tokenized(self):
        """HIPAA: SSN must not appear in cleartext in Silver layer."""
        original = "123-45-6789"
        tokenized = self.tokenizer.tokenize_ssn(original)
        assert tokenized != original
        assert "123" not in tokenized[:3]

    def test_pan_preserves_last4(self):
        """PCI-DSS: Only last 4 digits of PAN may be visible."""
        original = "4111111111111111"
        tokenized = self.tokenizer.tokenize_pan(original)
        assert tokenized.endswith("1111")
        # First 12 digits must be different
        assert "411111111111" not in tokenized

    def test_email_tokenization_preserves_domain(self):
        """HIPAA: Email local part tokenized, domain preserved for routing."""
        original = "patient@hospital.org"
        tokenized = self.tokenizer.tokenize_email(original)
        assert tokenized.endswith("@hospital.org")
        assert not tokenized.startswith("patient@")

    def test_mrn_is_fully_tokenized(self):
        """HIPAA: Medical Record Numbers must be fully tokenized."""
        original = "MRN-12345678"
        tokenized = self.tokenizer.tokenize_generic(original)
        assert tokenized != original
        assert len(tokenized) == len(original)

    def test_tokenization_is_consistent(self):
        """Same input always produces same token (deterministic for joins)."""
        t1 = self.tokenizer.tokenize_ssn("999-88-7777")
        t2 = self.tokenizer.tokenize_ssn("999-88-7777")
        assert t1 == t2

    def test_different_inputs_produce_different_tokens(self):
        """Different PII values must produce different tokens."""
        t1 = self.tokenizer.tokenize_ssn("111-22-3333")
        t2 = self.tokenizer.tokenize_ssn("444-55-6666")
        assert t1 != t2
