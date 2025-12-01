#!/bin/bash

# Integration test script
# Assumes AWS CLI configured and Terraform outputs available

# Load outputs (in real, use terraform output)
EVENT_BUS_NAME="orders-bus"
S3_BUCKET="eventbridge-order-analytics-us-east-1"  # From outputs
DLQ_URL="https://sqs.us-east-1.amazonaws.com/123456789012/eventbridge-dlq"  # From outputs

echo "Sending test order event..."
cd ../producer
node send_order.js

echo "Waiting for processing..."
sleep 30

echo "Checking S3 for analytics data..."
aws s3 ls s3://$S3_BUCKET/orders/ --recursive

echo "Checking DLQ for failed messages..."
aws sqs get-queue-attributes --queue-url $DLQ_URL --attribute-names ApproximateNumberOfMessages

echo "Checking CloudWatch logs..."
aws logs tail /aws/lambda/order-processor --since 5m

echo "Test completed."
