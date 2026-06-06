# ==============================================================================
# Karpenter — Elastic Node Autoscaling (Primary Region)
# ==============================================================================
# Karpenter automatically provisions right-sized EC2 instances based on
# pending pod requirements. Replaces Cluster Autoscaler with faster,
# smarter scaling decisions.
# ==============================================================================

# =============================================================================
# Karpenter IAM Role (IRSA)
# =============================================================================
resource "aws_iam_role" "karpenter_controller" {
  name = "${var.project_name}-karpenter-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = module.eks.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${module.eks.oidc_provider_url}:aud" = "sts.amazonaws.com"
          "${module.eks.oidc_provider_url}:sub" = "system:serviceaccount:kube-system:karpenter"
        }
      }
    }]
  })

  tags = merge(local.common_tags, { Name = "${var.project_name}-karpenter-controller" })
}

resource "aws_iam_role_policy" "karpenter_controller" {
  name = "${var.project_name}-karpenter-policy"
  role = aws_iam_role.karpenter_controller.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateLaunchTemplate", "ec2:CreateFleet",
          "ec2:RunInstances", "ec2:CreateTags",
          "ec2:TerminateInstances", "ec2:DeleteLaunchTemplate",
          "ec2:DescribeLaunchTemplates", "ec2:DescribeInstances",
          "ec2:DescribeSecurityGroups", "ec2:DescribeSubnets",
          "ec2:DescribeImages", "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeAvailabilityZones", "ec2:DescribeSpotPriceHistory",
          "ssm:GetParameter", "pricing:GetProducts",
          "ec2:DescribeImages"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = aws_iam_role.karpenter_node.arn
      },
      {
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster"]
        Resource = module.eks.cluster_arn
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:DeleteMessage", "sqs:GetQueueUrl",
          "sqs:GetQueueAttributes", "sqs:ReceiveMessage"
        ]
        Resource = aws_sqs_queue.karpenter_interruption.arn
      }
    ]
  })
}

# =============================================================================
# Karpenter Node IAM Role + Instance Profile
# =============================================================================
resource "aws_iam_role" "karpenter_node" {
  name = "${var.project_name}-karpenter-node"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(local.common_tags, { Name = "${var.project_name}-karpenter-node" })
}

resource "aws_iam_role_policy_attachment" "karpenter_node_worker" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.karpenter_node.name
}

resource "aws_iam_role_policy_attachment" "karpenter_node_cni" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.karpenter_node.name
}

resource "aws_iam_role_policy_attachment" "karpenter_node_ecr" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.karpenter_node.name
}

resource "aws_iam_role_policy_attachment" "karpenter_node_ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.karpenter_node.name
}

resource "aws_iam_instance_profile" "karpenter_node" {
  name = "${var.project_name}-karpenter-node-profile"
  role = aws_iam_role.karpenter_node.name

  tags = merge(local.common_tags, { Name = "${var.project_name}-karpenter-node-profile" })
}

# EKS Access Entry for Karpenter nodes
resource "aws_eks_access_entry" "karpenter_node" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.karpenter_node.arn
  type          = "EC2_LINUX"
}

# =============================================================================
# SQS Queue — Spot Interruption Handling (KMS-encrypted)
# =============================================================================
resource "aws_sqs_queue" "karpenter_interruption" {
  name                       = "${var.project_name}-karpenter-interruption"
  message_retention_seconds  = 300
  sqs_managed_sse_enabled    = false
  kms_master_key_id          = module.kms.sqs_key_id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-karpenter-interruption-queue"
  })
}

resource "aws_sqs_queue_policy" "karpenter_interruption" {
  queue_url = aws_sqs_queue.karpenter_interruption.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = ["events.amazonaws.com", "sqs.amazonaws.com"] }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.karpenter_interruption.arn
    }]
  })
}

# EventBridge Rules → SQS for interruption events
resource "aws_cloudwatch_event_rule" "spot_interruption" {
  name = "${var.project_name}-spot-interruption"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Spot Instance Interruption Warning"]
  })

  tags = merge(local.common_tags, { Name = "${var.project_name}-spot-interruption-rule" })
}

resource "aws_cloudwatch_event_target" "spot_interruption" {
  rule      = aws_cloudwatch_event_rule.spot_interruption.name
  target_id = "karpenter-interruption"
  arn       = aws_sqs_queue.karpenter_interruption.arn
}

resource "aws_cloudwatch_event_rule" "instance_rebalance" {
  name = "${var.project_name}-instance-rebalance"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance Rebalance Recommendation"]
  })

  tags = merge(local.common_tags, { Name = "${var.project_name}-rebalance-rule" })
}

resource "aws_cloudwatch_event_target" "instance_rebalance" {
  rule      = aws_cloudwatch_event_rule.instance_rebalance.name
  target_id = "karpenter-rebalance"
  arn       = aws_sqs_queue.karpenter_interruption.arn
}

# =============================================================================
# Karpenter Helm Release
# =============================================================================
resource "helm_release" "karpenter" {
  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  namespace  = "kube-system"
  version    = "1.0.6"

  set { name = "settings.clusterName"; value = module.eks.cluster_name }
  set { name = "settings.clusterEndpoint"; value = module.eks.cluster_endpoint }
  set { name = "settings.interruptionQueue"; value = aws_sqs_queue.karpenter_interruption.name }
  set { name = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"; value = aws_iam_role.karpenter_controller.arn }
  set { name = "replicas"; value = "2" }

  depends_on = [module.eks]
}
