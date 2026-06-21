# ─────────────────────────────────────────────────────────────────────────────
# Messaging Module — SQS Queues & SNS Topics
# ─────────────────────────────────────────────────────────────────────────────
# These are the event sources for KEDA autoscaling:
# - order-queue (FIFO, encrypted) → triggers order-service ScaledObject
# - notification-queue → triggers notification-service ScaledObject
# All queues have DLQs and IRSA roles for pod-level access.
# ─────────────────────────────────────────────────────────────────────────────

data "aws_caller_identity" "current" {}

# ─── Order Queue (FIFO — exactly-once processing) ───────────────────────────

resource "aws_sqs_queue" "order_dlq" {
  name                       = "${var.name_prefix}-order-dlq.fifo"
  fifo_queue                 = true
  message_retention_seconds  = 1209600 # 14 days
  sqs_managed_sse_enabled    = false
  kms_master_key_id          = var.kms_key_arn
  kms_data_key_reuse_period_seconds = 300

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-order-dlq"
  })
}

resource "aws_sqs_queue" "order_queue" {
  name                        = "${var.name_prefix}-order-queue.fifo"
  fifo_queue                  = true
  content_based_deduplication = true
  visibility_timeout_seconds  = 300
  message_retention_seconds   = 345600 # 4 days
  receive_wait_time_seconds   = 20     # Long polling
  sqs_managed_sse_enabled     = false
  kms_master_key_id           = var.kms_key_arn
  kms_data_key_reuse_period_seconds = 300

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.order_dlq.arn
    maxReceiveCount     = 3
  })

  tags = merge(var.common_tags, {
    Name       = "${var.name_prefix}-order-queue"
    Compliance = "PCI-DSS"
    KedaTrigger = "true"
  })
}

# ─── Notification Queue (Standard) ──────────────────────────────────────────

resource "aws_sqs_queue" "notification_dlq" {
  name                      = "${var.name_prefix}-notification-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = false
  kms_master_key_id         = var.kms_key_arn
  kms_data_key_reuse_period_seconds = 300

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-notification-dlq"
  })
}

resource "aws_sqs_queue" "notification_queue" {
  name                       = "${var.name_prefix}-notification-queue"
  visibility_timeout_seconds = 120
  message_retention_seconds  = 345600
  receive_wait_time_seconds  = 20
  sqs_managed_sse_enabled    = false
  kms_master_key_id          = var.kms_key_arn
  kms_data_key_reuse_period_seconds = 300

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.notification_dlq.arn
    maxReceiveCount     = 3
  })

  tags = merge(var.common_tags, {
    Name       = "${var.name_prefix}-notification-queue"
    KedaTrigger = "true"
  })
}

# ─── SNS Topic (Notification Events) ────────────────────────────────────────

resource "aws_sns_topic" "notifications" {
  name              = "${var.name_prefix}-notifications"
  kms_master_key_id = var.kms_key_arn

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-notifications-topic"
  })
}

resource "aws_sns_topic_subscription" "notification_sqs" {
  topic_arn = aws_sns_topic.notifications.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.notification_queue.arn
}

resource "aws_sqs_queue_policy" "notification_from_sns" {
  queue_url = aws_sqs_queue.notification_queue.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowSNSPublish"
      Effect    = "Allow"
      Principal = { Service = "sns.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.notification_queue.arn
      Condition = {
        ArnEquals = { "aws:SourceArn" = aws_sns_topic.notifications.arn }
      }
    }]
  })
}

# ─── SNS Topic (Order Events) ───────────────────────────────────────────────

resource "aws_sns_topic" "order_events" {
  name              = "${var.name_prefix}-order-events"
  kms_master_key_id = var.kms_key_arn

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-order-events-topic"
  })
}

# ─── IRSA Roles for Service Queue Access ────────────────────────────────────

# Order Service — read from order queue
resource "aws_iam_role" "order_service" {
  name = "${var.name_prefix}-order-service-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Federated = var.oidc_provider_arn }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${var.oidc_provider_url}:aud" = "sts.amazonaws.com"
          "${var.oidc_provider_url}:sub" = "system:serviceaccount:retail-apps:order-service"
        }
      }
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy" "order_service_sqs" {
  name = "sqs-access"
  role = aws_iam_role.order_service.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Resource = aws_sqs_queue.order_queue.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = [
          aws_sns_topic.notifications.arn,
          aws_sns_topic.order_events.arn
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = var.kms_key_arn
      }
    ]
  })
}

# Notification Service — read from notification queue
resource "aws_iam_role" "notification_service" {
  name = "${var.name_prefix}-notification-service-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Federated = var.oidc_provider_arn }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${var.oidc_provider_url}:aud" = "sts.amazonaws.com"
          "${var.oidc_provider_url}:sub" = "system:serviceaccount:retail-apps:notification-service"
        }
      }
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy" "notification_service_sqs" {
  name = "sqs-access"
  role = aws_iam_role.notification_service.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Resource = aws_sqs_queue.notification_queue.arn
      },
      {
        Effect = "Allow"
        Action = ["ses:SendEmail", "ses:SendRawEmail"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = var.kms_key_arn
      }
    ]
  })
}

# KEDA Operator — read queue attributes for scaling decisions
resource "aws_iam_role" "keda_operator" {
  name = "${var.name_prefix}-keda-operator-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Federated = var.oidc_provider_arn }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${var.oidc_provider_url}:aud" = "sts.amazonaws.com"
          "${var.oidc_provider_url}:sub" = "system:serviceaccount:keda:keda-operator"
        }
      }
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy" "keda_operator_sqs" {
  name = "sqs-read-attributes"
  role = aws_iam_role.keda_operator.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sqs:GetQueueAttributes",
        "sqs:GetQueueUrl"
      ]
      Resource = [
        aws_sqs_queue.order_queue.arn,
        aws_sqs_queue.notification_queue.arn
      ]
    }]
  })
}
