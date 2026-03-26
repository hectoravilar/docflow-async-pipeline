# 1. Zip the Python code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

# 2. Trust Policy (Assume Role)
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# 3. Logs and S3 Permissions
data "aws_iam_policy_document" "lambda_policy" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }

  statement {
    actions = ["s3:PutObject"]
    # FIX: Dynamic reference! This prevents dependency breaks.
    resources = ["${aws_s3_bucket.YOUR_BUCKET_RESOURCE_NAME.arn}/*"]
  }
}

# 4. Create the IAM Role
resource "aws_iam_role" "lambda_role" {
  name               = lower("${var.project_name}-lambda-role-${var.environment}")
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

# 5. Attach the permissions to the Role
resource "aws_iam_role_policy" "lambda_policy_attachment" {
  name   = lower("${var.project_name}-lambda-policy-${var.environment}")
  role   = aws_iam_role.lambda_role.id
  policy = data.aws_iam_policy_document.lambda_policy.json
}

# 6. The Lambda Function 
resource "aws_lambda_function" "api_handler" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = lower("${var.project_name}-api-handler-${var.environment}")
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      # Injecting the bucket name 
      BUCKET_NAME = aws_s3_bucket.docflow_bucket.bucket
    }
  }
}
resource "aws_apigatewayv2_api" "api_gateway" {
  name          = lower("${var.project_name}-${var.environment}")
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["Content-Type"]
    max_age       = 300
  }
}
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id             = aws_apigatewayv2_api.api_gateway.id
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.api_handler.invoke_arn
}
resource "aws_apigatewayv2_route" "lambda_route" {
  api_id    = aws_apigatewayv2_api.api_gateway.id
  route_key = "POST /upload"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}
resource "aws_lambda_permission" "api_gateway_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api_gateway.execution_arn}/*/*"
}
output "api_endpoint" {
  value       = "${aws_apigatewayv2_api.api_gateway.api_endpoint}/upload"
  description = "The endpoint URL used by the frontend to request S3 presigned links"
}
