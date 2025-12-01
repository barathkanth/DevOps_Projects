variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "env" {
  description = "Environment"
  type        = string
  default     = "dev"
}

variable "firehose_name" {
  description = "Kinesis Firehose delivery stream name"
  type        = string
  default     = "orders-firehose"
}
