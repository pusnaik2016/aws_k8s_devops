# ==============================================================================
# AWS WAF v2 — Web Application Firewall
# ==============================================================================
# Provisions a WAF Web ACL that protects the ALB from common web attacks.
# WAF inspects every HTTP request before it reaches the application and
# blocks malicious traffic based on configurable rules.
#
# Rules applied (in priority order):
#   1. Rate Limiting — Block IPs exceeding 2000 requests per 5 minutes
#   2. AWS Common Rules — OWASP Top 10 protection (XSS, LFI, etc.)
#   3. SQL Injection Rules — Detect and block SQL injection attempts
#   4. Known Bad Inputs — Block requests with known malicious patterns
#
# Association:
#   WAF is associated with the ALB to filter all incoming web traffic.
#   API Gateway has its own built-in throttling, so WAF focuses on ALB.
# ==============================================================================

# =============================================================================
# WAF Web ACL — The main firewall configuration
# =============================================================================
resource "aws_wafv2_web_acl" "app" {
  name        = "${var.project_name}-waf"
  description = "WAF Web ACL for DevSecOps application — OWASP protection + rate limiting"
  scope       = "REGIONAL" # REGIONAL for ALB; use CLOUDFRONT for CloudFront

  # Default action — Allow requests that don't match any block rules
  default_action {
    allow {}
  }

  # ---------------------------------------------------------------------------
  # Rule 1: Rate Limiting — Throttle abusive IPs
  # ---------------------------------------------------------------------------
  # Blocks any single IP address that exceeds the request threshold within
  # a 5-minute evaluation window. Protects against DDoS and brute force.
  # ---------------------------------------------------------------------------
  rule {
    name     = "rate-limit"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit # Requests per 5-minute window
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-rate-limit"
    }
  }

  # ---------------------------------------------------------------------------
  # Rule 2: AWS Managed Rules — Common Rule Set (OWASP Top 10)
  # ---------------------------------------------------------------------------
  # Provides protection against the OWASP Top 10 web application security
  # risks including cross-site scripting (XSS), local file inclusion (LFI),
  # remote file inclusion (RFI), and other common attack vectors.
  # ---------------------------------------------------------------------------
  rule {
    name     = "aws-common-rules"
    priority = 2

    override_action {
      none {} # Use the managed rule group's default actions
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-common-rules"
    }
  }

  # ---------------------------------------------------------------------------
  # Rule 3: SQL Injection Protection
  # ---------------------------------------------------------------------------
  # Detects and blocks SQL injection patterns in URLs, query parameters,
  # request bodies, and headers. Critical for applications with database
  # backends to prevent unauthorized data access.
  # ---------------------------------------------------------------------------
  rule {
    name     = "aws-sqli-rules"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-sqli-rules"
    }
  }

  # ---------------------------------------------------------------------------
  # Rule 4: Known Bad Inputs Protection
  # ---------------------------------------------------------------------------
  # Blocks request patterns known to be invalid or commonly used in attacks
  # such as Log4j exploits, SSRF patterns, and other known bad payloads.
  # ---------------------------------------------------------------------------
  rule {
    name     = "aws-known-bad-inputs"
    priority = 4

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-known-bad-inputs"
    }
  }

  # WAF-level visibility configuration (aggregate metrics)
  visibility_config {
    sampled_requests_enabled   = true
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-waf"
  }

  tags = {
    Name = "${var.project_name}-waf"
  }
}

# =============================================================================
# WAF Association — Attach the Web ACL to the ALB
# =============================================================================
# Associates the WAF rules with the Application Load Balancer so that
# every request to the ALB is inspected by WAF before reaching EKS.
# =============================================================================
resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = aws_lb.app.arn
  web_acl_arn  = aws_wafv2_web_acl.app.arn
}
