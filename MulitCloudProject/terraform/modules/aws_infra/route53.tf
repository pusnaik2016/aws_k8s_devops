# =============================================================================
# AWS Route 53 — Global DNS & Traffic Routing
# =============================================================================
# Features:
#   - Latency-based routing (AWS primary ↔ Azure standby)
#   - Health checks with automatic failover
#   - Geolocation routing for GDPR EU traffic trapping
# =============================================================================

# -----------------------------------------------------------------------------
# Hosted Zone
# -----------------------------------------------------------------------------
resource "aws_route53_zone" "main" {
  name    = var.domain_name
  comment = "Multicloud Clearing Engine — Global DNS"

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-hosted-zone"
  })
}

# -----------------------------------------------------------------------------
# Health Check — AWS Primary (CloudFront)
# -----------------------------------------------------------------------------
resource "aws_route53_health_check" "aws_primary" {
  fqdn              = aws_cloudfront_distribution.main.domain_name
  port               = 443
  type               = "HTTPS"
  resource_path      = "/health"
  failure_threshold  = 3
  request_interval   = 10
  measure_latency    = true

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-health-check-aws"
  })
}

# -----------------------------------------------------------------------------
# Latency-Based Routing — AWS Primary
# -----------------------------------------------------------------------------
resource "aws_route53_record" "primary" {
  zone_id        = aws_route53_zone.main.zone_id
  name           = "api.${var.domain_name}"
  type           = "A"
  set_identifier = "aws-primary"

  alias {
    name                   = aws_cloudfront_distribution.main.domain_name
    zone_id                = aws_cloudfront_distribution.main.hosted_zone_id
    evaluate_target_health = true
  }

  latency_routing_policy {
    region = var.region
  }

  health_check_id = aws_route53_health_check.aws_primary.id
}

# -----------------------------------------------------------------------------
# GDPR Geolocation Routing — EU Traffic Stays in EU Region
# -----------------------------------------------------------------------------
resource "aws_route53_record" "eu_geolocation" {
  zone_id        = aws_route53_zone.main.zone_id
  name           = "api.${var.domain_name}"
  type           = "A"
  set_identifier = "eu-geolocation"

  alias {
    name                   = aws_cloudfront_distribution.main.domain_name
    zone_id                = aws_cloudfront_distribution.main.hosted_zone_id
    evaluate_target_health = true
  }

  geolocation_routing_policy {
    continent = "EU"
  }
}

# -----------------------------------------------------------------------------
# Failover Record — Azure Hot Standby (CNAME to Front Door)
# -----------------------------------------------------------------------------
resource "aws_route53_record" "failover_secondary" {
  zone_id        = aws_route53_zone.main.zone_id
  name           = "failover.${var.domain_name}"
  type           = "CNAME"
  ttl            = 60
  set_identifier = "azure-standby"

  records = ["standby.${var.domain_name}"] # Azure Front Door CNAME

  failover_routing_policy {
    type = "SECONDARY"
  }
}
