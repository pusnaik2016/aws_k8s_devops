# ============================================================================
# AWS Networking — VPC, Subnets, NAT Gateway, VPC Endpoints
# ============================================================================
# Primary region: us-east-1 | HIPAA-compliant network segmentation
# ============================================================================

terraform {
  required_version = ">= 1.5"
}

# ──────────────────────────────────────────────────────────────────────────────
# Data Sources
# ──────────────────────────────────────────────────────────────────────────────

data "aws_availability_zones" "available" {
  state = "available"
}

# ──────────────────────────────────────────────────────────────────────────────
# VPC
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.common_tags, {
    Name               = "${var.project}-${var.environment}-vpc"
    DataClassification = "confidential"
  })
}

# ──────────────────────────────────────────────────────────────────────────────
# Subnets — 3 AZ, Public + Private + Database tiers
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_subnet" "public" {
  count                   = 3
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = merge(var.common_tags, {
    Name                              = "${var.project}-${var.environment}-public-${data.aws_availability_zones.available.names[count.index]}"
    "kubernetes.io/role/elb"          = "1"
    "kubernetes.io/cluster/${var.project}-${var.environment}-eks" = "shared"
    Tier                              = "public"
  })
}

resource "aws_subnet" "private" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + 3)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(var.common_tags, {
    Name                                       = "${var.project}-${var.environment}-private-${data.aws_availability_zones.available.names[count.index]}"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.project}-${var.environment}-eks" = "shared"
    Tier                                       = "private"
  })
}

resource "aws_subnet" "database" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + 6)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(var.common_tags, {
    Name               = "${var.project}-${var.environment}-database-${data.aws_availability_zones.available.names[count.index]}"
    Tier               = "database"
    DataClassification = "phi"
  })
}

# ──────────────────────────────────────────────────────────────────────────────
# Internet Gateway + NAT Gateway
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-igw"
  })
}

resource "aws_eip" "nat" {
  count  = var.environment == "prod" ? 3 : 1
  domain = "vpc"

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-nat-eip-${count.index}"
  })
}

resource "aws_nat_gateway" "main" {
  count         = var.environment == "prod" ? 3 : 1
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-nat-${count.index}"
  })

  depends_on = [aws_internet_gateway.main]
}

# ──────────────────────────────────────────────────────────────────────────────
# Route Tables
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-public-rt"
  })
}

resource "aws_route_table" "private" {
  count  = var.environment == "prod" ? 3 : 1
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  # Route to Azure DR via VPN
  dynamic "route" {
    for_each = var.azure_dr_cidr != "" ? [1] : []
    content {
      cidr_block         = var.azure_dr_cidr
      virtual_private_gateway_id = var.vpn_gateway_id
    }
  }

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-private-rt-${count.index}"
  })
}

resource "aws_route_table_association" "public" {
  count          = 3
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = 3
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[var.environment == "prod" ? count.index : 0].id
}

# ──────────────────────────────────────────────────────────────────────────────
# VPC Endpoints (PrivateLink — avoid NAT charges, enhance security)
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "${var.project}-${var.environment}-vpce-"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTPS from VPC"
  }

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-vpce-sg"
  })
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.private[*].id

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-s3-vpce"
  })
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-ecr-api-vpce"
  })
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-ecr-dkr-vpce"
  })
}

resource "aws_vpc_endpoint" "sts" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.sts"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-sts-vpce"
  })
}

# ──────────────────────────────────────────────────────────────────────────────
# VPC Flow Logs (HIPAA audit requirement)
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_flow_log" "vpc" {
  vpc_id               = aws_vpc.main.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = var.flow_log_group_arn
  iam_role_arn         = var.flow_log_role_arn

  tags = merge(var.common_tags, {
    Name       = "${var.project}-${var.environment}-vpc-flow-log"
    Compliance = "hipaa-audit"
  })
}
