# ==============================================================================
# Application Load Balancer (ALB)
# ==============================================================================
# Provisions an internet-facing ALB that distributes traffic to EKS pods.
# The ALB sits in public subnets and forwards traffic to the application
# pods running in private subnets via target group registration.
#
# Architecture:
#   Internet → Route53 → WAF → ALB (public) → EKS pods (private)
#
# Features:
#   - HTTP (80) listener with redirect to HTTPS
#   - HTTPS (443) listener with ACM certificate (when domain is configured)
#   - Health checks against /actuator/health
#   - Access logging (optional, requires S3 bucket)
#   - Deletion protection disabled for dev (enable in production)
# ==============================================================================

# =============================================================================
# ALB — Internet-facing load balancer in public subnets
# =============================================================================
resource "aws_lb" "app" {
  name               = "${var.project_name}-app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  # Disable for dev/demo — enable in production to prevent accidental deletion
  enable_deletion_protection = false

  # Drop invalid HTTP headers for security
  drop_invalid_header_fields = true

  tags = {
    Name = "${var.project_name}-app-alb"
  }
}

# =============================================================================
# Target Group — Routes traffic to EKS application pods
# =============================================================================
# Target type is "ip" because the ALB Controller registers pod IPs directly.
# Health checks ensure only healthy pods receive traffic.
# =============================================================================
resource "aws_lb_target_group" "app" {
  name        = "${var.project_name}-app-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.devsecops_vpc.id
  target_type = "ip"    # ALB Controller registers pod IPs directly

  # Health check configuration — matches Spring Boot Actuator endpoint
  health_check {
    enabled             = true
    path                = "/actuator/health"
    port                = "8080"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 10
    interval            = 30
    matcher             = "200"
  }

  # Deregistration delay — time to finish in-flight requests before removing target
  deregistration_delay = 30

  tags = {
    Name = "${var.project_name}-app-tg"
  }
}

# =============================================================================
# HTTP Listener (Port 80) — Redirects to HTTPS
# =============================================================================
# All HTTP traffic is automatically redirected to HTTPS for security.
# If no ACM certificate is configured, this listener forwards directly.
# =============================================================================
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = {
    Name = "${var.project_name}-http-listener"
  }
}

# =============================================================================
# HTTPS Listener (Port 443) — Terminates TLS, forwards to target group
# =============================================================================
# Uses the ACM certificate provisioned in route53.tf for TLS termination.
# If no certificate is available, use the HTTP listener with forward action.
# =============================================================================
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.app.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.app.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  depends_on = [aws_acm_certificate_validation.app]

  tags = {
    Name = "${var.project_name}-https-listener"
  }
}
