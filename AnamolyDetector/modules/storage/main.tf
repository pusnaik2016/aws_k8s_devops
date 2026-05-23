###############################################################################
# Storage Module — DynamoDB table with TTL
###############################################################################

resource "aws_dynamodb_table" "cost_history" {
  name         = "${var.table_name}-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "service"
  range_key    = "date"

  attribute {
    name = "service"
    type = "S"
  }

  attribute {
    name = "date"
    type = "S"
  }

  # TTL: DynamoDB will automatically delete rows after retention_days
  ttl {
    attribute_name = "expiry_ts"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name      = "${var.table_name}-${var.environment}"
    Component = "storage"
  }
}
