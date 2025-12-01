output "event_bus_name" {
  description = "Name of the EventBridge custom event bus"
  value       = aws_cloudwatch_event_bus.orders.name
}

output "order_processor_lambda_arn" {
  description = "ARN of the order processor Lambda function"
  value       = aws_lambda_function.order_processor.arn
}

output "firehose_name" {
  description = "Name of the Kinesis Firehose delivery stream"
  value       = aws_kinesis_firehose_delivery_stream.orders_firehose.name
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for analytics"
  value       = aws_s3_bucket.analytics.bucket
}

