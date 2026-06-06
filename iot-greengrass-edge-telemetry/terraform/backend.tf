# -----------------------------------------------------------------------------
# Remote State Backend — S3 + DynamoDB Locking
# -----------------------------------------------------------------------------
terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket         = "iot-greengrass-terraform-state"
    key            = "iot-greengrass/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock"
    encrypt        = true
  }
}
