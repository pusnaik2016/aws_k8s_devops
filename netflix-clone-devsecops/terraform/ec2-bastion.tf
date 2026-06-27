# ==============================================================================
# EC2 Instance — Bastion Host for Private EKS Access
# ==============================================================================
# Lightweight bastion host for kubectl access to the private EKS cluster.
# ==============================================================================

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.bastion_instance_type
  key_name               = var.key_pair_name
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.bastion.id]

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name = "${var.project_name}-bastion-root-volume"
    }
  }

  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail
    echo "=========================================="
    echo "  Bastion Host Setup — Started $(date)"
    echo "=========================================="

    # --- System Update ---
    sudo apt-get update -y && sudo apt-get upgrade -y

    # --- AWS CLI v2 ---
    echo "[1/3] Installing AWS CLI v2..."
    curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    sudo apt-get install -y unzip
    sudo unzip -q -o awscliv2.zip
    sudo ./aws/install --update
    rm -rf awscliv2.zip aws/
    aws --version

    # --- kubectl ---
    echo "[2/3] Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm -f kubectl
    kubectl version --client

    # --- Helm ---
    echo "[3/3] Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

    echo "=========================================="
    echo "  Bastion Host Setup Complete — $(date)"
    echo "=========================================="
    echo "  Configure kubectl:"
    echo "    aws eks update-kubeconfig --region us-east-1 --name ${var.project_name}-eks"
    echo "  Verify:"
    echo "    kubectl get nodes"
    echo "=========================================="
  EOF

  tags = {
    Name = "${var.project_name}-bastion"
    Role = "bastion"
  }
}
