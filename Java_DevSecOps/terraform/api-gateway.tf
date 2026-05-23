# ==============================================================================
# API Gateway (HTTP API v2) — API Management Layer
# ==============================================================================
# Provisions an AWS HTTP API (v2) as the API management layer for the
# Boardgame application. API Gateway sits in front of the ALB and provides:
#
#   - Cognito JWT Authorization — Only authenticated users can call APIs
#   - Rate Limiting / Throttling — Protects backend from traffic spikes
#   - VPC Link — Privately routes traffic to the internal ALB
#   - Request/Response Logging — CloudWatch integration for debugging
#
# Architecture:
#   Client → API Gateway → (Cognito Auth) → VPC Link → ALB → EKS Pods
#
# HTTP API v2 is chosen over REST API for:
#   - Lower latency (~10ms vs ~29ms)
#   - Lower cost ($1.00 vs $3.50 per million requests)
#   - Native JWT authorizer support
#   - Automatic deployments
# ==============================================================================

# =============================================================================
# HTTP API — The API Gateway entry point
# =============================================================================
resource "aws_apigatewayv2_api" "app" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"
  description   = "API Gateway for Boardgame DevSecOps application"

  # CORS configuration for browser-based clients
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization", "X-Amz-Date"]
    max_age       = 3600
  }

  tags = {
    Name = "${var.project_name}-api"
  }
}

# =============================================================================
# VPC Link — Private connectivity from API Gateway to the ALB
# =============================================================================
# VPC Link creates a private connection between API Gateway and resources
# inside the VPC (the ALB). Traffic never traverses the public internet.
# =============================================================================
resource "aws_apigatewayv2_vpc_link" "app" {
  name               = "${var.project_name}-vpc-link"
  subnet_ids         = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.alb.id]

  tags = {
    Name = "${var.project_name}-vpc-link"
  }
}

# =============================================================================
# Cognito JWT Authorizer — Validates tokens from Cognito User Pool
# =============================================================================
# All API requests must include a valid JWT token in the Authorization header.
# The authorizer validates the token against the Cognito User Pool and checks:
#   - Token signature (using JWKS from Cognito)
#   - Token expiration
#   - Audience (client ID match)
# =============================================================================
resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.app.id
  name             = "${var.project_name}-cognito-authorizer"
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.app.id]
    issuer   = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.app.id}"
  }
}

# =============================================================================
# Integration — Connect API Gateway to ALB via VPC Link
# =============================================================================
# HTTP_PROXY integration forwards the entire request to the ALB, including
# path, query parameters, and headers. The ALB then routes to EKS pods.
# =============================================================================
resource "aws_apigatewayv2_integration" "alb" {
  api_id             = aws_apigatewayv2_api.app.id
  integration_type   = "HTTP_PROXY"
  integration_uri    = aws_lb_listener.https.arn
  integration_method = "ANY"
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.app.id

  # Timeout configuration
  timeout_milliseconds = 30000    # 30 second timeout
}

# =============================================================================
# Route — Catch-all route for /api/* requests with Cognito authorization
# =============================================================================
# All requests to /api/* are routed through the Cognito authorizer first,
# then forwarded to the ALB integration. This ensures only authenticated
# users can access the application APIs.
# =============================================================================
resource "aws_apigatewayv2_route" "api" {
  api_id    = aws_apigatewayv2_api.app.id
  route_key = "ANY /api/{proxy+}"

  target             = "integrations/${aws_apigatewayv2_integration.alb.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

# Health check route — NO authorization required (for monitoring tools)
resource "aws_apigatewayv2_route" "health" {
  api_id    = aws_apigatewayv2_api.app.id
  route_key = "GET /actuator/health"

  target = "integrations/${aws_apigatewayv2_integration.alb.id}"
  # No authorization — health checks must be accessible publicly
}

# =============================================================================
# Stage — Default stage with auto-deploy and throttling
# =============================================================================
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.app.id
  name        = "$default"
  auto_deploy = true

  # Throttling — protects backend from traffic spikes
  default_route_settings {
    throttling_burst_limit = 1000    # Max concurrent requests
    throttling_rate_limit  = 500     # Sustained requests per second
  }

  # Access logging to CloudWatch
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
      errorMessage   = "$context.error.message"
    })
  }

  tags = {
    Name = "${var.project_name}-api-default-stage"
  }
}

# CloudWatch Log Group for API Gateway access logs
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.project_name}-api"
  retention_in_days = 30

  tags = {
    Name = "${var.project_name}-api-gateway-logs"
  }
}
