# ==============================================================================
# Route53 & ACM — DNS Management and TLS Certificates
# ==============================================================================
# Provisions DNS records and TLS certificates for the DevSecOps application:
#
#   Route53:
#     - Hosted Zone for the domain
#     - A Record (Alias) pointing app.domain.com → ALB
#     - A Record (Alias) pointing api.domain.com → API Gateway
#
#   ACM (AWS Certificate Manager):
#     - TLS certificate for *.domain.com (wildcard)
#     - DNS-based validation (automatically validated via Route53)
#     - Used by ALB HTTPS listener and API Gateway custom domain
#
# Prerequisites:
#   - Set var.domain_name to your registered domain
#   - If using an existing domain, set create_route53_zone = false
#     and import the existing hosted zone
# ==============================================================================

# =============================================================================
# Route53 Hosted Zone — DNS zone for the domain
# =============================================================================
# Creates a public hosted zone for managing DNS records.
# After creation, update your domain registrar's nameservers to the
# Route53 nameservers shown in the Terraform outputs.
# =============================================================================
resource "aws_route53_zone" "main" {
  count = var.create_route53_zone ? 1 : 0

  name    = var.domain_name
  comment = "DNS zone for DevSecOps application managed by Terraform"

  tags = {
    Name = "${var.project_name}-dns-zone"
  }
}

# Use existing zone if not creating a new one
data "aws_route53_zone" "existing" {
  count = var.create_route53_zone ? 0 : 1

  name         = var.domain_name
  private_zone = false
}

# Local value to reference the zone ID regardless of creation method
locals {
  zone_id = var.create_route53_zone ? aws_route53_zone.main[0].zone_id : data.aws_route53_zone.existing[0].zone_id
}

# =============================================================================
# ACM Certificate — TLS certificate for HTTPS
# =============================================================================
# Requests a wildcard certificate (*.domain.com) that covers:
#   - app.domain.com (ALB)
#   - api.domain.com (API Gateway)
#   - Any future subdomains
#
# Validation is performed automatically via DNS records in Route53.
# =============================================================================
resource "aws_acm_certificate" "app" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-acm-cert"
  }
}

# DNS validation records — ACM creates these to prove domain ownership
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.app.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = local.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]

  allow_overwrite = true
}

# Wait for certificate validation to complete
resource "aws_acm_certificate_validation" "app" {
  certificate_arn         = aws_acm_certificate.app.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# =============================================================================
# DNS Records — Point subdomains to AWS resources
# =============================================================================

# app.domain.com → ALB (direct web access)
resource "aws_route53_record" "app" {
  zone_id = local.zone_id
  name    = "app.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.app.dns_name
    zone_id                = aws_lb.app.zone_id
    evaluate_target_health = true
  }
}

# api.domain.com → API Gateway (authenticated API access)
resource "aws_route53_record" "api" {
  zone_id = local.zone_id
  name    = "api.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_apigatewayv2_api.app.api_endpoint
    zone_id                = aws_apigatewayv2_api.app.id
    evaluate_target_health = false
  }
}
