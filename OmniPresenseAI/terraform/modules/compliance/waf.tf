# ─────────────────────────────────────────────────────────────
# AWS WAF v2 — Web Application Firewall
# ─────────────────────────────────────────────────────────────
# Compliance: PCI-DSS 6.6 (web app firewall), OWASP Top 10
# WAF Pillar: Security (Perimeter protection)
# ─────────────────────────────────────────────────────────────

# WAF Web ACL for CloudFront (must be us-east-1 for CF)
resource "aws_wafv2_web_acl" "cloudfront" {
  name        = "${var.project_name}-${var.environment}-cf-waf"
  description = "WAF for CloudFront — OWASP Top 10 protection"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  # ─── Rule 1: AWS Managed Common Rule Set (OWASP Core) ─────
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
      metric_name                = "${var.project_name}-common-rules"
      sampled_requests_enabled   = true
    }
  }

  # ─── Rule 2: SQL Injection Protection ─────────────────────
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 2

    override_action { none {} }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-sqli-rules"
      sampled_requests_enabled   = true
    }
  }

  # ─── Rule 3: Known Bad Inputs ─────────────────────────────
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 3

    override_action { none {} }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  # ─── Rule 4: Bot Control ──────────────────────────────────
  rule {
    name     = "AWSManagedRulesBotControlRuleSet"
    priority = 4

    override_action { none {} }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesBotControlRuleSet"
        vendor_name = "AWS"

        managed_rule_group_configs {
          aws_managed_rules_bot_control_rule_set {
            inspection_level = "COMMON"
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-bot-control"
      sampled_requests_enabled   = true
    }
  }

  # ─── Rule 5: Rate Limiting (DDoS protection) ──────────────
  rule {
    name     = "RateLimitRule"
    priority = 5

    action { block {} }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  # ─── Rule 6: Geo-restriction (optional) ───────────────────
  rule {
    name     = "GeoRestriction"
    priority = 6

    action { count {} } # Count-only mode — enable block when ready

    statement {
      geo_match_statement {
        country_codes = var.blocked_countries
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-geo-block"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-waf-global"
    sampled_requests_enabled   = true
  }

  tags = merge(var.tags, {
    Name       = "${var.project_name}-${var.environment}-waf"
    Compliance = "PCI-DSS,OWASP"
  })
}

# WAF logging to CloudWatch
resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-${var.project_name}-${var.environment}"
  retention_in_days = 90

  tags = merge(var.tags, { Compliance = "PCI-DSS" })
}

resource "aws_wafv2_web_acl_logging_configuration" "main" {
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
  resource_arn            = aws_wafv2_web_acl.cloudfront.arn
}
