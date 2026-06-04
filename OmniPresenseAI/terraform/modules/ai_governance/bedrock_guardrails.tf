# ─────────────────────────────────────────────────────────────
# Amazon Bedrock Guardrails — Responsible AI
# ─────────────────────────────────────────────────────────────
# AI Lens: Content filtering, PII redaction, topic blocking
# Compliance: HIPAA (PHI redaction), GDPR (PII protection)
# ─────────────────────────────────────────────────────────────

resource "aws_bedrock_guardrail" "main" {
  name                      = "${var.project_name}-${var.environment}-guardrail"
  description               = "Content safety and PII protection guardrail for OmniPresenseAI"
  blocked_input_messaging   = "I'm sorry, I cannot process that request. Please rephrase your question about our products or services."
  blocked_outputs_messaging = "I apologize, but I'm unable to provide that type of response. Let me help you with something else."

  # ─── Content Filters (harmful content blocking) ────────────
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
      input_strength  = "MEDIUM"
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

  # ─── Topic Policy (block off-topic requests) ──────────────
  topic_policy_config {
    topics_config {
      name       = "financial-advice"
      definition = "Providing specific financial advice, investment recommendations, or tax guidance"
      type       = "DENY"
      examples   = [
        "What stock should I buy?",
        "How should I invest my money?",
        "Can you give me tax advice?"
      ]
    }
    topics_config {
      name       = "medical-diagnosis"
      definition = "Providing medical diagnoses, treatment recommendations, or prescriptions"
      type       = "DENY"
      examples   = [
        "What medicine should I take?",
        "Can you diagnose my symptoms?",
        "Is this a serious condition?"
      ]
    }
    topics_config {
      name       = "legal-advice"
      definition = "Providing specific legal counsel or opinions"
      type       = "DENY"
      examples   = [
        "Can I sue for this?",
        "What are my legal rights?",
        "Draft a legal contract for me"
      ]
    }
  }

  # ─── Sensitive Information Filters (PII/PHI) ──────────────
  sensitive_information_policy_config {
    # PII entities to redact (GDPR + HIPAA)
    pii_entities_config {
      type   = "EMAIL"
      action = "ANONYMIZE"
    }
    pii_entities_config {
      type   = "PHONE"
      action = "ANONYMIZE"
    }
    pii_entities_config {
      type   = "NAME"
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
    pii_entities_config {
      type   = "US_BANK_ACCOUNT_NUMBER"
      action = "BLOCK"
    }
    pii_entities_config {
      type   = "IP_ADDRESS"
      action = "ANONYMIZE"
    }
    pii_entities_config {
      type   = "AWS_ACCESS_KEY"
      action = "BLOCK"
    }
    pii_entities_config {
      type   = "AWS_SECRET_KEY"
      action = "BLOCK"
    }

    # Custom regex patterns
    regexes_config {
      name        = "medical-record-number"
      description = "HIPAA — Medical Record Number pattern"
      pattern     = "MRN[\\s:-]*\\d{6,10}"
      action      = "BLOCK"
    }
    regexes_config {
      name        = "passport-number"
      description = "Passport number pattern"
      pattern     = "[A-Z]{1,2}\\d{6,9}"
      action      = "ANONYMIZE"
    }
  }

  # ─── Word Filters ─────────────────────────────────────────
  word_policy_config {
    managed_word_lists_config {
      type = "PROFANITY"
    }
    words_config {
      text = "competitor-name-1"
    }
    words_config {
      text = "competitor-name-2"
    }
  }

  tags = merge(var.tags, {
    Name       = "${var.project_name}-${var.environment}-guardrail"
    Compliance = "HIPAA,GDPR,PCI-DSS"
    AILens     = "Responsible-AI"
  })
}

# Create a versioned snapshot of the guardrail
resource "aws_bedrock_guardrail_version" "v1" {
  guardrail_arn = aws_bedrock_guardrail.main.guardrail_arn
  description   = "Initial production guardrail version"
}
