terraform {
  backend "s3" {
    bucket         = "agentcore-memory-tfstate-REPLACE_WITH_ACCOUNT_ID"
    key            = "agentcore-memory/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "agentcore-memory-tfstate-lock"
    encrypt        = true
  }
}
