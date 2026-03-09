#!/bin/bash
set -e

REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPO="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/dreamsquad-ecr"

echo "Logging into ECR..."
aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com

echo "Building Docker image..."
docker build -t ${ECR_REPO}:latest ./src/api

echo "Pushing image to ECR..."
docker push ${ECR_REPO}:latest

echo "Docker image pushed successfully!"
