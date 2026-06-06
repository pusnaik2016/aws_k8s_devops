# -----------------------------------------------------------------------------
# OpenSearch Serverless — Vector search collection for RAG embeddings
# -----------------------------------------------------------------------------

resource "aws_opensearchserverless_security_policy" "encryption" {
  name = "${var.project_name}-enc"
  type = "encryption"

  policy = jsonencode({
    Rules = [
      {
        ResourceType = "collection"
        Resource     = ["collection/${var.project_name}-vectors"]
      }
    ]
    AWSOwnedKey = true
  })
}

resource "aws_opensearchserverless_security_policy" "network" {
  name = "${var.project_name}-net"
  type = "network"

  policy = jsonencode([
    {
      Description = "VPC access for ${var.project_name}"
      Rules = [
        {
          ResourceType = "collection"
          Resource     = ["collection/${var.project_name}-vectors"]
        },
        {
          ResourceType = "dashboard"
          Resource     = ["collection/${var.project_name}-vectors"]
        }
      ]
      AllowFromPublic = false
      SourceVPCEs     = [aws_opensearchserverless_vpc_endpoint.main.id]
    }
  ])
}

resource "aws_opensearchserverless_vpc_endpoint" "main" {
  name               = "${var.project_name}-vpce"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = [var.sg_id]
}

resource "aws_opensearchserverless_collection" "vectors" {
  name             = "${var.project_name}-vectors"
  type             = "VECTORSEARCH"
  standby_replicas = var.environment == "prod" ? "ENABLED" : "DISABLED"

  depends_on = [
    aws_opensearchserverless_security_policy.encryption,
    aws_opensearchserverless_security_policy.network
  ]
}

# Data access policy — allow Lambda role to read/write
resource "aws_opensearchserverless_access_policy" "data" {
  name = "${var.project_name}-data"
  type = "data"

  policy = jsonencode([
    {
      Description = "Lambda access to vector collection"
      Rules = [
        {
          ResourceType = "index"
          Resource     = ["index/${var.project_name}-vectors/*"]
          Permission   = ["aoss:CreateIndex", "aoss:ReadDocument", "aoss:WriteDocument", "aoss:UpdateIndex", "aoss:DescribeIndex"]
        },
        {
          ResourceType = "collection"
          Resource     = ["collection/${var.project_name}-vectors"]
          Permission   = ["aoss:DescribeCollectionItems"]
        }
      ]
      Principal = ["*"]
    }
  ])
}
