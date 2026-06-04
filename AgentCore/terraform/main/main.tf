# ══════════════════════════════════════════════════════════════════════════════
# AgentCore Memory — Root Module
# Wires together all 5 infrastructure modules.
# Deploy: terraform apply -var='aurora_master_password=<your-password>'
# ══════════════════════════════════════════════════════════════════════════════

# ── Module 1: Aurora pgvector ────────────────────────────────────────────────

module "aurora" {
  source = "./modules/aurora-pgvector"

  name            = var.name
  master_password = var.aurora_master_password
  min_capacity    = var.aurora_min_capacity
  max_capacity    = var.aurora_max_capacity
}

# ── Module 2: Knowledge Base ─────────────────────────────────────────────────

module "knowledge_base" {
  source = "./modules/knowledge-base"

  name                 = var.name
  aurora_cluster_arn   = module.aurora.cluster_arn
  aurora_secret_arn    = module.aurora.secret_arn
  aurora_database_name = module.aurora.database_name
}

# ── Module 3: Session Memory (Lambda + DynamoDB + SQS) ───────────────────────

module "session_memory" {
  source = "./modules/session-memory"

  name               = var.name
  memory_bucket_name = module.knowledge_base.memory_bucket_name
  memory_bucket_arn  = module.knowledge_base.memory_bucket_arn
  knowledge_base_id  = module.knowledge_base.knowledge_base_id
  knowledge_base_arn = module.knowledge_base.knowledge_base_arn
  data_source_id     = module.knowledge_base.data_source_id
  lambda_source_dir  = "${path.root}/../../src/lambda/memory_writer"
  confidence_threshold = var.confidence_threshold
}

# ── Module 4: Bedrock Agent ──────────────────────────────────────────────────

module "agent" {
  source = "./modules/agent"

  name                      = var.name
  foundation_model          = var.foundation_model
  knowledge_base_id         = module.knowledge_base.knowledge_base_id
  knowledge_base_arn        = module.knowledge_base.knowledge_base_arn
  memory_writer_lambda_arn  = module.session_memory.lambda_function_arn
  memory_writer_lambda_name = module.session_memory.lambda_function_name
}

# ── Module 5: Observability ──────────────────────────────────────────────────

module "observability" {
  source = "./modules/observability"

  name                        = var.name
  aws_region                  = var.aws_region
  memory_writer_function_name = module.session_memory.lambda_function_name
  lambda_log_group_name       = module.session_memory.log_group_name
  sqs_queue_name              = "${var.name}-memory-queue"
  dlq_name                    = "${var.name}-memory-dlq"
}
