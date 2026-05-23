# ==============================================================================
# EC2 Instance — Bastion Host for Private EKS Access
# ==============================================================================
# Lightweight bastion host for kubectl access to the private EKS cluster.
# The EKS API endpoint is private-only (not reachable from internet),
# so all kubectl commands must run from within the VPC.
#
# This bastion replaces the Jenkins EC2 as the kubectl access point.
# It runs a minimal install: AWS CLI v2 + kubectl only.
#
# Cost optimization:
#   - t3.micro (~$8/month) — smallest general-purpose instance
#   - Stop when not in use ($0 when stopped)
#   - No application workloads — purely for admin access
#
# Usage:
#   ssh -i ~/.ssh/key.pem ubuntu@<BASTION_IP>
#   aws eks update-kubeconfig --region us-east-1 --name java-devsecops-eks
#   kubectl get pods -n boardgame
# ==============================================================================

# -----------------------------------------------------------------------------
# Data source: Latest Ubuntu 22.04 LTS AMI
# Using a data source ensures we always get the latest patched AMI
# -----------------------------------------------------------------------------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]    # Canonical's official AWS account ID

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# =============================================================================
# Bastion EC2 Instance
# =============================================================================
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.bastion_instance_type
  key_name               = var.key_pair_name
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.bastion.id]

  # Minimal 8GB root volume — only CLI tools, no builds
  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name = "${var.project_name}-bastion-root-volume"
    }
  }

  # Bootstrap script: Install AWS CLI v2 + kubectl
  user_data = <<-EOF
    #!/bin/bash
    # ==================================================================
    # Bastion Host Bootstrap — AWS CLI v2 + kubectl
    # ==================================================================
    # Minimal tooling for private EKS cluster administration.
    # Logs: /var/log/cloud-init-output.log
    # ==================================================================
    set -euo pipefail
    echo "=========================================="
    echo "  Bastion Host Setup — Started $(date)"
    echo "=========================================="

    # --- System Update ---
    sudo apt-get update -y && sudo apt-get upgrade -y

    # --- AWS CLI v2 ---
    # Required for:
    #   - aws eks update-kubeconfig (configure kubectl)
    #   - aws ecr get-login-password (if manual image ops needed)
    echo "[1/3] Installing AWS CLI v2..."
    curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    sudo apt-get install -y unzip
    sudo unzip -q -o awscliv2.zip
    sudo ./aws/install --update
    rm -rf awscliv2.zip aws/
    aws --version

    # --- kubectl ---
    # Required for:
    #   - kubectl get pods/nodes/services
    #   - kubectl apply -f (initial ArgoCD setup)
    #   - kubectl logs (debugging)
    echo "[2/3] Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm -f kubectl
    kubectl version --client

    # --- Helm ---
    # Required for manual chart operations if needed
    echo "[3/3] Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

    echo "=========================================="
    echo "  Bastion Host Setup Complete — $(date)"
    echo "=========================================="
    echo "  Configure kubectl:"
    echo "    aws eks update-kubeconfig --region us-east-1 --name java-devsecops-eks"
    echo "  Verify:"
    echo "    kubectl get nodes"
    echo "=========================================="
  EOF

  tags = {
    Name = "${var.project_name}-bastion"
    Role = "bastion"
  }
}
