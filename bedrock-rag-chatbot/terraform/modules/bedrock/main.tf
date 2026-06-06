# -----------------------------------------------------------------------------
# Bedrock Guardrails — Content filtering, PII protection, topic denial
# -----------------------------------------------------------------------------

resource "aws_bedrock_guardrail" "main" {
  name                      = "${var.project_name}-guardrail"
  blocked_input_messaging   = "Your request was blocked by our safety filters. Please rephrase your question."
  blocked_outputs_messaging = "The response was blocked by our safety filters. Please try a different question."
  description               = "Enterprise guardrails for RAG chatbot — prevents PII leakage, harmful content, and off-topic queries"

  # Content filtering — block harmful content
  content_policy_config {
    filters_config {
      type            = "SEXUAL"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "VIOLENCE"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "HATE"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "INSULTS"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "MISCONDUCT"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "PROMPT_ATTACK"
      input_strength  = "HIGH"
      output_strength = "NONE"
    }
  }

  # PII — Detect and redact sensitive information
  sensitive_information_policy_config {
    pii_entities_config {
      type   = "EMAIL"
      action = "ANONYMIZE"
    }
    pii_entities_config {
      type   = "PHONE"
      action = "ANONYMIZE"
    }
    pii_entities_config {
      type   = "US_SOCIAL_SECURITY_NUMBER"
      action = "BLOCK"
    }
    pii_entities_config {
      type   = "CREDIT_DEBIT_CARD_NUMBER"
      action = "BLOCK"
    }
  }

  # Topic denial — block off-topic queries
  topic_policy_config {
    topics_config {
      name       = "CompetitorInformation"
      definition = "Questions about competitor products, pricing, or strategies"
      type       = "DENY"
      examples   = ["What does competitor X charge?", "How does competitor Y's product work?"]
    }
    topics_config {
      name       = "InternalFinancials"
      definition = "Questions about internal financial data, revenue, or employee compensation"
      type       = "DENY"
      examples   = ["What is the company revenue?", "How much does the CEO earn?"]
    }
  }

  tags = {
    Name = "${var.project_name}-guardrail"
  }
}

resource "aws_bedrock_guardrail_version" "main" {
  guardrail_arn = aws_bedrock_guardrail.main.guardrail_arn
  description   = "Initial version"
}
