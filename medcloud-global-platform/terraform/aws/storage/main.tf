# ─────────────────────────────────────────────────────────────────────────────
# AWS Storage — S3, CloudFront CDN, ECR
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }

  backend "s3" {
    bucket         = "medcloud-terraform-state"
    key            = "aws/storage/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "medcloud-terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = merge(var.common_tags, {
      Cloud     = "AWS"
      Component = "storage"
    })
  }
}

data "terraform_remote_state" "security" {
  backend = "s3"
  config = {
    bucket = "medcloud-terraform-state"
    key    = "aws/security/terraform.tfstate"
    region = "us-east-1"
  }
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# S3 Buckets
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Static assets bucket (product images, PDFs)
resource "aws_s3_bucket" "static_assets" {
  bucket = "${local.name_prefix}-static-assets"
  tags = {
    Name      = "${local.name_prefix}-static-assets"
    DataClass = "public"
  }
}

resource "aws_s3_bucket_versioning" "static_assets" {
  bucket = aws_s3_bucket.static_assets.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "static_assets" {
  bucket = aws_s3_bucket.static_assets.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "static_assets" {
  bucket                  = aws_s3_bucket.static_assets.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Invoices bucket (PCI — encrypted documents)
resource "aws_s3_bucket" "invoices" {
  bucket = "${local.name_prefix}-invoices"
  tags = {
    Name       = "${local.name_prefix}-invoices"
    DataClass  = "PCI"
    Compliance = "PCI-DSS"
  }
}

resource "aws_s3_bucket_versioning" "invoices" {
  bucket = aws_s3_bucket.invoices.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "invoices" {
  bucket = aws_s3_bucket.invoices.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.storage.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "invoices" {
  bucket                  = aws_s3_bucket.invoices.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "invoices" {
  bucket = aws_s3_bucket.invoices.id
  rule {
    id     = "transition-to-ia"
    status = "Enabled"
    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }
    transition {
      days          = 365
      storage_class = "GLACIER"
    }
  }
}

resource "aws_kms_key" "storage" {
  description             = "CMK for S3 storage encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags = { Name = "${local.name_prefix}-storage-kms" }
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CloudFront CDN
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

resource "aws_cloudfront_origin_access_control" "s3" {
  name                              = "${local.name_prefix}-s3-oac"
  description                       = "OAC for S3 static assets"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "MedCloud Global CDN"
  default_root_object = "index.html"
  price_class         = "PriceClass_100"
  web_acl_id          = try(data.terraform_remote_state.security.outputs.waf_acl_arn, null)

  origin {
    domain_name              = aws_s3_bucket.static_assets.bucket_regional_domain_name
    origin_id                = "s3-static-assets"
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-static-assets"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Name = "${local.name_prefix}-cdn"
  }
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ECR Repositories (Container Registry)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

locals {
  ecr_repos = [
    "storefront-api",
    "order-service",
    "notification-service",
  ]
}

resource "aws_ecr_repository" "services" {
  for_each             = toset(local.ecr_repos)
  name                 = "medcloud/${each.value}"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.storage.arn
  }

  tags = {
    Name    = "medcloud-${each.value}"
    Service = each.value
  }
}

resource "aws_ecr_lifecycle_policy" "services" {
  for_each   = toset(local.ecr_repos)
  repository = aws_ecr_repository.services[each.key].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 20 tagged images"
        selection = {
          tagStatus   = "tagged"
          tagPrefixList = ["v"]
          countType   = "imageCountMoreThan"
          countNumber = 20
        }
        action = { type = "expire" }
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
        action = { type = "expire" }
      }
    ]
  })
}

# ─── Outputs ─────────────────────────────────────────────────────────────────

output "static_assets_bucket" {
  value = aws_s3_bucket.static_assets.id
}

output "invoices_bucket" {
  value = aws_s3_bucket.invoices.id
}

output "cloudfront_domain" {
  value = aws_cloudfront_distribution.main.domain_name
}

output "ecr_repos" {
  value = { for k, v in aws_ecr_repository.services : k => v.repository_url }
}
