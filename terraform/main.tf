terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}
resource "aws_s3_bucket" "docflow_bucket" {
  bucket = lower("${var.project_name}-pdfs-hector-${var.environment}")

  tags = {
    Name        = lower(var.project_name)
    Environment = lower(var.environment)
  }
}
resource "aws_sqs_queue" "docflow_dlq" {
  name = lower("${var.project_name}-dlq-${var.environment}")
}
resource "aws_sqs_queue" "docflow_queue" {
  name                       = lower("${var.project_name}-sqs-${var.environment}")
  max_message_size           = 2048
  message_retention_seconds  = 86400
  visibility_timeout_seconds = 60
  receive_wait_time_seconds  = 10
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.docflow_dlq.arn
    maxReceiveCount     = 4
  })

  tags = {
    Environment = lower(var.environment)
  }
}

resource "aws_dynamodb_table" "docflow_table" {
  name             = lower("${var.project_name}-dynamodb-${var.environment}")
  hash_key         = "document_id"
  billing_mode     = "PAY_PER_REQUEST"
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "document_id"
    type = "S"
  }
}
resource "aws_ecr_repository" "docflow_repository" {
  name                 = lower("docflow-worker-${var.environment}")
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}
