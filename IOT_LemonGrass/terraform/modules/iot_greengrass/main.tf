# -----------------------------------------------------------------------------
# IoT Greengrass Module — TES Role Alias & Component Management
# -----------------------------------------------------------------------------
# This module creates:
# 1. IoT Role Alias → maps TES requests to the IAM role
# 2. Greengrass v2 component version registration
# 3. Greengrass deployment targeting the Thing Group
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# IoT Role Alias — Token Exchange Service (TES)
# Greengrass Nucleus uses this to acquire temporary AWS credentials
# Flow: Device → MQTT → TES → STS:AssumeRole → Temporary Credentials
# -----------------------------------------------------------------------------
resource "aws_iot_role_alias" "greengrass_tes" {
  alias               = "${var.project_name}-GreengrassTESAlias"
  role_arn            = var.greengrass_tes_role_arn
  credential_duration = 3600 # 1 hour (default, max 12 hours)
}

# -----------------------------------------------------------------------------
# IoT Policy for TES — Allow devices to assume the role alias
# -----------------------------------------------------------------------------
resource "aws_iot_policy" "tes_policy" {
  name = "${var.project_name}-tes-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "iot:AssumeRoleWithCertificate"
      Resource = aws_iot_role_alias.greengrass_tes.arn
    }]
  })
}

# Attach TES policy to all device certificates
resource "aws_iot_policy_attachment" "tes_policy_attach" {
  for_each = var.certificate_arns

  policy = aws_iot_policy.tes_policy.name
  target = each.value
}

# -----------------------------------------------------------------------------
# Greengrass Core Device Configuration
# Note: The actual Greengrass Nucleus installation happens on the edge
# device. These resources register the cloud-side configuration.
# -----------------------------------------------------------------------------

# CloudWatch Log Group for Greengrass components
resource "aws_cloudwatch_log_group" "greengrass" {
  name              = "/aws/greengrass/${var.project_name}"
  retention_in_days = 30
  kms_key_id        = var.kms_key_arn

  tags = {
    Name = "${var.project_name}-greengrass-logs"
  }
}
