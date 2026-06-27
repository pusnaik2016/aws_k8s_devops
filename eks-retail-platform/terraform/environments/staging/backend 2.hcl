bucket         = "eks-retail-terraform-state"
key            = "staging/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "eks-retail-terraform-locks"
