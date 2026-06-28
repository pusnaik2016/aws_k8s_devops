# =============================================================================
# AWS NETWORKING MODULE — Multi-AZ Isolated VPC for Databricks Medallion
# =============================================================================
# Architecture:
#   Public Subnets     → NAT Gateways only (no workloads exposed)
#   Private-Compute    → Databricks clusters, PySpark jobs
#   Private-Data       → S3 VPC Endpoints, Secrets Manager (no internet)
#
# COMPLIANCE:
#   HIPAA  — VPC Flow Logs (365-day retention, CMK encrypted)
#   SOC 2  — Zero public IP on compute/data tiers
#   PCI-DSS — Network segmentation via NACLs + Security Groups
# =============================================================================

# ---------------------------------------------------------------------------
# Data Sources
# ---------------------------------------------------------------------------
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

# ---------------------------------------------------------------------------
# Locals
# ---------------------------------------------------------------------------
locals {
  name_prefix = "${var.project_name}-${var.environment}"
  account_id  = data.aws_caller_identity.current.account_id
  region      = data.aws_region.current.name
  azs         = slice(data.aws_availability_zones.available.names, 0, 2)

  tags = merge(var.common_tags, {
    Module      = "aws-networking"
    Cloud       = "aws"
    Environment = var.environment
    Compliance  = "hipaa-soc2-pci"
    ManagedBy   = "terraform"
  })
}

# =============================================================================
# VPC
# =============================================================================
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

# =============================================================================
# Internet Gateway (required for NAT Gateways only)
# =============================================================================
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-igw"
  })
}

# =============================================================================
# SUBNETS — 3-Tier Isolation (Public / Private-Compute / Private-Data)
# =============================================================================

# -----------------------------------------------------------------------------
# Public Subnets — NAT Gateways ONLY (no workloads)
# -----------------------------------------------------------------------------
resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false # COMPLIANCE: No auto-assigned public IPs

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-public-${local.azs[count.index]}"
    Tier = "public"
  })
}

# -----------------------------------------------------------------------------
# Private-Compute Subnets — Databricks Clusters / PySpark
# -----------------------------------------------------------------------------
resource "aws_subnet" "private_compute" {
  count = 2

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + 4)
  availability_zone = local.azs[count.index]

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-private-compute-${local.azs[count.index]}"
    Tier = "private-compute"
  })
}

# -----------------------------------------------------------------------------
# Private-Data Subnets — S3 endpoints, Secrets Manager (fully isolated)
# -----------------------------------------------------------------------------
resource "aws_subnet" "private_data" {
  count = 2

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + 8)
  availability_zone = local.azs[count.index]

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-private-data-${local.azs[count.index]}"
    Tier = "private-data"
  })
}

# =============================================================================
# NAT GATEWAYS — One per AZ for HA (egress for package downloads only)
# =============================================================================
resource "aws_eip" "nat" {
  count  = 2
  domain = "vpc"

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-nat-eip-${local.azs[count.index]}"
  })
}

resource "aws_nat_gateway" "main" {
  count = 2

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-nat-${local.azs[count.index]}"
  })

  depends_on = [aws_internet_gateway.main]
}

# =============================================================================
# ROUTE TABLES
# =============================================================================

# Public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-rt-public"
  })
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private-compute route tables (one per AZ, NAT egress)
resource "aws_route_table" "private_compute" {
  count  = 2
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-rt-private-compute-${local.azs[count.index]}"
  })
}

resource "aws_route_table_association" "private_compute" {
  count          = 2
  subnet_id      = aws_subnet.private_compute[count.index].id
  route_table_id = aws_route_table.private_compute[count.index].id
}

# Private-data route tables (NO internet, VPC internal + cross-cloud only)
resource "aws_route_table" "private_data" {
  count  = 2
  vpc_id = aws_vpc.main.id

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-rt-private-data-${local.azs[count.index]}"
  })
}

resource "aws_route_table_association" "private_data" {
  count          = 2
  subnet_id      = aws_subnet.private_data[count.index].id
  route_table_id = aws_route_table.private_data[count.index].id
}

# =============================================================================
# VPC ENDPOINTS — Private connectivity to AWS services (no internet traverse)
# =============================================================================

# Security group for VPC Interface Endpoints
resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "${local.name_prefix}-vpce-"
  description = "Security group for VPC Interface Endpoints"
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

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-vpce-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# S3 Gateway Endpoint (free, no interface charges)
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${local.region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = concat(
    aws_route_table.private_compute[*].id,
    aws_route_table.private_data[*].id
  )

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-vpce-s3"
  })
}

# STS Interface Endpoint (required for IAM role assumption)
resource "aws_vpc_endpoint" "sts" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${local.region}.sts"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = aws_subnet.private_compute[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-vpce-sts"
  })
}

# KMS Interface Endpoint
resource "aws_vpc_endpoint" "kms" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${local.region}.kms"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = aws_subnet.private_data[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-vpce-kms"
  })
}

# Secrets Manager Interface Endpoint
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${local.region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = aws_subnet.private_data[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-vpce-secretsmanager"
  })
}

# CloudWatch Logs Interface Endpoint
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${local.region}.logs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = aws_subnet.private_compute[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-vpce-logs"
  })
}

# Databricks SCC Relay (Secure Cluster Connectivity)
resource "aws_vpc_endpoint" "databricks_scc_relay" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.vpce.${local.region}.vpce-svc-${var.databricks_scc_relay_service_id}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = false

  subnet_ids         = aws_subnet.private_compute[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-vpce-databricks-scc"
  })
}

# Databricks REST API (Workspace Access)
resource "aws_vpc_endpoint" "databricks_workspace" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.vpce.${local.region}.vpce-svc-${var.databricks_workspace_service_id}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = aws_subnet.private_compute[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-vpce-databricks-workspace"
  })
}

# =============================================================================
# VPC FLOW LOGS — HIPAA Audit Trail (365 days, CMK encrypted)
# =============================================================================
resource "aws_flow_log" "main" {
  vpc_id                   = aws_vpc.main.id
  traffic_type             = "ALL"
  log_destination_type     = "cloud-watch-logs"
  log_destination          = aws_cloudwatch_log_group.vpc_flow_logs.arn
  iam_role_arn             = aws_iam_role.vpc_flow_logs.arn
  max_aggregation_interval = 60

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-vpc-flow-logs"
  })
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/flow-logs/${local.name_prefix}"
  retention_in_days = 365 # HIPAA: 1-year minimum retention
  kms_key_id        = var.logs_kms_key_arn

  tags = local.tags
}

resource "aws_iam_role" "vpc_flow_logs" {
  name = "${local.name_prefix}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "${local.name_prefix}-vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "*"
    }]
  })
}

# =============================================================================
# NETWORK ACLs — Data-Tier Isolation (HIPAA/PCI network segmentation)
# =============================================================================
resource "aws_network_acl" "private_data" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.private_data[*].id

  # Allow inbound HTTPS from compute subnets (S3/KMS/Secrets via VPC Endpoints)
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = cidrsubnet(var.vpc_cidr, 4, 4) # private-compute-az1
    from_port  = 443
    to_port    = 443
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = cidrsubnet(var.vpc_cidr, 4, 5) # private-compute-az2
    from_port  = 443
    to_port    = 443
  }

  # Allow ephemeral return traffic
  ingress {
    protocol   = "tcp"
    rule_no    = 900
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 1024
    to_port    = 65535
  }

  # Outbound: allow responses back to compute subnets
  egress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 1024
    to_port    = 65535
  }

  # Outbound: allow HTTPS to VPC endpoints
  egress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 443
    to_port    = 443
  }

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-nacl-private-data"
  })
}

# =============================================================================
# SECURITY GROUPS — Databricks Cluster Compute
# =============================================================================
resource "aws_security_group" "databricks_compute" {
  name_prefix = "${local.name_prefix}-dbx-compute-"
  description = "Databricks cluster worker and driver nodes"
  vpc_id      = aws_vpc.main.id

  # Intra-cluster communication (all ports between Databricks nodes)
  ingress {
    description = "Databricks intra-cluster"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "Databricks intra-cluster UDP"
    from_port   = 0
    to_port     = 65535
    protocol    = "udp"
    self        = true
  }

  # Egress: HTTPS to VPC endpoints + NAT for package downloads
  egress {
    description = "HTTPS outbound"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress: Databricks SCC relay
  egress {
    description = "Databricks intra-cluster"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  egress {
    description = "Databricks intra-cluster UDP"
    from_port   = 0
    to_port     = 65535
    protocol    = "udp"
    self        = true
  }

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-dbx-compute-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# =============================================================================
# AWS DIRECT CONNECT — Cross-Cloud Transit Gateway
# =============================================================================
resource "aws_dx_gateway" "cross_cloud" {
  count = var.enable_cross_cloud_transit ? 1 : 0

  name            = "${local.name_prefix}-dx-gateway"
  amazon_side_asn = var.dx_amazon_side_asn
}

resource "aws_vpn_gateway" "main" {
  count = var.enable_cross_cloud_transit ? 1 : 0

  vpc_id          = aws_vpc.main.id
  amazon_side_asn = var.dx_amazon_side_asn

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-vgw"
  })
}

resource "aws_dx_gateway_association" "main" {
  count = var.enable_cross_cloud_transit ? 1 : 0

  dx_gateway_id         = aws_dx_gateway.cross_cloud[0].id
  associated_gateway_id = aws_vpn_gateway.main[0].id

  allowed_prefixes = [var.vpc_cidr]
}

# Propagate VPN gateway routes to private subnets (for cross-cloud traffic)
resource "aws_vpn_gateway_route_propagation" "private_compute" {
  count = var.enable_cross_cloud_transit ? 2 : 0

  vpn_gateway_id = aws_vpn_gateway.main[0].id
  route_table_id = aws_route_table.private_compute[count.index].id
}

resource "aws_vpn_gateway_route_propagation" "private_data" {
  count = var.enable_cross_cloud_transit ? 2 : 0

  vpn_gateway_id = aws_vpn_gateway.main[0].id
  route_table_id = aws_route_table.private_data[count.index].id
}
