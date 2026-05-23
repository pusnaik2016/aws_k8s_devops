# ==============================================================================
# Secondary Region — Provider Configuration (ap-south-1)
# ==============================================================================
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws        = { source = "hashicorp/aws", version = "~> 5.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.27" }
    helm       = { source = "hashicorp/helm", version = "~> 2.12" }
    tls        = { source = "hashicorp/tls", version = "~> 4.0" }
    kubectl    = { source = "alekc/kubectl", version = "~> 2.0" }
  }

  backend "s3" {
    bucket         = "eks-devsecops-tfstate-secondary"
    key            = "secondary/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "eks-devsecops-tfstate-lock"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project            = var.project_name
      Environment        = var.environment
      Region             = var.aws_region
      ManagedBy          = "terraform"
      Owner              = var.owner_email
      CostCenter         = var.cost_center
      DataClassification = "confidential"
      Compliance         = "PCI-HIPAA-SOC2"
      DR_Tier            = "tier-1"
      BackupPolicy       = "daily"
      CreatedBy          = "devsecops-pipeline"
    }
  }
}

data "aws_eks_cluster_auth" "main" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority)
  token                  = data.aws_eks_cluster_auth.main.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority)
    token                  = data.aws_eks_cluster_auth.main.token
  }
}

provider "kubectl" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority)
  token                  = data.aws_eks_cluster_auth.main.token
  load_config_file       = false
}
