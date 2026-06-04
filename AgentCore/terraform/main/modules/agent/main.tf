# ══════════════════════════════════════════════════════════════════════════════
# Module: agent
# Bedrock Agent with SESSION_SUMMARY memory, Knowledge Base association,
# and MemoryActions action group for long-term memory writes.
# ══════════════════════════════════════════════════════════════════════════════

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

# ── IAM Role for Bedrock Agent ───────────────────────────────────────────────

data "aws_iam_policy_document" "agent_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["bedrock.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

resource "aws_iam_role" "agent" {
  name               = "${var.name}-agent-role"
  assume_role_policy = data.aws_iam_policy_document.agent_assume.json

  tags = { Name = "${var.name}-agent-role" }
}

resource "aws_iam_role_policy" "agent_bedrock" {
  name = "${var.name}-agent-bedrock"
  role = aws_iam_role.agent.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = "arn:aws:bedrock:${local.region}::foundation-model/${var.foundation_model}"
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:Retrieve",
          "bedrock:RetrieveAndGenerate"
        ]
        Resource = var.knowledge_base_arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "agent_lambda" {
  name = "${var.name}-agent-lambda"
  role = aws_iam_role.agent.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = var.memory_writer_lambda_arn
      }
    ]
  })
}

# ── Agent Instruction ────────────────────────────────────────────────────────

locals {
  agent_instruction = <<-EOT
    You are a helpful AI assistant with a 3-layer memory system.

    MEMORY ARCHITECTURE:
    - Layer 1 (In-Context): You can see the last few turns of this conversation.
    - Layer 2 (Session Summary): Bedrock automatically maintains a rolling summary of this session.
    - Layer 3 (Long-Term Knowledge Base): Facts saved across all sessions, searchable via semantic search.

    RETRIEVAL RULES — always search the knowledge base BEFORE answering when:
    - The user asks about their preferences, history, or past decisions
    - The user asks "what do you know about me" or "from long-term memory"
    - The user asks about their AWS region, tech stack, or project context
    - Any question that could be answered by previously saved facts

    SAVE RULES — call save_to_long_term_memory when:
    - User states a preference ("I always prefer X over Y")
    - User shares a fact about their project or context
    - A decision was made that will affect future sessions
    - Confidence should be 0.0-1.0 (only facts >= 0.7 are persisted)

    RESPONSE RULES:
    - Always confirm saves: "I've saved [fact] to your long-term memory."
    - Always cite retrievals: "Based on your long-term memory, [fact]."
    - If the knowledge base returns no results, say so honestly.
    - Never fabricate memories that don't exist in your knowledge base.
  EOT
}

# ── Bedrock Agent ────────────────────────────────────────────────────────────

resource "aws_bedrockagent_agent" "this" {
  agent_name              = var.name
  agent_resource_role_arn = aws_iam_role.agent.arn
  foundation_model        = var.foundation_model
  instruction             = local.agent_instruction
  idle_session_ttl_in_seconds = 600

  memory_configuration {
    enabled_memory_types = ["SESSION_SUMMARY"]
    storage_days         = var.session_summary_retention_days
  }

  tags = { Name = var.name }
}

# ── Knowledge Base Association ───────────────────────────────────────────────

resource "aws_bedrockagent_agent_knowledge_base_association" "this" {
  agent_id             = aws_bedrockagent_agent.this.agent_id
  knowledge_base_id    = var.knowledge_base_id
  description          = "Long-term memory store for user preferences, decisions, and project context"
  knowledge_base_state = "ENABLED"
}

# ── Action Group: MemoryActions ──────────────────────────────────────────────

resource "aws_bedrockagent_agent_action_group" "memory_actions" {
  agent_id                    = aws_bedrockagent_agent.this.agent_id
  action_group_name           = "MemoryActions"
  action_group_executor {
    lambda = var.memory_writer_lambda_arn
  }

  function_schema {
    member_functions {
      functions {
        name        = "save_to_long_term_memory"
        description = "Saves an important fact, preference, or decision to long-term memory so it can be retrieved in future sessions"

        parameters {
          map_block_key = "fact"
          type          = "string"
          description   = "The fact, preference, or decision to save"
          required      = true
        }

        parameters {
          map_block_key = "category"
          type          = "string"
          description   = "Category: preference | project_context | decision | user_profile"
          required      = true
        }

        parameters {
          map_block_key = "confidence"
          type          = "number"
          description   = "Confidence score 0.0-1.0 that this fact is worth persisting (only >= 0.7 are saved)"
          required      = true
        }
      }
    }
  }
}

# ── Lambda Permission (allow Bedrock to invoke) ─────────────────────────────

resource "aws_lambda_permission" "bedrock_invoke" {
  statement_id  = "AllowBedrockInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.memory_writer_lambda_name
  principal     = "bedrock.amazonaws.com"
  source_arn    = aws_bedrockagent_agent.this.agent_arn
}

# ── Agent Alias ──────────────────────────────────────────────────────────────

resource "aws_bedrockagent_agent_alias" "live" {
  agent_id         = aws_bedrockagent_agent.this.agent_id
  agent_alias_name = "live"
  description      = "Live alias for the AgentCore Memory agent"

  tags = { Name = "${var.name}-live" }
}
