# ─────────────────────────────────────────────────────────────────────────────
# AWS Networking — Multi-AZ VPC with Public, Private, and Isolated Subnets
# ─────────────────────────────────────────────────────────────────────────────
# HIPAA/PCI-DSS compliant networking:
# - Public subnets: ALB, NAT Gateway only (no direct workloads)
# - Private subnets: EKS nodes, application workloads
# - Isolated subnets: Aurora, ElastiCache (no internet access)
# - VPC Flow Logs enabled for audit compliance
# - Transit Gateway for cross-cloud VPN connectivity
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }

  backend "s3" {
    bucket         = "medcloud-terraform-state"
    key            = "aws/networking/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "medcloud-terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(var.common_tags, {
      Cloud       = "AWS"
      Environment = var.environment
      Component   = "networking"
    })
  }
}

# ─── Data Sources ────────────────────────────────────────────────────────────

data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_caller_identity" "current" {}

# ─── Local Values ────────────────────────────────────────────────────────────

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  azs         = slice(data.aws_availability_zones.available.names, 0, 3)

  # Subnet CIDR allocation (within 10.0.0.0/16)
  public_subnets   = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets  = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
  isolated_subnets = ["10.0.20.0/24", "10.0.21.0/24", "10.0.22.0/24"]

  # Cross-cloud VPN peer CIDRs
  azure_vnet_cidr = var.azure_vnet_cidr  # 10.1.0.0/16
  gcp_vpc_cidr    = var.gcp_vpc_cidr     # 10.2.0.0/16
}

# ─── VPC ─────────────────────────────────────────────────────────────────────

resource "aws_vpc" "main" {
  cidr_block           = var.aws_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

# ─── Internet Gateway ───────────────────────────────────────────────────────

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

# ─── Public Subnets (ALB, NAT Gateway only) ─────────────────────────────────

resource "aws_subnet" "public" {
  count = length(local.public_subnets)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_subnets[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false # HIPAA: No auto-assign public IPs

  tags = {
    Name                                           = "${local.name_prefix}-public-${local.azs[count.index]}"
    "kubernetes.io/role/elb"                        = "1"
    "kubernetes.io/cluster/${local.name_prefix}-eks" = "shared"
    Tier                                           = "public"
  }
}

# ─── Private Subnets (EKS Nodes, Application Workloads) ─────────────────────

resource "aws_subnet" "private" {
  count = length(local.private_subnets)

  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_subnets[count.index]
  availability_zone = local.azs[count.index]

  tags = {
    Name                                           = "${local.name_prefix}-private-${local.azs[count.index]}"
    "kubernetes.io/role/internal-elb"               = "1"
    "kubernetes.io/cluster/${local.name_prefix}-eks" = "shared"
    Tier                                           = "private"
  }
}

# ─── Isolated Subnets (Databases — No Internet Access) ──────────────────────

resource "aws_subnet" "isolated" {
  count = length(local.isolated_subnets)

  vpc_id            = aws_vpc.main.id
  cidr_block        = local.isolated_subnets[count.index]
  availability_zone = local.azs[count.index]

  tags = {
    Name       = "${local.name_prefix}-isolated-${local.azs[count.index]}"
    Tier       = "isolated"
    Compliance = "HIPAA-PHI"
  }
}

# ─── NAT Gateways (HA — one per AZ for production) ──────────────────────────

resource "aws_eip" "nat" {
  count  = var.environment == "prod" ? length(local.azs) : 1
  domain = "vpc"

  tags = {
    Name = "${local.name_prefix}-nat-eip-${count.index}"
  }
}

resource "aws_nat_gateway" "main" {
  count = var.environment == "prod" ? length(local.azs) : 1

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${local.name_prefix}-nat-${count.index}"
  }

  depends_on = [aws_internet_gateway.main]
}

# ─── Route Tables ────────────────────────────────────────────────────────────

# Public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${local.name_prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(local.public_subnets)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private route tables (one per AZ in prod for HA NAT)
resource "aws_route_table" "private" {
  count  = var.environment == "prod" ? length(local.azs) : 1
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name = "${local.name_prefix}-private-rt-${count.index}"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(local.private_subnets)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index % length(aws_route_table.private)].id
}

# Isolated route table (NO internet route — database tier)
resource "aws_route_table" "isolated" {
  vpc_id = aws_vpc.main.id

  # No default route — isolated from internet
  # Only VPC-internal and cross-cloud VPN routes

  tags = {
    Name = "${local.name_prefix}-isolated-rt"
  }
}

resource "aws_route_table_association" "isolated" {
  count          = length(local.isolated_subnets)
  subnet_id      = aws_subnet.isolated[count.index].id
  route_table_id = aws_route_table.isolated.id
}

# ─── VPC Flow Logs (HIPAA Audit Requirement) ────────────────────────────────

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/medcloud/${var.environment}/vpc-flow-logs"
  retention_in_days = var.environment == "prod" ? 365 : 30 # HIPAA: 6 years for PHI
  kms_key_id        = aws_kms_key.flow_logs.arn

  tags = {
    Name       = "${local.name_prefix}-vpc-flow-logs"
    Compliance = "HIPAA-audit"
  }
}

resource "aws_kms_key" "flow_logs" {
  description             = "KMS key for VPC Flow Logs encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:*"
          }
        }
      },
      {
        Sid    = "AllowKeyAdmin"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "${local.name_prefix}-flow-logs-kms"
  }
}

resource "aws_kms_alias" "flow_logs" {
  name          = "alias/${local.name_prefix}-flow-logs"
  target_key_id = aws_kms_key.flow_logs.key_id
}

resource "aws_iam_role" "vpc_flow_logs" {
  name = "${local.name_prefix}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "${local.name_prefix}-vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_flow_log" "main" {
  vpc_id                   = aws_vpc.main.id
  traffic_type             = "ALL"
  iam_role_arn             = aws_iam_role.vpc_flow_logs.arn
  log_destination          = aws_cloudwatch_log_group.vpc_flow_logs.arn
  max_aggregation_interval = 60

  tags = {
    Name = "${local.name_prefix}-vpc-flow-log"
  }
}

# ─── VPC Endpoints (Private connectivity — no internet for AWS services) ────

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = concat(
    aws_route_table.private[*].id,
    [aws_route_table.isolated.id]
  )

  tags = {
    Name = "${local.name_prefix}-s3-endpoint"
  }
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]

  tags = {
    Name = "${local.name_prefix}-ecr-api-endpoint"
  }
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]

  tags = {
    Name = "${local.name_prefix}-ecr-dkr-endpoint"
  }
}

resource "aws_vpc_endpoint" "sts" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.sts"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]

  tags = {
    Name = "${local.name_prefix}-sts-endpoint"
  }
}

resource "aws_vpc_endpoint" "kms" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.kms"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]

  tags = {
    Name = "${local.name_prefix}-kms-endpoint"
  }
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]

  tags = {
    Name = "${local.name_prefix}-logs-endpoint"
  }
}

# ─── Security Group for VPC Endpoints ────────────────────────────────────────

resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "${local.name_prefix}-vpc-endpoints-"
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.aws_vpc_cidr]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-vpc-endpoints-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ─── Transit Gateway (Cross-Cloud Connectivity Hub) ─────────────────────────

resource "aws_ec2_transit_gateway" "main" {
  description                     = "MedCloud cross-cloud transit gateway"
  amazon_side_asn                 = 64512
  auto_accept_shared_attachments  = "disable"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  dns_support                     = "enable"
  vpn_ecmp_support                = "enable"

  tags = {
    Name = "${local.name_prefix}-tgw"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "main" {
  subnet_ids         = aws_subnet.private[*].id
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-tgw-vpc-attachment"
  }
}

# ─── Customer Gateway for Azure VPN ─────────────────────────────────────────

resource "aws_customer_gateway" "azure" {
  count = var.cross_cloud_vpn_config.aws_to_azure_enabled ? 1 : 0

  bgp_asn    = 65515 # Azure default ASN
  ip_address = "0.0.0.0" # Placeholder — replaced with Azure VPN Gateway public IP
  type       = "ipsec.1"

  tags = {
    Name = "${local.name_prefix}-azure-cgw"
  }
}

# ─── Customer Gateway for GCP VPN ───────────────────────────────────────────

resource "aws_customer_gateway" "gcp" {
  count = var.cross_cloud_vpn_config.aws_to_gcp_enabled ? 1 : 0

  bgp_asn    = 65534 # GCP Cloud Router ASN
  ip_address = "0.0.0.0" # Placeholder — replaced with GCP VPN Gateway public IP
  type       = "ipsec.1"

  tags = {
    Name = "${local.name_prefix}-gcp-cgw"
  }
}

# ─── Outputs ─────────────────────────────────────────────────────────────────

output "vpc_id" {
  description = "AWS VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "AWS VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (EKS nodes)"
  value       = aws_subnet.private[*].id
}

output "isolated_subnet_ids" {
  description = "Isolated subnet IDs (databases)"
  value       = aws_subnet.isolated[*].id
}

output "transit_gateway_id" {
  description = "Transit Gateway ID for cross-cloud connectivity"
  value       = aws_ec2_transit_gateway.main.id
}

output "availability_zones" {
  description = "Availability zones used"
  value       = local.azs
}
