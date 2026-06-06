# ─────────────────────────────────────────────────────────────
# IRSA — IAM Roles for Service Accounts
# ─────────────────────────────────────────────────────────────
# Pod-level IAM: each microservice gets its own IAM role
# bound to a Kubernetes ServiceAccount via OIDC federation.
# ─────────────────────────────────────────────────────────────

locals {
  oidc_provider_arn = aws_iam_openid_connect_provider.eks.arn
  oidc_provider_url = replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")
}

# ─────────────────────────────────────────────────────────────
# Chat Service IRSA — Bedrock + Aurora + Redis
# ─────────────────────────────────────────────────────────────

resource "aws_iam_role" "chat_service" {
  name = "${local.cluster_name}-chat-service-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = local.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_provider_url}:aud" = "sts.amazonaws.com"
            "${local.oidc_provider_url}:sub" = "system:serviceaccount:omni-ai:chat-service"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "chat_service" {
  name = "chat-service-policy"
  role = aws_iam_role.chat_service.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "BedrockInvoke"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = [
          "arn:aws:bedrock:${var.aws_region}::foundation-model/anthropic.claude-3-5-sonnet-*",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/amazon.titan-embed-text-v2*"
        ]
      },
      {
        Sid    = "SSMRead"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/${var.project_name}/${var.environment}/*"
      }
    ]
  })
}

# ─────────────────────────────────────────────────────────────
# Analytics Service IRSA — Bedrock + S3
# ─────────────────────────────────────────────────────────────

resource "aws_iam_role" "analytics_service" {
  name = "${local.cluster_name}-analytics-service-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = local.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_provider_url}:aud" = "sts.amazonaws.com"
            "${local.oidc_provider_url}:sub" = "system:serviceaccount:omni-ai:analytics-service"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "analytics_service" {
  name = "analytics-service-policy"
  role = aws_iam_role.analytics_service.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "BedrockInvoke"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = [
          "arn:aws:bedrock:${var.aws_region}::foundation-model/anthropic.claude-3-5-sonnet-*"
        ]
      },
      {
        Sid    = "S3TranscriptAccess"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-${var.environment}-transcripts",
          "arn:aws:s3:::${var.project_name}-${var.environment}-transcripts/*"
        ]
      },
      {
        Sid    = "SSMRead"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/${var.project_name}/${var.environment}/*"
      }
    ]
  })
}
