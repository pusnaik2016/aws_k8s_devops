# ─────────────────────────────────────────────────────────────
# AWS Load Balancer Controller — EKS Add-on
# ─────────────────────────────────────────────────────────────
# Manages ALB/NLB resources from within the EKS cluster
# using Kubernetes Ingress annotations.
# ─────────────────────────────────────────────────────────────

resource "aws_iam_role" "alb_controller" {
  name = "${local.cluster_name}-alb-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = local.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_provider_url}:aud" = "sts.amazonaws.com"
            "${local.oidc_provider_url}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "alb_controller" {
  name = "alb-controller-policy"
  role = aws_iam_role.alb_controller.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:CreateSecurityGroup",
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "ec2:DeleteSecurityGroup",
          "elasticloadbalancing:*",
          "iam:CreateServiceLinkedRole",
          "cognito-idp:DescribeUserPoolClient",
          "acm:ListCertificates",
          "acm:DescribeCertificate",
          "waf-regional:*",
          "wafv2:*",
          "shield:*",
          "tag:GetResources",
          "tag:TagResources"
        ]
        Resource = "*"
      }
    ]
  })
}
