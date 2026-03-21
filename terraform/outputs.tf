output "s3_bucket_name" {
  description = "Name of the S3 Bucket"
  value       = aws_s3_bucket.docflow_bucket.bucket
}

output "sqs_queue" {
  description = "URL of the SQS queue"
  value       = aws_sqs_queue.docflow_queue.url
}
output "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.docflow_table.name
}
