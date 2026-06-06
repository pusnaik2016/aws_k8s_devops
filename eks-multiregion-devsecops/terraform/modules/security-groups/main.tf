# ==============================================================================
# Security Groups Module — Least-Privilege Firewall Rules
# ==============================================================================

# =============================================================================
# Bastion SG — kubectl access to private EKS
# =============================================================================
resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-bastion-sg"
  description = "Bastion host — SSH for kubectl to private EKS"
  vpc_id      = var.vpc_id

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

  tags = merge(var.tags, { Name = "${var.project_name}-bastion-sg" })
}

# =============================================================================
# ALB SG — Internet-facing load balancer
# =============================================================================
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "ALB — HTTP/HTTPS from internet"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Outbound to VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(var.tags, { Name = "${var.project_name}-alb-sg" })
}

# =============================================================================
# EKS Cluster SG — Control plane ENIs
# =============================================================================
resource "aws_security_group" "eks_cluster" {
  name        = "${var.project_name}-eks-cluster-sg"
  description = "EKS control plane — private API endpoint"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from VPC"
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

  tags = merge(var.tags, { Name = "${var.project_name}-eks-cluster-sg" })
}

# =============================================================================
# EKS Nodes SG — Worker nodes in private subnets
# =============================================================================
resource "aws_security_group" "eks_nodes" {
  name        = "${var.project_name}-eks-nodes-sg"
  description = "EKS worker nodes — private subnets only"
  vpc_id      = var.vpc_id

  # Application traffic from ALB
  ingress {
    description     = "App traffic from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Kubelet API from control plane
  ingress {
    description     = "Kubelet from control plane"
    from_port       = 10250
    to_port         = 10250
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster.id]
  }

  # CoreDNS
  ingress {
    description = "CoreDNS TCP"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "CoreDNS UDP"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    self        = true
  }

  # Inter-node pod communication
  ingress {
    description = "Inter-node pod traffic"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  # Webhook admission controllers (443 from control plane)
  ingress {
    description     = "Webhook admission from control plane"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster.id]
  }

  # Karpenter webhook
  ingress {
    description     = "Karpenter webhook"
    from_port       = 8443
    to_port         = 8443
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name                                             = "${var.project_name}-eks-nodes-sg"
    "kubernetes.io/cluster/${var.project_name}-eks"   = "owned"
    "karpenter.sh/discovery"                         = "${var.project_name}-eks"
  })
}

# =============================================================================
# Aurora SG — Database access from EKS nodes only
# =============================================================================
resource "aws_security_group" "aurora" {
  name        = "${var.project_name}-aurora-sg"
  description = "Aurora DB — access from EKS nodes only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from EKS nodes"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  # Allow from bastion for DB admin
  ingress {
    description     = "MySQL from bastion"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.project_name}-aurora-sg" })
}
