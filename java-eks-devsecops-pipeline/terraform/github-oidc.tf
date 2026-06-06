# ==============================================================================
# GitHub OIDC Provider — Keyless AWS Authentication for GitHub Actions
# ==============================================================================
# Configures OpenID Connect (OIDC) federation between GitHub Actions and AWS.
# This eliminates the need for long-lived AWS access keys in GitHub Secrets.
#
# How it works:
#   1. GitHub Actions generates a short-lived JWT token during workflow run
#   2. The workflow calls sts:AssumeRoleWithWebIdentity with this JWT
#   3. AWS validates the JWT against GitHub's OIDC provider
#   4. AWS issues temporary credentials (15-minute default) scoped to the role
#
# Security:
#   - The IAM role trust policy is scoped to a SPECIFIC GitHub repository
#     and branch, preventing other repos from assuming this role
#   - Credentials are temporary (cannot be leaked/reused)
#   - No long-lived secrets stored anywhere
#
# Reference: https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services
# ==============================================================================

# =============================================================================
# GitHub OIDC Identity Provider — Trust GitHub's token issuer
# =============================================================================
# Creates the OIDC identity provider in IAM that allows AWS to validate
# tokens issued by GitHub Actions. This is a one-time setup per AWS account.
# =============================================================================
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  # The audience claim must match — GitHub uses sts.amazonaws.com
  client_id_list = ["sts.amazonaws.com"]

  # GitHub's OIDC provider TLS certificate thumbprint
  # This is GitHub's well-known thumbprint for token.actions.githubusercontent.com
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = {
    Name = "${var.project_name}-github-oidc-provider"
  }
}

# =============================================================================
# IAM Role — Assumable ONLY by GitHub Actions from the specified repository
# =============================================================================
# Trust policy constraints:
#   - ONLY tokens from token.actions.githubusercontent.com are accepted
#   - ONLY the specified GitHub org/repo can assume this role
#   - ONLY the main branch can push images (prevents PR-based attacks)
# =============================================================================
resource "aws_iam_role" "github_actions" {
  name = "${var.project_name}-github-actions-ecr-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          # Audience must be sts.amazonaws.com
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          # ONLY allow the specified repository and main branch to assume this role
          # Format: repo:ORG/REPO:ref:refs/heads/BRANCH
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main"
        }
      }
    }]
  })

  tags = {
    Name = "${var.project_name}-github-actions-role"
  }
}

# =============================================================================
# IAM Policy — ECR Push Permissions
# =============================================================================
# Grants the minimum permissions needed for GitHub Actions to:
#   1. Authenticate to ECR (get authorization token)
#   2. Push Docker images (put, initiate, upload, complete, batch)
#   3. Check existing images (batch get, describe)
# =============================================================================
resource "aws_iam_role_policy" "github_actions_ecr" {
  name = "${var.project_name}-github-actions-ecr-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # ECR authentication — required to get a Docker login token
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        # ECR image operations — scoped to the specific repository only
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:DescribeImages"
        ]
        Resource = aws_ecr_repository.app.arn
      }
    ]
  })
}
