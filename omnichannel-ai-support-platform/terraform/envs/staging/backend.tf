terraform {
  backend "s3" {
    bucket         = "omnipresense-ai-terraform-state"
    key            = "staging/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "omnipresense-ai-terraform-locks"
    encrypt        = true
  }
}
