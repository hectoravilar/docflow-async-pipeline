$ErrorActionPreference = "Stop"

$REGION = "us-east-1"
$ACCOUNT_ID = (aws sts get-caller-identity --query Account --output text)
$ECR_REPO = "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/dreamsquad-ecr"

Write-Host "Logging into ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

Write-Host "Building Docker image..."
docker build -t "${ECR_REPO}:latest" ./src/api

Write-Host "Pushing image to ECR..."
docker push "${ECR_REPO}:latest"

Write-Host "Docker image pushed successfully!"
