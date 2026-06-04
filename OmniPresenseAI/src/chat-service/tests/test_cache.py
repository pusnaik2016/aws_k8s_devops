"""Unit tests for cache key generation."""
from app.routes.chat import _generate_cache_key


def test_cache_key_deterministic():
    key1 = _generate_cache_key("Hello world")
    key2 = _generate_cache_key("Hello world")
    assert key1 == key2


def test_cache_key_case_insensitive():
    key1 = _generate_cache_key("Hello")
    key2 = _generate_cache_key("hello")
    assert key1 == key2


def test_cache_key_strips_whitespace():
    key1 = _generate_cache_key("  hello  ")
    key2 = _generate_cache_key("hello")
    assert key1 == key2
