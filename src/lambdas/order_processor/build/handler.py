import json
import os
import boto3

firehose = boto3.client("firehose")
eventbridge = boto3.client("events")
S3_FIREHOSE_NAME = os.environ.get("FIREHOSE_NAME", "orders-firehose")

def lambda_handler(event, context):
    # EventBridge wraps the event into 'detail'
    print("Received event:", json.dumps(event))
    for record in event.get("detail", []) or [event.get("detail")]:
        detail = record if isinstance(record, dict) else json.loads(record)
        # Basic validation
        if "orderId" not in detail:
            print("Invalid event, missing orderId")
            raise Exception("Invalid event")
        # Enrichment example: add processedAt
        detail["processedAt"] = context.aws_request_id
        # Send to firehose for analytics
        firehose.put_record(
            DeliveryStreamName=S3_FIREHOSE_NAME,
            Record={"Data": json.dumps(detail) + "\n"}
        )
    return {"status": "ok"}
