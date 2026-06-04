"""Unit tests for Bedrock client."""
from app.services.bedrock_client import BedrockClient
from app.config import Settings


def test_build_messages_no_context():
    settings = Settings()
    client = BedrockClient(settings)
    messages = client._build_messages("Hello")
    assert len(messages) == 1
    assert messages[0]["role"] == "user"
    assert messages[0]["content"] == "Hello"


def test_build_messages_with_context():
    settings = Settings()
    client = BedrockClient(settings)
    context = [{"content": "FAQ answer", "source": "faq.md"}]
    messages = client._build_messages("Question?", context=context)
    assert "Context from knowledge base" in messages[0]["content"]
    assert "FAQ answer" in messages[0]["content"]


def test_build_messages_with_history():
    settings = Settings()
    client = BedrockClient(settings)
    history = [
        {"role": "user", "content": "Hi"},
        {"role": "assistant", "content": "Hello!"},
    ]
    messages = client._build_messages("Follow up", history=history)
    assert len(messages) == 3  # 2 history + 1 new
