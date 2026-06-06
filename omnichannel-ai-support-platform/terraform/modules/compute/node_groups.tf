# ─────────────────────────────────────────────────────────────
# EKS Managed Node Groups — Graviton (ARM64)
# ─────────────────────────────────────────────────────────────

resource "aws_launch_template" "eks_nodes" {
  name_prefix = "${local.cluster_name}-nodes-"

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 50
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # IMDSv2 enforced
    http_put_response_hop_limit = 2
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = "${local.cluster_name}-node"
    })
  }

  tags = local.common_tags
}

resource "aws_eks_node_group" "general" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${local.cluster_name}-general"
  node_role_arn   = var.eks_node_group_role_arn
  subnet_ids      = var.private_subnet_ids

  instance_types = var.node_instance_types
  capacity_type  = "ON_DEMAND"

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = 1
  }

  launch_template {
    id      = aws_launch_template.eks_nodes.id
    version = "$Latest"
  }

  labels = {
    role        = "general"
    environment = var.environment
  }

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-general-nodegroup"
  })

  depends_on = [aws_eks_cluster.main]
}
