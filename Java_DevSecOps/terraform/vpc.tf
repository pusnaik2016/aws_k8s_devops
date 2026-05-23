# ==============================================================================
# VPC & Networking — Production Multi-AZ Architecture
# ==============================================================================
# Creates a production-grade VPC spanning 3 Availability Zones with:
#
#   Public Subnets (3):
#     - ALB (Application Load Balancer) placement
#     - NAT Gateways for private subnet egress
#     - Bastion host for kubectl access to private EKS
#     - Tagged with kubernetes.io/role/elb for EKS ALB discovery
#
#   Private Subnets (3):
#     - EKS worker nodes (no public IPs, no direct internet access)
#     - All application pods run here
#     - Tagged with kubernetes.io/role/internal-elb for internal LBs
#
#   NAT Gateways:
#     - Configurable: 1 shared (cost saving) or 3 per-AZ (HA)
#     - Provides internet egress for private subnets (pulling images, etc.)
#
#   VPC Endpoints (PrivateLink):
#     - ECR API, ECR DKR, S3, STS, CloudWatch Logs, EKS
#     - Allows private EKS nodes to reach AWS services without NAT traversal
#     - Reduces NAT Gateway data transfer costs and improves security
#
# Security:
#     - EKS nodes have NO public IPs
#     - EKS API endpoint is PRIVATE ONLY
#     - All AWS service calls from EKS go through VPC Endpoints
# ==============================================================================

# =============================================================================
# VPC — The isolated virtual network for all DevSecOps resources
# =============================================================================
resource "aws_vpc" "devsecops_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true    # Required for VPC Endpoints and EKS
  enable_dns_hostnames = true    # Required for EKS node registration

  tags = {
    Name                                        = "${var.project_name}-vpc"
    "kubernetes.io/cluster/${var.project_name}-eks" = "shared"
  }
}

# =============================================================================
# Public Subnets — One per AZ for ALB, NAT Gateways, and CI tools
# =============================================================================
# Public subnets host internet-facing resources. EKS ALB Controller uses
# the kubernetes.io/role/elb tag to discover these subnets for placing
# internet-facing Application Load Balancers.
# =============================================================================
resource "aws_subnet" "public" {
  count = length(var.availability_zones)

  vpc_id                  = aws_vpc.devsecops_vpc.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true    # EC2 instances get public IPs automatically

  tags = {
    Name                                        = "${var.project_name}-public-${var.availability_zones[count.index]}"
    "kubernetes.io/role/elb"                     = "1"
    "kubernetes.io/cluster/${var.project_name}-eks" = "shared"
    Tier                                        = "public"
  }
}

# =============================================================================
# Private Subnets — One per AZ for EKS worker nodes (NO public IPs)
# =============================================================================
# Private subnets host the EKS managed node groups. Nodes have no public IPs
# and access the internet only through NAT Gateways. The internal-elb tag
# tells the ALB Controller to use these subnets for internal load balancers.
# =============================================================================
resource "aws_subnet" "private" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.devsecops_vpc.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name                                        = "${var.project_name}-private-${var.availability_zones[count.index]}"
    "kubernetes.io/role/internal-elb"            = "1"
    "kubernetes.io/cluster/${var.project_name}-eks" = "shared"
    Tier                                        = "private"
  }
}

# =============================================================================
# Internet Gateway — Provides outbound internet access for public subnets
# =============================================================================
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.devsecops_vpc.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# =============================================================================
# Elastic IPs — Static IPs for NAT Gateways
# =============================================================================
# Each NAT Gateway needs a dedicated Elastic IP. The count is determined
# by whether we're using a single NAT Gateway (cost saving) or one per AZ (HA).
# =============================================================================
resource "aws_eip" "nat" {
  count  = var.single_nat_gateway ? 1 : length(var.availability_zones)
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.igw]
}

# =============================================================================
# NAT Gateways — Provide internet egress for private subnets
# =============================================================================
# NAT Gateways allow EKS nodes in private subnets to pull Docker images,
# download packages, and communicate with external services.
#
# Configuration:
#   single_nat_gateway = true  → 1 NAT GW (~$32/month) — development/cost saving
#   single_nat_gateway = false → 3 NAT GWs (~$96/month) — production/HA
# =============================================================================
resource "aws_nat_gateway" "nat" {
  count = var.single_nat_gateway ? 1 : length(var.availability_zones)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.project_name}-nat-gw-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.igw]
}

# =============================================================================
# Public Route Table — Routes internet-bound traffic through the IGW
# =============================================================================
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.devsecops_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Associate each public subnet with the public route table
resource "aws_route_table_association" "public" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# =============================================================================
# Private Route Tables — Route internet-bound traffic through NAT Gateways
# =============================================================================
# Each private subnet routes through its own NAT Gateway (HA mode) or
# through a single shared NAT Gateway (cost saving mode).
# =============================================================================
resource "aws_route_table" "private" {
  count = var.single_nat_gateway ? 1 : length(var.availability_zones)

  vpc_id = aws_vpc.devsecops_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }

  tags = {
    Name = "${var.project_name}-private-rt-${count.index + 1}"
  }
}

# Associate each private subnet with its corresponding private route table
resource "aws_route_table_association" "private" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[var.single_nat_gateway ? 0 : count.index].id
}

# =============================================================================
# VPC Endpoints (PrivateLink) — Private connectivity to AWS services
# =============================================================================
# VPC Endpoints allow EKS nodes in private subnets to communicate with AWS
# services (ECR, S3, STS, CloudWatch, EKS) without routing through NAT
# Gateways. This improves security (traffic stays on AWS backbone) and
# reduces NAT Gateway data transfer costs.
#
# Two types of endpoints:
#   Interface Endpoints: Create ENIs in subnets (ECR, STS, CloudWatch, EKS)
#   Gateway Endpoints:   Route table entries (S3 — free, no per-hour charge)
# =============================================================================

# Security Group for VPC Endpoints — allows HTTPS traffic from VPC CIDR
resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.project_name}-vpc-endpoints-sg"
  description = "Security group for VPC Interface Endpoints — allows HTTPS from VPC"
  vpc_id      = aws_vpc.devsecops_vpc.id

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

  tags = {
    Name = "${var.project_name}-vpc-endpoints-sg"
  }
}

# --- ECR API Endpoint (Interface) ---
# Allows EKS to make ECR API calls (e.g., describe repositories, get auth tokens)
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.devsecops_vpc.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project_name}-ecr-api-endpoint"
  }
}

# --- ECR Docker Registry Endpoint (Interface) ---
# Allows EKS to pull container images from ECR via Docker protocol
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.devsecops_vpc.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project_name}-ecr-dkr-endpoint"
  }
}

# --- S3 Gateway Endpoint (FREE — no per-hour charge) ---
# ECR stores container image layers in S3. This gateway endpoint allows
# private nodes to download those layers without NAT, and it's free.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.devsecops_vpc.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.private[*].id

  tags = {
    Name = "${var.project_name}-s3-endpoint"
  }
}

# --- STS Endpoint (Interface) ---
# Required for IRSA (IAM Roles for Service Accounts). Pods exchange
# Kubernetes service account tokens for temporary AWS credentials via STS.
resource "aws_vpc_endpoint" "sts" {
  vpc_id              = aws_vpc.devsecops_vpc.id
  service_name        = "com.amazonaws.${var.aws_region}.sts"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project_name}-sts-endpoint"
  }
}

# --- CloudWatch Logs Endpoint (Interface) ---
# Allows EKS nodes and pods to ship logs to CloudWatch without NAT
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.devsecops_vpc.id
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project_name}-logs-endpoint"
  }
}

# --- EKS Endpoint (Interface) ---
# Allows private worker nodes to communicate with the EKS control plane
# API server without routing through the public internet
resource "aws_vpc_endpoint" "eks" {
  vpc_id              = aws_vpc.devsecops_vpc.id
  service_name        = "com.amazonaws.${var.aws_region}.eks"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project_name}-eks-endpoint"
  }
}
