# =============================================================================
# External Secrets Operator Module
# Project: 3-Tier EKS Application
# Author: Pushparaj Naik
# Security: AWS Secrets Manager → Kubernetes secrets via IRSA
# =============================================================================

# --- Namespace ---
resource "kubernetes_namespace" "external_secrets" {
  count = var.enable ? 1 : 0

  metadata {
    name = "external-secrets"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      Environment                    = var.environment
    }
  }
}

# --- Helm Release ---
resource "helm_release" "external_secrets" {
  count = var.enable ? 1 : 0

  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = var.chart_version
  namespace  = kubernetes_namespace.external_secrets[0].metadata[0].name

  wait    = true
  timeout = 300

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "external-secrets-sa"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.external_secrets[0].arn
  }

  set {
    name  = "resources.requests.cpu"
    value = "50m"
  }

  set {
    name  = "resources.requests.memory"
    value = "64Mi"
  }

  set {
    name  = "resources.limits.cpu"
    value = "200m"
  }

  set {
    name  = "resources.limits.memory"
    value = "256Mi"
  }
}

# =============================================================================
# IRSA — IAM Role for External Secrets Service Account
# =============================================================================

resource "aws_iam_role" "external_secrets" {
  count = var.enable ? 1 : 0
  name  = "${var.prefix}-${var.environment}-external-secrets-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${var.oidc_provider}:aud" = "sts.amazonaws.com"
            "${var.oidc_provider}:sub" = "system:serviceaccount:external-secrets:external-secrets-sa"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.prefix}-${var.environment}-external-secrets-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "external_secrets" {
  count = var.enable ? 1 : 0
  name  = "${var.prefix}-${var.environment}-external-secrets-policy"
  role  = aws_iam_role.external_secrets[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecretVersionIds"
        ]
        Resource = [
          var.db_secret_arn,
          "arn:aws:secretsmanager:${var.aws_region}:${var.account_id}:secret:${var.prefix}-${var.environment}-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = [var.kms_key_arn]
      }
    ]
  })
}

# --- ClusterSecretStore ---
resource "kubernetes_manifest" "cluster_secret_store" {
  count = var.enable ? 1 : 0

  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ClusterSecretStore"

    metadata = {
      name = "aws-secrets-manager"
      labels = {
        "app.kubernetes.io/managed-by" = "terraform"
      }
    }

    spec = {
      provider = {
        aws = {
          service = "SecretsManager"
          region  = var.aws_region
          auth = {
            jwt = {
              serviceAccountRef = {
                name      = "external-secrets-sa"
                namespace = "external-secrets"
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.external_secrets]
}
