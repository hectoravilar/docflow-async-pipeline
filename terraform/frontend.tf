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

# IAM Policy Document to allow CloudFront to read the S3 bucket
data "aws_iam_policy_document" "frontend_bucket_policy" {
  statement {
    sid    = "AllowCloudFrontServicePrincipalReadOnly"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = ["s3:GetObject"]

    resources = ["${aws_s3_bucket.docflow_bucket_s3.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.frontend_distribution.arn]
    }
  }
}

# Attach the policy to the bucket
resource "aws_s3_bucket_policy" "frontend_policy_attachment" {
  bucket = aws_s3_bucket.docflow_bucket_s3.id
  policy = data.aws_iam_policy_document.frontend_bucket_policy.json
}

# The CloudFront Distribution
resource "aws_cloudfront_distribution" "frontend_distribution" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100" # Optimized for lower cost in lab environments

  origin {
    domain_name              = aws_s3_bucket.docflow_bucket_s3.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.docflow_bucket_s3.bucket}"
    origin_access_control_id = aws_cloudfront_origin_access_control.docflow_oac.id
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.docflow_bucket_s3.bucket}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none" # Unblocked globally
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true # Uses default AWS SSL
  }

  tags = {
    Environment = lower(var.environment)
  }
}

# Outputs the final URL to the terminal
output "frontend_url" {
  value       = "https://${aws_cloudfront_distribution.frontend_distribution.domain_name}"
  description = "The secure HTTPS URL for the Docflow frontend"
}
