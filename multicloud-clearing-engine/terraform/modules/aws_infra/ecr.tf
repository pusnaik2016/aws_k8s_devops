# =============================================================================
# AWS ECR — Container Registries (Private Access via VPC Endpoints)
# =============================================================================
# Creates ECR repositories for all clearing engine microservices.
# Images are pulled by EKS nodes via VPC Interface Endpoints — no internet
# access required (private cluster compatible).
# =============================================================================

locals {
  ecr_services = [
    "transaction-ingestion",
    "clearing-engine",
    "audit-pipeline",
    "notification-service",
  ]
}

# -----------------------------------------------------------------------------
# ECR Repositories
# -----------------------------------------------------------------------------
resource "aws_ecr_repository" "services" {
  for_each = toset(local.ecr_services)

  name                 = "${var.project_name}/${each.value}"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true # HIPAA: Vulnerability scanning required
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.main.arn
  }

  tags = merge(var.common_tags, {
    Name    = "${local.name_prefix}-ecr-${each.value}"
    Service = each.value
  })
}

# -----------------------------------------------------------------------------
# ECR Lifecycle Policies — Keep images clean
# -----------------------------------------------------------------------------
resource "aws_ecr_lifecycle_policy" "services" {
  for_each   = toset(local.ecr_services)
  repository = aws_ecr_repository.services[each.key].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 30 tagged production images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "sha-"]
          countType     = "imageCountMoreThan"
          countNumber   = 30
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Expire untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# ECR Repository Policy — Allow EKS nodes to pull
# -----------------------------------------------------------------------------
resource "aws_ecr_repository_policy" "eks_pull" {
  for_each   = toset(local.ecr_services)
  repository = aws_ecr_repository.services[each.key].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEKSNodePull"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.eks_node_group.arn
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
        ]
      }
    ]
  })
}
