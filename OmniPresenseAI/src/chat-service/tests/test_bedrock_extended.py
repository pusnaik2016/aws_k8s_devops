"""Extended unit tests for Bedrock client — edge cases and security."""
import pytest
from app.services.bedrock_client import BedrockClient
from app.config import Settings


@pytest.fixture
def client():
    return BedrockClient(Settings())


class TestBuildMessages:
    """Test message building logic used in RAG pipeline."""

    def test_empty_message(self, client):
        messages = client._build_messages("")
        assert len(messages) == 1
        assert messages[0]["content"] == ""

    def test_long_message(self, client):
        long_msg = "x" * 10000
        messages = client._build_messages(long_msg)
        assert messages[0]["content"] == long_msg

    def test_special_characters(self, client):
        special = "Hello <script>alert('xss')</script>"
        messages = client._build_messages(special)
        assert messages[0]["content"] == special

    def test_unicode_message(self, client):
        unicode_msg = "こんにちは 你好 مرحبا"
        messages = client._build_messages(unicode_msg)
        assert messages[0]["content"] == unicode_msg

    def test_context_includes_source(self, client):
        context = [{"content": "Answer text", "source": "faq.md"}]
        messages = client._build_messages("Question?", context=context)
        assert "faq.md" in messages[-1]["content"]

    def test_context_multiple_docs(self, client):
        context = [
            {"content": "Doc 1 content", "source": "doc1.md"},
            {"content": "Doc 2 content", "source": "doc2.md"},
            {"content": "Doc 3 content", "source": "doc3.md"},
        ]
        messages = client._build_messages("Question?", context=context)
        content = messages[-1]["content"]
        assert "Doc 1 content" in content
        assert "Doc 2 content" in content
        assert "Doc 3 content" in content

    def test_context_missing_source_key(self, client):
        context = [{"content": "Some content"}]
        messages = client._build_messages("Q?", context=context)
        assert "Knowledge Base" in messages[-1]["content"]

    def test_history_ordering(self, client):
        history = [
            {"role": "user", "content": "First"},
            {"role": "assistant", "content": "Response 1"},
            {"role": "user", "content": "Second"},
            {"role": "assistant", "content": "Response 2"},
        ]
        messages = client._build_messages("Third", history=history)
        assert messages[0]["role"] == "user"
        assert messages[0]["content"] == "First"
        assert messages[-1]["role"] == "user"
        assert "Third" in messages[-1]["content"]

    def test_history_truncation(self, client):
        """History should be truncated to last 10 messages."""
        history = [
            {"role": "user" if i % 2 == 0 else "assistant", "content": f"msg-{i}"}
            for i in range(20)
        ]
        messages = client._build_messages("New msg", history=history)
        # 10 history + 1 new = 11
        assert len(messages) == 11

    def test_context_and_history_combined(self, client):
        history = [{"role": "user", "content": "Hi"}]
        context = [{"content": "KB info", "source": "kb.md"}]
        messages = client._build_messages("Q?", context=context, history=history)
        # History first, then context+question
        assert messages[0]["content"] == "Hi"
        assert "KB info" in messages[-1]["content"]

    def test_none_context_and_history(self, client):
        messages = client._build_messages("Hello", context=None, history=None)
        assert len(messages) == 1

    def test_empty_context_list(self, client):
        messages = client._build_messages("Hello", context=[])
        assert len(messages) == 1
        assert messages[0]["content"] == "Hello"


class TestBedrockClientInit:
    """Test client initialization."""

    def test_model_id_set(self, client):
        assert client.model_id is not None
        assert len(client.model_id) > 0

    def test_embedding_model_set(self, client):
        assert client.embedding_model_id is not None

    def test_boto3_client_created(self, client):
        assert client.client is not None
