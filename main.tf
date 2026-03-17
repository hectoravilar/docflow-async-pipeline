# configuração do provider aws
# Define o provider AWS utilizando a região especificada nas variáveis locais
provider "aws" {
  region = local.region
}

# configuração do terraform
terraform {
  # Versão mínima do Terraform necessária para executar este código
  required_version = ">= 1.5.0"

  required_providers {
    # provider aws para gerenciar recursos na amazon web services
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0" # Permite atualizações minor e patch, mas não major
    }
    # provider random para gerar valores aleatórios (nomes únicos)
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    # provider null para executar provisioners sem recursos reais
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.0"
    }
  }
}

# variáveis locais
locals {
  # nome do bucket s3 usando o id da conta aws para garantir unicidade global
  bucket_name = "s3-bucket-${data.aws_caller_identity.current.account_id}"
  
  # região aws onde os recursos serão provisionados
  region      = "us-east-1"
  
  # id da conta aws obtido dinamicamente
  account_id  = data.aws_caller_identity.current.account_id
  
  # porta onde o container da aplicação irá escutar
  container_port = 8080

  # nome único para os recursos usando o diretório atual e string aleatória
  name   = "ex-${basename(path.cwd)}-${random_string.random.result}"

  # cidr block para a vpc (65,536 endereços ip disponíveis)
  vpc_cidr = "10.0.0.0/16"
  
  # seleciona as 3 primeiras zonas de disponibilidade da região
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  # tags padrão aplicadas aos recursos para organização e rastreamento
  tags = {
    Name       = local.name
    Example    = local.name
    Repository = "https://github.com/terraform-aws-modules/terraform-aws-ecs"
  }

  # renderiza o template html substituindo a variável api_endpoint
  rendered_index = templatefile("${path.module}/src/website/index.html.tpl", {
    api_endpoint = "http://${aws_lb.app.dns_name}"
    
  })

  # gera hash md5 de todos os arquivos da api para versionamento de imagem
  api_hash  = md5(join("", [for f in fileset("${path.module}/src/api", "**"): filemd5("${path.module}/src/api/${f}")]))
  
  # tag da imagem docker baseada no hash dos arquivos (primeiros 8 caracteres)
  image_tag = "v-${substr(local.api_hash, 0, 8)}"
}

# data sources
# obtém informações da conta aws atual (id, arn, etc.)
data "aws_caller_identity" "current" {}

# lista todas as zonas de disponibilidade na região atual
data "aws_availability_zones" "available" {
  # exclui zonas locais (local zones), mantendo apenas zonas padrão
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# recursos auxiliares
# gera uma string aleatória de 6 caracteres para nomes únicos de recursos
resource "random_string" "random" {
  length  = 6
  special = false # apenas letras e números, sem caracteres especiais
}

# s3 bucket - frontend estático
# cria bucket s3 usando módulo oficial da aws para hospedar o frontend
module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 4.1"

  bucket = local.bucket_name
  acl    = "private" # acl privada por padrão (será sobrescrita pela policy)

  # controla a propriedade dos objetos no bucket
  control_object_ownership = true
  object_ownership         = "ObjectWriter" # quem faz upload é o dono

  # configurações de acesso público (necessário para website estático)
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false

  # habilita versionamento para manter histórico de alterações
  versioning = {
    enabled = true
  }
}

# configuração adicional de acesso público para o bucket
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = module.s3_bucket.s3_bucket_id

  # permite acesso público para funcionar como website estático
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# configura o bucket s3 como website estático
resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = module.s3_bucket.s3_bucket_id

  # documento padrão servido quando acessar a raiz do site
  index_document {
    suffix = "index.html"
  }

  # documento servido em caso de erro 404 (spa pattern)
  error_document {
    key = "index.html"
  }

  depends_on = [module.s3_bucket]
}

# policy do bucket permitindo leitura pública dos objetos
resource "aws_s3_bucket_policy" "frontend" {
  bucket = module.s3_bucket.s3_bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = "*" # qualquer pessoa pode ler
        Action = "s3:GetObject"
        Resource = "${module.s3_bucket.s3_bucket_arn}/*" # todos os objetos
      }
    ]
  })

  # garante que o public access block seja configurado primeiro
  depends_on = [aws_s3_bucket_public_access_block.frontend]
}

# output com a url do frontend hospedado no s3
output "frontend_url" {
  value = "http://${local.bucket_name}.s3-website-${local.region}.amazonaws.com"
}

# ecr - elastic container registry
# Cria repositório ECR para armazenar imagens Docker do backend
module "ecr" {
  source = "terraform-aws-modules/ecr/aws"
  version = "~> 2.0"

  repository_name = "dreamsquad-ecr"

  # Permite que tags de imagem sejam sobrescritas (útil para desenvolvimento)
  repository_image_tag_mutability = "MUTABLE"
  
  # Política de ciclo de vida: mantém apenas as últimas 30 imagens
  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last 30 images",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = ["v"], # Apenas imagens com tag começando com "v"
          countType     = "imageCountMoreThan",
          countNumber   = 30
        },
        action = {
          type = "expire" # Remove imagens antigas automaticamente
        }
      }
    ]
  })

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

# lambda function - criação de arquivos no s3
# Cria função Lambda que insere arquivos no S3 quando acionada pelo EventBridge
module "lambda_function" {
  source = "terraform-aws-modules/lambda/aws"
  version = "~> 7.2"

  function_name = "CreateS3File"
  description   = "This Lambda create an file in the S3 Bucket when triggered by EventBridge"
  handler       = "index.lambda_handler" # Função handler no arquivo index.py
  runtime       = "python3.12"           # Runtime Python mais recente
  
  # Variáveis de ambiente disponíveis dentro da Lambda
  environment_variables = {
    bucket_name = module.s3_bucket.s3_bucket_id
  }

  # Caminho do código fonte da Lambda
  source_path = "./src/lambda-CreateS3File"

  # Anexa policy IAM customizada para permitir escrita no S3
  attach_policy_json = true
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",    # Permite criar objetos
          "s3:PutObjectAcl"  # Permite definir ACL dos objetos
        ]
        Resource = "${module.s3_bucket.s3_bucket_arn}/*"
      }
    ]
  })

  tags = {
    Name = "CreateS3File"
  }
}

# eventbridge - agendamento de tarefas
# Configura EventBridge para executar a Lambda em horário agendado
module "eventbridge" {
  source = "terraform-aws-modules/eventbridge/aws"
  version = "~> 3.0"

  create_bus = false # Usa o event bus padrão

  # Define regra de agendamento usando expressão cron
  rules = {
    crons = {
      description         = "Trigger for a Lambda"
      schedule_expression = "cron(0 13 * * ? *)" # Executa às 13:00 UTC (10:00 BRT) todos os dias
    }
  }

  # Define a Lambda como alvo da regra
  targets = {
    crons = [
      {
        name  = "lambda-CreateS3File-cron"
        arn   = module.lambda_function.lambda_function_arn
        input = jsonencode({ "job" : "cron-by-rate" }) # Payload enviado para a Lambda
      }
    ]
  }
}

# upload de arquivos para o s3
# Referência: https://stackoverflow.com/questions/57456167/uploading-multiple-files-in-aws-s3-from-terraform
# Source - https://stackoverflow.com/a/66233285
# Posted by Flair
# Retrieved 2026-03-08, License - CC BY-SA 4.0

# Faz upload do index.html renderizado com o endpoint da API
resource "aws_s3_object" "index" {
  bucket       = module.s3_bucket.s3_bucket_id
  key          = "index.html"
  content      = local.rendered_index
  content_type = "text/html"
  etag         = md5(local.rendered_index) # Atualiza apenas se o conteúdo mudar
}

# Faz upload de todos os outros arquivos do website (exceto templates)
resource "aws_s3_object" "website_files" {
  # Itera sobre todos os arquivos, excluindo index.html e templates
  for_each = setsubtract(fileset("${path.module}/src/website", "*"), ["index.html", "index.html.tpl"])

  bucket = module.s3_bucket.s3_bucket_id
  key    = each.value
  source = "${path.module}/src/website/${each.value}"

  etag = filemd5("${path.module}/src/website/${each.value}") # Detecta mudanças
}

# permissões lambda
# Permite que o EventBridge invoque a função Lambda
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_function.lambda_function_name
  principal     = "events.amazonaws.com"
  source_arn    = module.eventbridge.eventbridge_rule_arns["crons"]
}

# vpc - virtual private cloud
# Cria VPC com subnets públicas e privadas em múltiplas AZs
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "${local.name}-vpc"
  cidr = local.vpc_cidr

  azs             = local.azs
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]     # 256 IPs cada
  private_subnets = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"] # 256 IPs cada

  # NAT Gateway permite que recursos privados acessem a internet
  enable_nat_gateway = true
  single_nat_gateway = true # Usa apenas 1 NAT para reduzir custos (não recomendado para produção)

  tags = local.tags
}

# security groups
# Security Group para o Application Load Balancer
resource "aws_security_group" "alb_sg" {
  name   = "${local.name}-alb-sg"
  vpc_id = module.vpc.vpc_id

  # Permite tráfego HTTP de qualquer origem
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Acesso público
  }

  # Permite todo tráfego de saída
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"          # Todos os protocolos
    cidr_blocks = ["0.0.0.0/0"] # Para qualquer destino
  }
}

# Security Group para as tasks ECS
resource "aws_security_group" "ecs_sg" {
  name   = "${local.name}-ecs-sg"
  vpc_id = module.vpc.vpc_id

  # Permite tráfego apenas do ALB na porta do container
  ingress {
    from_port       = local.container_port
    to_port         = local.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id] # Apenas do ALB
  }

  # Permite todo tráfego de saída (necessário para pull de imagens, etc.)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ecs cluster
# Cria cluster ECS para executar containers
resource "aws_ecs_cluster" "this" {
  name = "${local.name}-cluster"
}

# iam roles para ecs
# Role que permite ao ECS executar tasks (pull de imagens, logs, etc.)
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${local.name}-ecs-task-exec-role"

  # Trust policy: permite que o serviço ECS assuma esta role
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

# Anexa policy gerenciada pela AWS com permissões necessárias para ECS
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ecs task definition
# Define como o container deve ser executado
resource "aws_ecs_task_definition" "app" {
  family                   = "${local.name}-task"
  requires_compatibilities = ["FARGATE"] # Usa Fargate (serverless)
  cpu                      = "256"       # 0.25 vCPU
  memory                   = "512"       # 512 MB
  network_mode             = "awsvpc"    # Cada task tem seu próprio ENI
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  # Definição dos containers na task
  container_definitions = jsonencode([
    {
      name  = "app"
      image = "${module.ecr.repository_url}:latest" # Imagem do ECR

      # Mapeamento de portas
      portMappings = [
        {
          containerPort = local.container_port
          hostPort      = local.container_port
        }
      ]
      
      # Variáveis de ambiente injetadas no container
      environment = [
        {
          name  = "FRONTEND_URL"
          value = "http://${local.bucket_name}.s3-website-${local.region}.amazonaws.com"
        }
      ]
      
      essential = true # Container principal da task
    }
  ])
}

# application load balancer
# Cria ALB para distribuir tráfego entre as tasks ECS
resource "aws_lb" "app" {
  name               = "${local.name}-alb"
  load_balancer_type = "application"
  subnets            = module.vpc.public_subnets # ALB em subnets públicas
  security_groups    = [aws_security_group.alb_sg.id]
}

# Target Group: define como o ALB encaminha tráfego para os targets
resource "aws_lb_target_group" "app" {
  name        = "${local.name}-tg"
  port        = local.container_port
  protocol    = "HTTP"
  target_type = "ip"             # Usa IPs (necessário para Fargate)
  vpc_id      = module.vpc.vpc_id

  # Configuração de health check
  health_check {
    path                = "/health"        # Endpoint de health check
    port                = "traffic-port"   # Usa a mesma porta do tráfego
    healthy_threshold   = 2                # Considera saudável após 2 checks bem-sucedidos
    unhealthy_threshold = 2                # Considera não saudável após 2 falhas
    timeout             = 5                # Timeout de 5 segundos
    interval            = 30               # Verifica a cada 30 segundos
    matcher             = "200"            # Código HTTP esperado
  }
}

# Listener do ALB: escuta na porta 80 e encaminha para o Target Group
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  # Ação padrão: encaminha para o Target Group
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# ecs service
# Cria serviço ECS que mantém as tasks em execução
resource "aws_ecs_service" "app" {
  name            = "${local.name}-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.app.arn
  launch_type     = "FARGATE"
  desired_count   = 1 # Número de tasks desejadas em execução

  # Configuração de rede para as tasks
  network_configuration {
    subnets         = module.vpc.private_subnets # Tasks em subnets privadas
    security_groups = [aws_security_group.ecs_sg.id]
    assign_public_ip = false # Não atribui IP público (usa NAT Gateway)
  }

  # Integração com o Load Balancer
  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = local.container_port
  }

  # Garante que o listener seja criado antes do serviço
  depends_on = [
    aws_lb_listener.http
  ]
}

# outputs
# Output com o DNS do Application Load Balancer
output "alb_dns" {
  value = aws_lb.app.dns_name
}

