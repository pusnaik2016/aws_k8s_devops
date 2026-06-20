bucket         = "healthcloud-staging-terraform-state"
key            = "healthcloud/staging/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "healthcloud-staging-terraform-locks"
encrypt        = true
