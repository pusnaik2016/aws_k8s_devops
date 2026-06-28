"""Unit tests for PII/PAN tokenization utility."""

import pytest
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))
from utils.encryption import PIITokenizer, tokenize_pii


TEST_KEY = "test-encryption-key-32chars-long!"


class TestPIITokenizer:
    """Tests for the PIITokenizer class."""

    def setup_method(self):
        self.tokenizer = PIITokenizer(TEST_KEY)

    def test_tokenize_ssn_format_preserved(self):
        result = self.tokenizer.tokenize_ssn("123-45-6789")
        assert len(result) == 11  # XXX-XX-XXXX
        assert result[3] == "-"
        assert result[6] == "-"
        assert result != "123-45-6789"

    def test_tokenize_ssn_deterministic(self):
        r1 = self.tokenizer.tokenize_ssn("123-45-6789")
        r2 = self.tokenizer.tokenize_ssn("123-45-6789")
        assert r1 == r2

    def test_tokenize_ssn_none_returns_none(self):
        assert self.tokenizer.tokenize_ssn(None) is None

    def test_tokenize_ssn_empty_returns_empty(self):
        assert self.tokenizer.tokenize_ssn("") == ""

    def test_tokenize_pan_last4_visible(self):
        result = self.tokenizer.tokenize_pan("4111-1111-1111-1111")
        assert result.endswith("1111")
        assert result != "4111-1111-1111-1111"

    def test_tokenize_pan_format_preserved(self):
        result = self.tokenizer.tokenize_pan("4111111111111111")
        parts = result.split("-")
        assert len(parts) == 4
        assert len(parts[3]) == 4

    def test_tokenize_email_domain_preserved(self):
        result = self.tokenizer.tokenize_email("user@example.com")
        assert result.endswith("@example.com")
        assert not result.startswith("user@")

    def test_tokenize_email_no_at_sign(self):
        result = self.tokenizer.tokenize_email("invalid-email")
        assert result == "invalid-email"  # Returned as-is

    def test_tokenize_generic(self):
        result = self.tokenizer.tokenize_generic("sensitive-data")
        assert len(result) == len("sensitive-data")
        assert result != "sensitive-data"

    def test_different_keys_produce_different_tokens(self):
        t1 = PIITokenizer("key-one-32chars-abcdefghijklmnop")
        t2 = PIITokenizer("key-two-32chars-abcdefghijklmnop")
        assert t1.tokenize_ssn("123-45-6789") != t2.tokenize_ssn("123-45-6789")

    def test_empty_key_raises(self):
        with pytest.raises(ValueError):
            PIITokenizer("")

    def test_detokenize_not_implemented(self):
        with pytest.raises(NotImplementedError):
            self.tokenizer.detokenize("some-token")


class TestTokenizePII:
    """Tests for the convenience function."""

    def test_tokenize_pii_ssn(self):
        result = tokenize_pii("123-45-6789", "ssn", TEST_KEY)
        assert result != "123-45-6789"
        assert "-" in result

    def test_tokenize_pii_pan(self):
        result = tokenize_pii("4111111111111111", "pan", TEST_KEY)
        assert result.endswith("1111")

    def test_tokenize_pii_email(self):
        result = tokenize_pii("test@company.com", "email", TEST_KEY)
        assert result.endswith("@company.com")
