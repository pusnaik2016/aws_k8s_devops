# =============================================================================
# AWS CloudFront + WAF — CDN & Edge Security
# =============================================================================

# -----------------------------------------------------------------------------
# AWS WAF WebACL — OWASP Top 10 Protection
# -----------------------------------------------------------------------------
resource "aws_wafv2_web_acl" "main" {
  name        = "${local.name_prefix}-waf"
  scope       = "CLOUDFRONT"
  description = "WAF for CloudFront — OWASP + rate limiting + geo-blocking"

  default_action {
    allow {}
  }

  # AWS Managed Rules — Core Rule Set (OWASP)
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1
    override_action { none {} }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rules — Known Bad Inputs
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2
    override_action { none {} }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "KnownBadInputs"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rules — SQL Injection
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 3
    override_action { none {} }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "SQLiRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # Rate Limiting — DDoS Protection
  rule {
    name     = "RateLimitRule"
    priority = 10
    action { block {} }
    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.name_prefix}-waf"
    sampled_requests_enabled   = true
  }

  tags = local.tags
}

# -----------------------------------------------------------------------------
# S3 Bucket for CloudFront Access Logs
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "cf_logs" {
  bucket        = "${local.name_prefix}-cf-access-logs"
  force_destroy = false

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-cf-access-logs"
  })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cf_logs" {
  bucket = aws_s3_bucket.cf_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.main.arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cf_logs" {
  bucket = aws_s3_bucket.cf_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "cf_logs" {
  bucket = aws_s3_bucket.cf_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_ownership_controls" "cf_logs" {
  bucket = aws_s3_bucket.cf_logs.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# -----------------------------------------------------------------------------
# CloudFront Distribution
# -----------------------------------------------------------------------------
resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = true
  http_version        = "http2and3"
  comment             = "Clearing Engine CDN — Primary Active Site"
  price_class         = "PriceClass_100" # US, Canada, Europe
  web_acl_id          = aws_wafv2_web_acl.main.arn
  wait_for_deployment = false

  origin {
    domain_name = "alb.${var.domain_name}" # ALB origin — updated post-deploy
    origin_id   = "primary-alb"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "primary-alb"

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
    compress               = true

    forwarded_values {
      query_string = true
      headers      = ["*"]
      cookies {
        forward = "all"
      }
    }
  }

  # GDPR Geo-Restriction (optional: restrict to specific countries)
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.cf_logs.bucket_regional_domain_name
    prefix          = "cloudfront/"
  }

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-cloudfront"
  })
}
