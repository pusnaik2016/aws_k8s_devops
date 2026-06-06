# =============================================================================
# AWS VPC Interface Endpoints — Private Cluster Access
# =============================================================================
# Since EKS runs as a private cluster with no Internet Gateway or NAT Gateway,
# all AWS API access must flow through VPC Interface Endpoints (AWS PrivateLink).
#
# Required endpoints for private EKS + ECR image pulls:
#   - ecr.api          → ECR API calls (auth, describe, list)
#   - ecr.dkr          → Docker layer pulls from ECR
#   - s3 (Gateway)     → ECR image layer storage (S3-backed)
#   - sts              → IRSA token exchange (pod identity)
#   - logs             → CloudWatch Logs (container logging)
#   - ec2              → ENI management for VPC-CNI
#   - elasticloadbalancing → ALB controller operations
# =============================================================================

# -----------------------------------------------------------------------------
# Security Group for VPC Endpoints
# -----------------------------------------------------------------------------
resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "${local.name_prefix}-vpce-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for VPC Interface Endpoints"

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-vpce-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# Interface Endpoints (PrivateLink)
# -----------------------------------------------------------------------------

# ECR API — Authentication & metadata operations
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = aws_subnet.private_app[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-vpce-ecr-api"
  })
}

# ECR DKR — Docker image layer pulls
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = aws_subnet.private_app[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-vpce-ecr-dkr"
  })
}

# S3 Gateway Endpoint — ECR image layers are stored in S3
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.private[*].id

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-vpce-s3"
  })
}

# STS — Required for IRSA (IAM Roles for Service Accounts) token exchange
resource "aws_vpc_endpoint" "sts" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.sts"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = aws_subnet.private_app[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-vpce-sts"
  })
}

# CloudWatch Logs — Container and application logging
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.logs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = aws_subnet.private_app[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-vpce-logs"
  })
}

# EC2 — Required for VPC-CNI ENI management
resource "aws_vpc_endpoint" "ec2" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.ec2"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = aws_subnet.private_app[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-vpce-ec2"
  })
}

# Elastic Load Balancing — Required for AWS Load Balancer Controller
resource "aws_vpc_endpoint" "elb" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.elasticloadbalancing"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = aws_subnet.private_app[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-vpce-elb"
  })
}

# SSM — Parameter Store access for secrets
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.ssm"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = aws_subnet.private_app[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-vpce-ssm"
  })
}

# KMS — Encryption/decryption operations for secrets-at-rest
resource "aws_vpc_endpoint" "kms" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.kms"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = aws_subnet.private_app[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-vpce-kms"
  })
}
