"""
PII/PAN Tokenization — Format-Preserving Encryption Utility
=============================================================
HIPAA: Tokenizes ePHI fields (SSN, MRN, DOB)
PCI-DSS: Format-preserving encryption for PAN (cardholder data)

Uses HMAC-SHA256 for deterministic tokenization.
For production NIST-certified compliance, integrate FF3-1 (pyffx or BPS).
"""

import hashlib
import hmac
from typing import Optional


class PIITokenizer:
    """Format-preserving tokenizer for PII and PAN data."""

    def __init__(self, encryption_key: str):
        if not encryption_key:
            raise ValueError("Encryption key cannot be empty")
        self._key = encryption_key.encode("utf-8")

    def _hmac_token(self, value: str) -> str:
        """Generate deterministic HMAC-SHA256 token."""
        return hmac.new(self._key, value.encode("utf-8"), hashlib.sha256).hexdigest()

    def tokenize_ssn(self, ssn: Optional[str]) -> Optional[str]:
        """Tokenize SSN preserving XXX-XX-XXXX format."""
        if not ssn or not ssn.strip():
            return ssn
        token = self._hmac_token(ssn.replace("-", ""))
        return f"{token[:3]}-{token[3:5]}-{token[5:9]}"

    def tokenize_pan(self, pan: Optional[str]) -> Optional[str]:
        """Tokenize PAN preserving format, keeping last 4 digits visible."""
        if not pan or not pan.strip():
            return pan
        clean = pan.replace("-", "").replace(" ", "")
        token = self._hmac_token(clean)
        last4 = clean[-4:]
        return f"{token[:4]}-{token[4:8]}-{token[8:12]}-{last4}"

    def tokenize_email(self, email: Optional[str]) -> Optional[str]:
        """Tokenize email local part, preserve domain."""
        if not email or "@" not in email:
            return email
        local, domain = email.rsplit("@", 1)
        token = self._hmac_token(local)
        return f"{token[:8]}@{domain}"

    def tokenize_generic(self, value: Optional[str]) -> Optional[str]:
        """Generic tokenization preserving string length."""
        if not value or not value.strip():
            return value
        token = self._hmac_token(value)
        return token[:len(value)]

    def detokenize(self, token: str) -> str:
        """Detokenization requires lookup table — not implemented in HMAC mode."""
        raise NotImplementedError(
            "HMAC-based tokenization is one-way. "
            "For reversible tokenization, implement FF3-1 with a token vault."
        )


def tokenize_pii(value: str, field_type: str, key: str) -> str:
    """Convenience function for PySpark UDF usage."""
    tokenizer = PIITokenizer(key)
    method = {
        "ssn": tokenizer.tokenize_ssn,
        "pan": tokenizer.tokenize_pan,
        "email": tokenizer.tokenize_email,
    }.get(field_type, tokenizer.tokenize_generic)
    return method(value)


def detokenize_pii(token: str, field_type: str, key: str) -> str:
    """Detokenization stub — requires FF3-1 implementation."""
    raise NotImplementedError("Requires FF3-1 token vault for reversible detokenization")
