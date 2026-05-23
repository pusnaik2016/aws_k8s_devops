##############################################################################
# .tflint.hcl — TFLint configuration
# Rules for the Terraform AWS provider plugin
##############################################################################

config {
  # Enable module inspection (checks called modules, not just root)
  call_module_type = "local"

  # Force an error exit code when issues are found (required for CI)
  force = false
}

# AWS ruleset plugin
plugin "aws" {
  enabled    = true
  version    = "0.33.0"
  source     = "github.com/terraform-linters/tflint-ruleset-aws"

  # Deep check: validate against real AWS APIs (requires credentials in CI)
  # Set to false if you don't want credential-dependent checks
  deep_check = false
}

##############################################################################
# Rule configuration
##############################################################################

# Disallow deprecated resources / data sources
rule "aws_lambda_function_invalid_runtime" {
  enabled = true
}

# Require all Lambda functions to have an explicit timeout set
rule "aws_lambda_function_invalid_timeout" {
  enabled = true
}

# Disallow wildcard resources in IAM policies (we have a known exception for CE)
# rule "aws_iam_policy_document_gov_friendly_arns" {
#   enabled = true
# }

# Enforce that DynamoDB tables use PAY_PER_REQUEST or PROVISIONED explicitly
rule "aws_dynamodb_table_invalid_billing_mode" {
  enabled = true
}

# Warn on SNS topics without KMS encryption
rule "aws_sns_topic_invalid_kms_master_key_id" {
  enabled = false   # We use alias/aws/sns — this rule doesn't recognise aliases
}

# Terraform core rules
rule "terraform_deprecated_interpolation" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}

rule "terraform_required_providers" {
  enabled = true
}

rule "terraform_required_version" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}
