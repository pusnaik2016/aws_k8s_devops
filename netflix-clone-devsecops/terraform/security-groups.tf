# ==============================================================================
# Security Groups — Netflix Clone DevSecOps (GitHub Actions + EKS)
# ==============================================================================
# Defines firewall rules for each component. Each security group follows
# the principle of least privilege.
#
# Key difference from Java project: EKS nodes accept port 80 (Nginx)
# instead of port 8080 (Spring Boot).
# ==============================================================================

# =============================================================================
# 1. Bastion Security Group — kubectl access to private EKS
# =============================================================================
resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-bastion-sg"
  description = "Security group for bastion host — SSH access for kubectl to private EKS"
  vpc_id      = aws_vpc.devsecops_vpc.id

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

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
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Security group for Application Load Balancer — internet-facing"
  vpc_id      = aws_vpc.devsecops_vpc.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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
resource "aws_security_group" "eks_cluster" {
  name        = "${var.project_name}-eks-cluster-sg"
  description = "Security group for EKS control plane — private API endpoint"
  vpc_id      = aws_vpc.devsecops_vpc.id

  ingress {
    description = "HTTPS from VPC (worker nodes and bastion kubectl)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

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
# Key difference: Port 80 (Nginx) instead of 8080 (Spring Boot)
# =============================================================================
resource "aws_security_group" "eks_nodes" {
  name        = "${var.project_name}-eks-nodes-sg"
  description = "Security group for EKS worker nodes — private subnets only"
  vpc_id      = aws_vpc.devsecops_vpc.id

  # Application traffic from ALB (port 80 — Nginx serving React app)
  ingress {
    description     = "Application traffic from ALB (Nginx port 80)"
    from_port       = 80
    to_port         = 80
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

  # CoreDNS from within the cluster
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

  # Prometheus metrics scraping (port 9090, 9093, 3000)
  ingress {
    description = "Prometheus and Grafana ports"
    from_port   = 3000
    to_port     = 9093
    protocol    = "tcp"
    self        = true
  }

  # All outbound
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name                                            = "${var.project_name}-eks-nodes-sg"
    "kubernetes.io/cluster/${var.project_name}-eks" = "owned"
  }
}
