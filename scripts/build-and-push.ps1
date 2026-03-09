param(
    [string]$Region,
    [string]$AccountId,
    [string]$RepositoryUrl
)

$ErrorActionPreference = "Stop"

aws ecr get-login-password --region $Region | docker login --username AWS --password-stdin "$AccountId.dkr.ecr.$Region.amazonaws.com"
docker build -t "${RepositoryUrl}:latest" ./src/api
docker push "${RepositoryUrl}:latest"
