variable "environment" {
  description = "Deployment environment name"
  type        = string
  default     = "DevOps"
}

variable "aws_region" {
  description = "AWS Region where the resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "The name of the project"
  type        = string
  default     = "docflow"
}
