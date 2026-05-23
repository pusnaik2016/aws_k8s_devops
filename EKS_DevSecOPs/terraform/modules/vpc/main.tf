# ==============================================================================
# VPC Module — Production Multi-AZ Network Architecture
# ==============================================================================
# Creates a production-grade VPC spanning 3 Availability Zones with:
#
#   Public Subnets (3):  ALB, NAT Gateways, Bastion host
#   Private Subnets (3): EKS worker nodes, application pods
#   Database Subnets (3): Aurora DB instances (isolated)
#
#   NAT Gateways:  One per AZ for HA (production)
#   VPC Flow Logs: Encrypted with KMS, 365-day retention
#   VPC Endpoints: ECR, S3, STS, CloudWatch, EKS, RDS, KMS, SNS, SQS
#
# All subnets tagged for EKS auto-discovery and Karpenter node placement.
# ==============================================================================

# =============================================================================
# VPC — Isolated virtual network
# =============================================================================
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name                                              = "${var.project_name}-vpc"
    "kubernetes.io/cluster/${var.project_name}-eks"    = "shared"
  })
}

# =============================================================================
# Public Subnets — ALB, NAT Gateways, Bastion
# =============================================================================
resource "aws_subnet" "public" {
  count = length(var.availability_zones)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name                                              = "${var.project_name}-public-${var.availability_zones[count.index]}"
    "kubernetes.io/role/elb"                           = "1"
    "kubernetes.io/cluster/${var.project_name}-eks"    = "shared"
    "karpenter.sh/discovery"                           = "${var.project_name}-eks"
    Tier                                              = "public"
  })
}

# =============================================================================
# Private Subnets — EKS worker nodes (NO public IPs)
# =============================================================================
resource "aws_subnet" "private" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.tags, {
    Name                                              = "${var.project_name}-private-${var.availability_zones[count.index]}"
    "kubernetes.io/role/internal-elb"                  = "1"
    "kubernetes.io/cluster/${var.project_name}-eks"    = "shared"
    "karpenter.sh/discovery"                           = "${var.project_name}-eks"
    Tier                                              = "private"
  })
}

# =============================================================================
# Database Subnets — Aurora instances (isolated, no internet access)
# =============================================================================
resource "aws_subnet" "database" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.database_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.tags, {
    Name = "${var.project_name}-database-${var.availability_zones[count.index]}"
    Tier = "database"
  })
}

# =============================================================================
# DB Subnet Group — For Aurora placement
# =============================================================================
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = aws_subnet.database[*].id

  tags = merge(var.tags, {
    Name = "${var.project_name}-db-subnet-group"
  })
}

# =============================================================================
# Internet Gateway
# =============================================================================
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.project_name}-igw"
  })
}

# =============================================================================
# Elastic IPs for NAT Gateways (one per AZ for HA)
# =============================================================================
resource "aws_eip" "nat" {
  count  = var.single_nat_gateway ? 1 : length(var.availability_zones)
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.project_name}-nat-eip-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.main]
}

# =============================================================================
# NAT Gateways — Internet egress for private subnets
# =============================================================================
resource "aws_nat_gateway" "main" {
  count = var.single_nat_gateway ? 1 : length(var.availability_zones)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.tags, {
    Name = "${var.project_name}-nat-gw-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.main]
}

# =============================================================================
# Route Tables
# =============================================================================

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Route Tables (one per AZ or shared)
resource "aws_route_table" "private" {
  count  = var.single_nat_gateway ? 1 : length(var.availability_zones)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-private-rt-${count.index + 1}"
  })
}

resource "aws_route_table_association" "private" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[var.single_nat_gateway ? 0 : count.index].id
}

# Database Route Tables (no internet access — isolated)
resource "aws_route_table" "database" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.project_name}-database-rt"
  })
}

resource "aws_route_table_association" "database" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database.id
}

# =============================================================================
# VPC Flow Logs — Network traffic monitoring (KMS-encrypted)
# =============================================================================
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc-flowlogs/${var.project_name}"
  retention_in_days = 365
  kms_key_id        = var.kms_key_arn

  tags = merge(var.tags, {
    Name       = "${var.project_name}-vpc-flow-logs"
    Compliance = "PCI-HIPAA-SOC2"
  })
}

resource "aws_iam_role" "vpc_flow_logs" {
  name = "${var.project_name}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-vpc-flow-logs-role"
  })
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "${var.project_name}-vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "${aws_cloudwatch_log_group.vpc_flow_logs.arn}:*"
    }]
  })
}

resource "aws_flow_log" "main" {
  vpc_id                   = aws_vpc.main.id
  traffic_type             = "ALL"
  log_destination_type     = "cloud-watch-logs"
  log_destination          = aws_cloudwatch_log_group.vpc_flow_logs.arn
  iam_role_arn             = aws_iam_role.vpc_flow_logs.arn
  max_aggregation_interval = 60

  tags = merge(var.tags, {
    Name = "${var.project_name}-vpc-flow-log"
  })
}

# =============================================================================
# VPC Endpoints — Private connectivity to AWS services
# =============================================================================

# Security Group for VPC Endpoints
resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.project_name}-vpc-endpoints-sg"
  description = "Allow HTTPS from VPC CIDR for VPC Interface Endpoints"
  vpc_id      = aws_vpc.main.id

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

  tags = merge(var.tags, {
    Name = "${var.project_name}-vpc-endpoints-sg"
  })
}

# --- Interface Endpoints ---
locals {
  interface_endpoints = {
    "ecr-api"  = "com.amazonaws.${var.aws_region}.ecr.api"
    "ecr-dkr"  = "com.amazonaws.${var.aws_region}.ecr.dkr"
    "sts"      = "com.amazonaws.${var.aws_region}.sts"
    "logs"     = "com.amazonaws.${var.aws_region}.logs"
    "eks"      = "com.amazonaws.${var.aws_region}.eks"
    "kms"      = "com.amazonaws.${var.aws_region}.kms"
    "sns"      = "com.amazonaws.${var.aws_region}.sns"
    "sqs"      = "com.amazonaws.${var.aws_region}.sqs"
    "rds"      = "com.amazonaws.${var.aws_region}.rds"
  }
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_endpoints

  vpc_id              = aws_vpc.main.id
  service_name        = each.value
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-${each.key}-endpoint"
  })
}

# --- S3 Gateway Endpoint (FREE) ---
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat(
    aws_route_table.private[*].id,
    [aws_route_table.database.id]
  )

  tags = merge(var.tags, {
    Name = "${var.project_name}-s3-endpoint"
  })
}

# --- DynamoDB Gateway Endpoint (FREE) ---
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.private[*].id

  tags = merge(var.tags, {
    Name = "${var.project_name}-dynamodb-endpoint"
  })
}
