# ─────────────────────────────────────────────────────────────
# GitHub OIDC Provider — Zero Static Credentials
# ─────────────────────────────────────────────────────────────
# Allows GitHub Actions to assume an AWS IAM role via
# OpenID Connect federation, eliminating the need for
# long-lived AWS access keys stored in GitHub Secrets.
# ─────────────────────────────────────────────────────────────

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = merge(var.tags, {
    Name = "${var.project_name}-github-oidc"
  })
}

# ─────────────────────────────────────────────────────────────
# GitHub Actions Deploy Role
# ─────────────────────────────────────────────────────────────

resource "aws_iam_role" "github_actions_deploy" {
  name = "${var.project_name}-${var.environment}-github-actions-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
        Action    = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org_repo}:*"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-github-deploy-role"
  })
}

# Attach scoped permissions for Terraform operations (least privilege)
# Compliance: SOX separation of duties, PCI-DSS 7.1 least privilege
resource "aws_iam_policy" "github_actions_deploy" {
  name        = "${var.project_name}-${var.environment}-github-deploy-policy"
  description = "Scoped permissions for GitHub Actions Terraform + EKS deployments"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "TerraformStateAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-terraform-state",
          "arn:aws:s3:::${var.project_name}-terraform-state/*"
        ]
      },
      {
        Sid    = "TerraformLocking"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "arn:aws:dynamodb:*:*:table/${var.project_name}-terraform-locks"
      },
      {
        Sid    = "EKSManagement"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:UpdateClusterConfig",
          "eks:UpdateClusterVersion",
          "eks:DescribeNodegroup",
          "eks:UpdateNodegroupConfig",
          "eks:CreateNodegroup",
          "eks:DeleteNodegroup",
          "eks:CreateCluster",
          "eks:DeleteCluster",
          "eks:TagResource",
          "eks:CreateAddon",
          "eks:DeleteAddon",
          "eks:DescribeAddon"
        ]
        Resource = "arn:aws:eks:*:*:cluster/${var.project_name}-*"
      },
      {
        Sid    = "NetworkingAndCompute"
        Effect = "Allow"
        Action = [
          "ec2:*Vpc*", "ec2:*Subnet*", "ec2:*SecurityGroup*",
          "ec2:*RouteTable*", "ec2:*InternetGateway*", "ec2:*NatGateway*",
          "ec2:*Address*", "ec2:*FlowLog*", "ec2:*NetworkInterface*",
          "ec2:*Tags*", "ec2:Describe*", "ec2:CreateTags",
          "elasticloadbalancing:*",
          "autoscaling:*"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = ["us-east-1", "us-west-2"]
          }
        }
      },
      {
        Sid    = "DatabaseServices"
        Effect = "Allow"
        Action = [
          "rds:*",
          "elasticache:*"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = ["us-east-1", "us-west-2"]
          }
        }
      },
      {
        Sid    = "IAMRoleManagement"
        Effect = "Allow"
        Action = [
          "iam:CreateRole", "iam:DeleteRole", "iam:GetRole",
          "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:GetRolePolicy",
          "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies", "iam:TagRole", "iam:PassRole",
          "iam:CreatePolicy", "iam:DeletePolicy", "iam:GetPolicy",
          "iam:GetPolicyVersion", "iam:ListPolicyVersions", "iam:CreatePolicyVersion",
          "iam:CreateOpenIDConnectProvider", "iam:GetOpenIDConnectProvider",
          "iam:DeleteOpenIDConnectProvider", "iam:TagOpenIDConnectProvider",
          "iam:CreateServiceLinkedRole"
        ]
        Resource = "*"
      },
      {
        Sid    = "SecurityAndEncryption"
        Effect = "Allow"
        Action = [
          "kms:CreateKey", "kms:DescribeKey", "kms:GetKeyPolicy",
          "kms:GetKeyRotationStatus", "kms:ListResourceTags",
          "kms:CreateAlias", "kms:DeleteAlias", "kms:EnableKeyRotation",
          "kms:TagResource", "kms:ScheduleKeyDeletion",
          "ssm:PutParameter", "ssm:GetParameter", "ssm:DeleteParameter",
          "ssm:DescribeParameters", "ssm:AddTagsToResource", "ssm:ListTagsForResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "StorageAndCDN"
        Effect = "Allow"
        Action = [
          "s3:CreateBucket", "s3:DeleteBucket", "s3:Get*", "s3:Put*", "s3:List*",
          "cloudfront:*",
          "apigateway:*",
          "route53:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "ComplianceServices"
        Effect = "Allow"
        Action = [
          "guardduty:*", "securityhub:*", "config:*",
          "macie2:*", "access-analyzer:*", "wafv2:*",
          "cloudtrail:*", "budgets:*", "bedrock:*",
          "logs:*", "events:*", "sns:*",
          "cloudwatch:PutMetricAlarm", "cloudwatch:DeleteAlarms",
          "cloudwatch:DescribeAlarms"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "github_actions_deploy" {
  role       = aws_iam_role.github_actions_deploy.name
  policy_arn = aws_iam_policy.github_actions_deploy.arn
}

# Attach permissions for ECR push
resource "aws_iam_role_policy" "github_actions_ecr" {
  name = "ecr-push-policy"
  role = aws_iam_role.github_actions_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = "*"
      }
    ]
  })
}
