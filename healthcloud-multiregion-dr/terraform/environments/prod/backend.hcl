bucket         = "healthcloud-prod-terraform-state"
key            = "healthcloud/prod/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "healthcloud-prod-terraform-locks"
encrypt        = true
