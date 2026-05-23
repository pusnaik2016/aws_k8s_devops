terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "bedrock-rag-terraform-state"
    key            = "enterprise-rag/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "Pushparaj Naik"
    }
  }
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# KMS Key — Shared encryption key for all resources
# -----------------------------------------------------------------------------
resource "aws_kms_key" "main" {
  description             = "${var.project_name} encryption key"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccountFullAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowLambdaUsage"
        Effect = "Allow"
        Principal = {
          AWS = module.iam.lambda_role_arn
        }
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "main" {
  name          = "alias/${var.project_name}"
  target_key_id = aws_kms_key.main.key_id
}

# -----------------------------------------------------------------------------
# Modules
# -----------------------------------------------------------------------------
module "networking" {
  source = "./modules/networking"

  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
  aws_region   = var.aws_region
}

module "s3" {
  source = "./modules/s3"

  project_name = var.project_name
  environment  = var.environment
  kms_key_arn  = aws_kms_key.main.arn
}

module "opensearch" {
  source = "./modules/opensearch"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.networking.vpc_id
  subnet_ids   = module.networking.private_subnet_ids
  sg_id        = module.networking.opensearch_sg_id
}

module "iam" {
  source = "./modules/iam"

  project_name         = var.project_name
  environment          = var.environment
  aws_region           = var.aws_region
  account_id           = data.aws_caller_identity.current.account_id
  s3_bucket_arn        = module.s3.bucket_arn
  opensearch_arn       = module.opensearch.collection_arn
  kms_key_arn          = aws_kms_key.main.arn
  bedrock_model_id     = var.bedrock_model_id
  embedding_model_id   = var.embedding_model_id
}

module "lambda" {
  source = "./modules/lambda"

  project_name          = var.project_name
  environment           = var.environment
  lambda_role_arn       = module.iam.lambda_role_arn
  private_subnet_ids    = module.networking.private_subnet_ids
  lambda_sg_id          = module.networking.lambda_sg_id
  s3_bucket_name        = module.s3.bucket_name
  opensearch_endpoint   = module.opensearch.collection_endpoint
  bedrock_model_id      = var.bedrock_model_id
  embedding_model_id    = var.embedding_model_id
  kms_key_arn           = aws_kms_key.main.arn
}

module "api_gateway" {
  source = "./modules/api_gateway"

  project_name     = var.project_name
  environment      = var.environment
  chat_lambda_arn  = module.lambda.chat_function_arn
  chat_lambda_name = module.lambda.chat_function_name
  aws_region       = var.aws_region
  account_id       = data.aws_caller_identity.current.account_id
}

module "bedrock_guardrails" {
  source = "./modules/bedrock"

  project_name = var.project_name
  environment  = var.environment
}
