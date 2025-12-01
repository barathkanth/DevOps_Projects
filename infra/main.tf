# infra/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
  required_version = ">= 1.5.0"
}

provider "aws" {
  region = var.aws_region
}

# CloudWatch Log Group for eventbridge
resource "aws_cloudwatch_log_group" "eventbridge" {
  name              = "/aws/events/orders-bus"
  retention_in_days = 1
}

# CloudWatch Log Group for lambda
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/order-processor"
  retention_in_days = 1
}

# Event Bus
resource "aws_cloudwatch_event_bus" "orders" {
  name = "orders-bus"
}

# Event Archive
resource "aws_cloudwatch_event_archive" "orders_archive" {
  name             = "orders-archive"
  event_source_arn = aws_cloudwatch_event_bus.orders.arn
  retention_days   = 1
  event_pattern = jsonencode({
    "detail-type" : ["OrderCreated"]
  })
}

# Schema Registry
resource "aws_schemas_registry" "orders_registry" {
  name = "orders-registry"
}

resource "aws_schemas_schema" "order_schema" {
  name          = "order-schema"
  registry_name = aws_schemas_registry.orders_registry.name
  type          = "OpenApi3"
  content       = jsonencode({
    openapi = "3.0.0"
    info = {
      title   = "Order Schema"
      version = "1.0.0"
    },
    "paths":{},
    components = {
      schemas = {
        Order = {
          type = "object"
          properties = {
            orderId = { type = "string" }
            customerId = { type = "string" }
            amount = { type = "number" }
            currency = { type = "string" }
            items = {
              type = "array"
              items = { type = "object" }
            }
            createdAt = { type = "string" }
          }
          required = ["orderId", "customerId", "amount"]
        }
      }
    }
  })
}

# SQS DLQ
# resource "aws_sqs_queue" "dlq" {
#  name = "eventbridge-dlq"
# }

# IAM Role for Lambda
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name               = "lambda-exec-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

# Attach policies
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_additional" {
  name = "lambda-additional-policy"
  role = aws_iam_role.lambda_exec.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "firehose:PutRecord",
          "events:PutEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# Lambda Function
resource "aws_lambda_function" "order_processor" {
  filename         = "${path.module}/../src/lambdas/order_processor/order_processor.zip"
  function_name    = "order-processor"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.11"
  environment {
    variables = {
      ENV            = var.env
      FIREHOSE_NAME  = var.firehose_name
      EVENT_BUS_NAME = aws_cloudwatch_event_bus.orders.name
    }
  }
}

# EventBridge Rule
resource "aws_cloudwatch_event_rule" "to_lambda" {
  name           = "order-created-to-lambda"
  event_bus_name = aws_cloudwatch_event_bus.orders.name
  event_pattern = jsonencode({
    "source" : ["com.myapp.orders"],
    "detail-type" : ["OrderCreated"]
  })
}

# Target
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule           = aws_cloudwatch_event_rule.to_lambda.name
  arn            = aws_lambda_function.order_processor.arn
  event_bus_name = aws_cloudwatch_event_bus.orders.name
  retry_policy {
    maximum_retry_attempts          = 2
    maximum_event_age_in_seconds    = 3600
  }
  dead_letter_config {
    #arn = aws_sqs_queue.dlq.arn
  }
}

# Permission
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.order_processor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.to_lambda.arn
}

# For Kinesis Firehose - placeholder, will expand in modules
# Assume a simple Firehose to S3
resource "aws_kinesis_firehose_delivery_stream" "orders_firehose" {
  name        = var.firehose_name
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose_role.arn
    bucket_arn = aws_s3_bucket.analytics.arn
    prefix     = "orders/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
    error_output_prefix = "errors/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/!{firehose:error-output-type}/"
  }
}

# IAM for Firehose
resource "aws_iam_role" "firehose_role" {
  name = "firehose-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "firehose.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "firehose_s3" {
  role       = aws_iam_role.firehose_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# S3 Bucket
resource "aws_s3_bucket" "analytics" {
  bucket = "eventbridge-order-analytics-${var.aws_region}"
}