# -----------------------------------------------------------------------------
# IoT Core Module — Things, Certificates, Policies, Thing Groups
# -----------------------------------------------------------------------------
# This module provisions the AWS IoT Core resources required for each
# customer site's Greengrass core device:
#   - IoT Thing Type (categorize devices)
#   - IoT Thing Group (fleet management)
#   - IoT Thing per customer site
#   - X.509 Certificate per device (mutual TLS authentication)
#   - IoT Policy (least-privilege MQTT permissions)
#   - Certificate ↔ Policy and Certificate ↔ Thing attachments
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Data Source — IoT Endpoint
# -----------------------------------------------------------------------------
data "aws_iot_endpoint" "ats" {
  endpoint_type = "iot:Data-ATS"
}

# -----------------------------------------------------------------------------
# IoT Thing Type — Categorize Greengrass Core Devices
# -----------------------------------------------------------------------------
resource "aws_iot_thing_type" "greengrass_core" {
  name = "${var.project_name}-greengrass-core"

  properties {
    description           = "Greengrass v2 Core Device for ${var.project_name}"
    searchable_attributes = ["site", "environment"]
  }
}

# -----------------------------------------------------------------------------
# IoT Thing Group — Fleet Management
# All Greengrass core devices belong to this group for fleet deployments
# -----------------------------------------------------------------------------
resource "aws_iot_thing_group" "fleet" {
  name = "${var.project_name}-fleet"

  properties {
    description = "Fleet group for all ${var.project_name} Greengrass core devices"

    attribute_payload {
      attributes = {
        environment = var.environment
        project     = var.project_name
      }
    }
  }
}

# -----------------------------------------------------------------------------
# IoT Policy — Least-Privilege MQTT Permissions
# Devices can only connect with their thing name as client ID,
# and can only publish/subscribe to their own topic hierarchy
# -----------------------------------------------------------------------------
resource "aws_iot_policy" "device_policy" {
  name = "${var.project_name}-device-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowConnect"
        Effect   = "Allow"
        Action   = "iot:Connect"
        Resource = "arn:aws:iot:${var.aws_region}:${var.account_id}:client/$${iot:Connection.Thing.ThingName}"
      },
      {
        Sid    = "AllowPublishTelemetry"
        Effect = "Allow"
        Action = "iot:Publish"
        Resource = [
          "arn:aws:iot:${var.aws_region}:${var.account_id}:topic/${var.telemetry_topic_prefix}/*/telemetry",
          "arn:aws:iot:${var.aws_region}:${var.account_id}:topic/${var.telemetry_topic_prefix}/*/alert",
          "arn:aws:iot:${var.aws_region}:${var.account_id}:topic/$aws/things/$${iot:Connection.Thing.ThingName}/*"
        ]
      },
      {
        Sid    = "AllowSubscribe"
        Effect = "Allow"
        Action = "iot:Subscribe"
        Resource = [
          "arn:aws:iot:${var.aws_region}:${var.account_id}:topicfilter/${var.telemetry_topic_prefix}/*/command",
          "arn:aws:iot:${var.aws_region}:${var.account_id}:topicfilter/$aws/things/$${iot:Connection.Thing.ThingName}/*"
        ]
      },
      {
        Sid    = "AllowReceive"
        Effect = "Allow"
        Action = "iot:Receive"
        Resource = [
          "arn:aws:iot:${var.aws_region}:${var.account_id}:topic/${var.telemetry_topic_prefix}/*/command",
          "arn:aws:iot:${var.aws_region}:${var.account_id}:topic/$aws/things/$${iot:Connection.Thing.ThingName}/*"
        ]
      },
      {
        Sid    = "AllowShadowAccess"
        Effect = "Allow"
        Action = [
          "iot:GetThingShadow",
          "iot:UpdateThingShadow",
          "iot:DeleteThingShadow"
        ]
        Resource = "arn:aws:iot:${var.aws_region}:${var.account_id}:thing/$${iot:Connection.Thing.ThingName}"
      },
      {
        Sid    = "AllowGreengrassDiscovery"
        Effect = "Allow"
        Action = [
          "greengrass:Discover",
          "greengrass:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# IoT Things — One per customer site
# Each represents a Greengrass Core device at a customer location
# -----------------------------------------------------------------------------
resource "aws_iot_thing" "device" {
  for_each = toset(var.customer_sites)

  name            = "${var.project_name}-${each.value}"
  thing_type_name = aws_iot_thing_type.greengrass_core.name

  attributes = {
    site        = each.value
    environment = var.environment
    device_type = "greengrass-core"
  }
}

# Add each thing to the fleet group
resource "aws_iot_thing_group_membership" "fleet_membership" {
  for_each = toset(var.customer_sites)

  thing_name       = aws_iot_thing.device[each.key].name
  thing_group_name = aws_iot_thing_group.fleet.name
}

# -----------------------------------------------------------------------------
# X.509 Certificates — One per device (mutual TLS authentication)
# AWS generates the key pair and certificate
# -----------------------------------------------------------------------------
resource "aws_iot_certificate" "device_cert" {
  for_each = toset(var.customer_sites)

  active = true
}

# Attach policy to each certificate
resource "aws_iot_policy_attachment" "device_policy_attach" {
  for_each = toset(var.customer_sites)

  policy = aws_iot_policy.device_policy.name
  target = aws_iot_certificate.device_cert[each.key].arn
}

# Attach certificate to thing (authenticates device as specific thing)
resource "aws_iot_thing_principal_attachment" "device_cert_attach" {
  for_each = toset(var.customer_sites)

  principal = aws_iot_certificate.device_cert[each.key].arn
  thing     = aws_iot_thing.device[each.key].name
}

# -----------------------------------------------------------------------------
# Save certificates locally for device provisioning
# IMPORTANT: In production, use AWS IoT Fleet Provisioning instead
# These are saved only for PoC convenience
# -----------------------------------------------------------------------------
resource "local_file" "device_cert_pem" {
  for_each = toset(var.customer_sites)

  content  = aws_iot_certificate.device_cert[each.key].certificate_pem
  filename = "${path.module}/certs/${each.value}-certificate.pem"
}

resource "local_file" "device_private_key" {
  for_each = toset(var.customer_sites)

  content  = aws_iot_certificate.device_cert[each.key].private_key
  filename = "${path.module}/certs/${each.value}-private.key"

  file_permission = "0600"
}

resource "local_file" "device_public_key" {
  for_each = toset(var.customer_sites)

  content  = aws_iot_certificate.device_cert[each.key].public_key
  filename = "${path.module}/certs/${each.value}-public.key"
}
