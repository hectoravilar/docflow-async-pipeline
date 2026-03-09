provider "aws" {
  region = local.region
}

terraform {
  
  required_version = ">= 1.5.0" 

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
 
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.0"
    }
  }
}

locals {
  bucket_name = "s3-bucket-${data.aws_caller_identity.current.account_id}"
  region      = "us-east-1"
  account_id  = data.aws_caller_identity.current.account_id
  container_port = 8080

  name   = "ex-${basename(path.cwd)}-${random_string.random.result}"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Name       = local.name
    Example    = local.name
    Repository = "https://github.com/terraform-aws-modules/terraform-aws-ecs"
  }

  rendered_index = templatefile("${path.module}/src/website/index.html.tpl", {
    api_endpoint = "http://${aws_lb.app.dns_name}"
    
  })

  api_hash  = md5(join("", [for f in fileset("${path.module}/src/api", "**"): filemd5("${path.module}/src/api/${f}")]))
  image_tag = "v-${substr(local.api_hash, 0, 8)}"
}

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  # Exclude local zones
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

resource "random_string" "random" {
  length  = 6
  special = false
}

# Create S3 Bucket
module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 4.1"

  bucket = local.bucket_name
  acl    = "private"

  control_object_ownership = true
  object_ownership         = "ObjectWriter"

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false

  versioning = {
    enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = module.s3_bucket.s3_bucket_id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = module.s3_bucket.s3_bucket_id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }

  depends_on = [module.s3_bucket]
}


resource "aws_s3_bucket_policy" "frontend" {
  bucket = module.s3_bucket.s3_bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = "*"
        Action = "s3:GetObject"
        Resource = "${module.s3_bucket.s3_bucket_arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.frontend]
}

output "frontend_url" {
  value = "http://${local.bucket_name}.s3-website-${local.region}.amazonaws.com"
}

# Create ECR to store docker images
module "ecr" {
  source = "terraform-aws-modules/ecr/aws"
  version = "~> 2.0"

  repository_name = "dreamsquad-ecr"

  repository_image_tag_mutability = "MUTABLE"
  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last 30 images",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = ["v"],
          countType     = "imageCountMoreThan",
          countNumber   = 30
        },
        action = {
          type = "expire"
        }
      }
    ]
  })

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

# Create AWS Lambda to create files in S3 bucket based on cron
module "lambda_function" {
  source = "terraform-aws-modules/lambda/aws"
  version = "~> 7.2"

  function_name = "CreateS3File"
  description   = "This Lambda create an file in the S3 Bucket when triggered by EventBridge"
  handler       = "index.lambda_handler"
  runtime       = "python3.12"
  environment_variables = {
    bucket_name = module.s3_bucket.s3_bucket_id
  }

  source_path = "./src/lambda-CreateS3File"

  attach_policy_json = true
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = "${module.s3_bucket.s3_bucket_arn}/*"
      }
    ]
  })

  tags = {
    Name = "CreateS3File"
  }
}

module "eventbridge" {
  source = "terraform-aws-modules/eventbridge/aws"
  version = "~> 3.0"

  create_bus = false

  rules = {
    crons = {
      description         = "Trigger for a Lambda"
      schedule_expression = "cron(0 13 * * ? *)"
    }
  }

  targets = {
    crons = [
      {
        name  = "lambda-CreateS3File-cron"
        arn   = module.lambda_function.lambda_function_arn
        input = jsonencode({ "job" : "cron-by-rate" })
      }
    ]
  }
}

// Uploading S3 Files: https://stackoverflow.com/questions/57456167/uploading-multiple-files-in-aws-s3-from-terraform
# Source - https://stackoverflow.com/a/66233285
# Posted by Flair
# Retrieved 2026-03-08, License - CC BY-SA 4.0

resource "aws_s3_object" "index" {
  bucket       = module.s3_bucket.s3_bucket_id
  key          = "index.html"
  content      = local.rendered_index
  content_type = "text/html"
  etag         = md5(local.rendered_index) 
}

resource "aws_s3_object" "website_files" {
  for_each = setsubtract(fileset("${path.module}/src/website", "*"), ["index.html", "index.html.tpl"])

  bucket = module.s3_bucket.s3_bucket_id
  key    = each.value
  source = "${path.module}/src/website/${each.value}"

  etag = filemd5("${path.module}/src/website/${each.value}")
}

# Build Docker image and upload
# https://www.linkedin.com/pulse/how-upload-docker-images-aws-ecr-using-terraform-hendrix-roa/
resource "null_resource" "docker_packaging" {
  
  triggers = {
    api_source_code_hash = local.api_hash
  }

  provisioner "local-exec" {
    # Sem o 'interpreter', o Terraform usa cmd.exe no Windows e /bin/sh no Mac/Linux
    command = "aws ecr get-login-password --region ${local.region} | docker login --username AWS --password-stdin ${local.account_id}.dkr.ecr.${local.region}.amazonaws.com && docker build -t ${module.ecr.repository_url}:${local.image_tag} ./src/api && docker push ${module.ecr.repository_url}:${local.image_tag}"
  }

  depends_on = [
    module.ecr.ecr_repository,
  ]
}

# Permission for EventBridge to invoke Lambda
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_function.lambda_function_name
  principal     = "events.amazonaws.com"
  source_arn    = module.eventbridge.eventbridge_rule_arns["crons"]
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "${local.name}-vpc"
  cidr = local.vpc_cidr

  azs             = local.azs
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = local.tags
}

resource "aws_security_group" "alb_sg" {
  name   = "${local.name}-alb-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ecs_sg" {
  name   = "${local.name}-ecs-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port       = local.container_port
    to_port         = local.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_cluster" "this" {
  name = "${local.name}-cluster"
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${local.name}-ecs-task-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${local.name}-task"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name  = "app"
      image = "${module.ecr.repository_url}:latest"

      portMappings = [
        {
          containerPort = local.container_port
          hostPort      = local.container_port
        }
      ]
      environment = [
        {
          name  = "FRONTEND_URL"
          value = "http://${local.bucket_name}.s3-website-${local.region}.amazonaws.com"
        }
      ]
      
      essential = true
    }
  ])
}

resource "aws_lb" "app" {
  name               = "${local.name}-alb"
  load_balancer_type = "application"
  subnets            = module.vpc.public_subnets
  security_groups    = [aws_security_group.alb_sg.id]
}

resource "aws_lb_target_group" "app" {
  name        = "${local.name}-tg"
  port        = local.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = module.vpc.vpc_id

  health_check {
    path                = "/health"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_ecs_service" "app" {
  name            = "${local.name}-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.app.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets         = module.vpc.private_subnets
    security_groups = [aws_security_group.ecs_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = local.container_port
  }

  depends_on = [
    aws_lb_listener.http
  ]
}

output "alb_dns" {
  value = aws_lb.app.dns_name
}

