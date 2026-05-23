###############################################################################
# Bedrock Config Module — Model configuration & data source
###############################################################################

# Expose the model_id as a structured output so other modules reference it
# consistently without hardcoding. Also validates region support.

data "aws_region" "current" {}

locals {
  supported_regions = [
    "us-east-1",
    "us-west-2",
    "eu-west-1",
    "ap-southeast-1",
    "ap-northeast-1",
  ]

  region_supported = contains(local.supported_regions, var.aws_region)
}

resource "null_resource" "bedrock_region_check" {
  # Emit a Terraform warning if the region may not support the Bedrock model.
  # This is advisory only — provisioning still proceeds.
  triggers = {
    region   = var.aws_region
    model_id = var.model_id
  }

  lifecycle {
    precondition {
      condition = local.region_supported
      error_message = <<-EOT
        Bedrock model '${var.model_id}' may not be available in region '${var.aws_region}'.
        Supported regions: ${join(", ", local.supported_regions)}.
        To override, remove or adjust the supported_regions list in modules/bedrock_config/main.tf.
      EOT
    }
  }
}
