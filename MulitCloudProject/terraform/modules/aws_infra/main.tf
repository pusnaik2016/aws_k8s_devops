# =============================================================================
# AWS INFRASTRUCTURE MODULE — Primary Active Site
# =============================================================================

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  account_id  = data.aws_caller_identity.current.account_id

  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  tags = merge(var.common_tags, {
    Module = "aws_infra"
    Cloud  = "aws"
  })
}
