bucket         = "medcloud-terraform-state-staging"
key            = "staging/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "medcloud-terraform-locks-staging"
