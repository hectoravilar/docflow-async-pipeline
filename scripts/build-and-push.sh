#!/bin/bash
set -e

REGION=$1
ACCOUNT_ID=$2
REPOSITORY_URL=$3

aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com
docker build -t $REPOSITORY_URL:latest ./src/api
docker push $REPOSITORY_URL:latest
