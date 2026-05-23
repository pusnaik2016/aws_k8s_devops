# ==============================================================================
# Security Groups — Production Architecture (GitHub Actions + EKS)
# ==============================================================================
# Defines firewall rules for each component. Each security group follows
# the principle of least privilege — only the minimum required ports are open.
#
# Security Groups:
#   1. Bastion SG       — kubectl access point (SSH only)
#   2. ALB SG           — Application Load Balancer (HTTP/HTTPS from internet)
#   3. EKS Cluster SG   — EKS control plane ENIs (private)
#   4. EKS Node SG      — Worker nodes (traffic from ALB + control plane)
#   5. VPC Endpoints SG — Defined in vpc.tf
#
# Note: Jenkins and SonarQube security groups removed — CI/CD now runs on
# GitHub Actions (hosted runners) and SAST uses SonarCloud (SaaS).
# ==============================================================================

# =============================================================================
# 1. Bastion Security Group — kubectl access to private EKS
# =============================================================================
# Minimal security group for the bastion host. Only SSH access is allowed
# inbound. All outbound is allowed for kubectl API calls to EKS.
# =============================================================================
resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-bastion-sg"
  description = "Security group for bastion host — SSH access for kubectl to private EKS"
  vpc_id      = aws_vpc.devsecops_vpc.id

  # SSH access for administration
  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  # All outbound — needed for kubectl to EKS API, AWS CLI calls
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-bastion-sg"
  }
}

# =============================================================================
# 2. ALB Security Group — Internet-facing load balancer
# =============================================================================
# Only allows HTTP (80) and HTTPS (443) from the internet.
# All other ports are blocked. ALB forwards traffic to EKS nodes.
# =============================================================================
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Security group for Application Load Balancer — internet-facing"
  vpc_id      = aws_vpc.devsecops_vpc.id

  # HTTP from internet (redirected to HTTPS by ALB listener)
  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS from internet
  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound to EKS nodes
  egress {
    description = "Allow all outbound to VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

# =============================================================================
# 3. EKS Cluster Security Group — Control plane ENIs (private)
# =============================================================================
# Controls traffic to/from the EKS control plane's elastic network interfaces
# in private subnets. The control plane communicates with worker nodes
# on port 443 (kubelet API) and 10250 (metrics).
# =============================================================================
resource "aws_security_group" "eks_cluster" {
  name        = "${var.project_name}-eks-cluster-sg"
  description = "Security group for EKS control plane — private API endpoint"
  vpc_id      = aws_vpc.devsecops_vpc.id

  # Allow HTTPS from worker nodes and bastion (kubectl)
  ingress {
    description = "HTTPS from VPC (worker nodes and bastion kubectl)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Outbound to worker nodes
  egress {
    description = "All outbound to VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name = "${var.project_name}-eks-cluster-sg"
  }
}

# =============================================================================
# 4. EKS Node Security Group — Worker nodes in private subnets
# =============================================================================
# Worker nodes accept traffic from:
#   - ALB (application traffic on pod ports)
#   - EKS control plane (kubelet management on 10250)
#   - Other nodes (inter-pod communication)
#
# Nodes have NO public IPs and NO direct internet ingress.
# =============================================================================
resource "aws_security_group" "eks_nodes" {
  name        = "${var.project_name}-eks-nodes-sg"
  description = "Security group for EKS worker nodes — private subnets only"
  vpc_id      = aws_vpc.devsecops_vpc.id

  # Application traffic from ALB (port 8080 — Spring Boot app)
  ingress {
    description     = "Application traffic from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Kubelet API from EKS control plane
  ingress {
    description     = "Kubelet API from control plane"
    from_port       = 10250
    to_port         = 10250
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster.id]
  }

  # CoreDNS from within the cluster (UDP and TCP port 53)
  ingress {
    description = "CoreDNS — cluster DNS (TCP)"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "CoreDNS — cluster DNS (UDP)"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    self        = true
  }

  # Inter-node communication (pod-to-pod across nodes)
  ingress {
    description = "Inter-node pod communication"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  # All outbound — pulling images via VPC Endpoint/NAT, DNS, etc.
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name                                            = "${var.project_name}-eks-nodes-sg"
    "kubernetes.io/cluster/${var.project_name}-eks"  = "owned"
  }
}
