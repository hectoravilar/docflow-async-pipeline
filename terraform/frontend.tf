resource "aws_s3_bucket" "docflow_bucket_s3" {
  bucket = lower("${var.project_name}-frontend-hector-${var.environment}")

  tags = {
    Name        = "Frontend Bucket"
    Environment = lower(var.environment)
  }
}
resource "aws_cloudfront_origin_access_control" "docflow_oac" {
  name                              = lower("${var.project_name}-oac-${var.environment}")
  description                       = "Docflow Origin Access Control"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
