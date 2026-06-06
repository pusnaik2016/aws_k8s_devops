# ==============================================================================
# Amazon ECR — Elastic Container Registry
# ==============================================================================
# Provisions a private container registry for the Boardgame application
# Docker images. ECR is preferred over DockerHub for EKS deployments because:
#
#   - Faster pulls: ECR is in the same AWS region as EKS (no internet egress)
#   - VPC Endpoints: Images pulled via PrivateLink (never leaves AWS backbone)
#   - IAM auth: No external credentials needed (nodes use IAM roles)
#   - Scanning: Built-in vulnerability scanning on push (complementing Trivy)
#   - No rate limits: Unlike DockerHub's pull rate limits
#
# Lifecycle:
#   - Keep the last 10 tagged images
#   - Expire untagged images after 7 days (prevent stale image accumulation)
# ==============================================================================

# =============================================================================
# ECR Repository — Private Docker image storage
# =============================================================================
resource "aws_ecr_repository" "app" {
  name                 = "${var.project_name}/boardgame-app"
  image_tag_mutability = "MUTABLE"    # Allow re-tagging (e.g., :latest)

  # Enable image scanning on push — scans for OS and package vulnerabilities
  # This provides an additional layer of security on top of Trivy scanning
  # in the GitHub Actions CI pipeline
  image_scanning_configuration {
    scan_on_push = true
  }

  # Encrypt images at rest with AWS KMS
  encryption_configuration {
    encryption_type = "AES256"
  }

  # Force delete repository even if it contains images (for terraform destroy)
  force_delete = true

  tags = {
    Name = "${var.project_name}-ecr-repo"
  }
}

# =============================================================================
# Lifecycle Policy — Automatic image cleanup
# =============================================================================
# Prevents unbounded image accumulation in the registry:
#   1. Keep the last 10 tagged images (for rollback capability)
#   2. Expire untagged images after 7 days (build intermediates, etc.)
# =============================================================================
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        # Rule 1: Remove untagged images older than 7 days
        rulePriority = 1
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
      },
      {
        # Rule 2: Keep only the last 10 tagged images
        rulePriority = 2
        description  = "Keep only the last 10 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "build"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
