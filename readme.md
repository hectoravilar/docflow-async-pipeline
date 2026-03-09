# Dreamsquad App
## Objetivo
Criar um site estatico simples para demonstrar um pipeline CI/CD na AWS. 
## Requisitos 
- Configure uma aplicação de FrontEnd estático simples. Pode ser uma aplicação
de exemplo, com alguma funcionalidade básica.
- Configure o deploy de uma aplicação de BackEnd utilizando tecnologia de
container. Pode ser uma aplicação de exemplo, com qualquer tipo de funcionalidade
- Configure um serviço que executa uma rotina diária às 10:00am para inserir um
arquivo no S3. O nome do arquivo deve ser a data/hora exata da execução da rotina
- A infraestrutura deve ser criada utilizando Terraform.

## Tecnologias 
- O Frontend estatico deve ser hospedado no AWS S3.
- O Frontend deve chamar uma api do backend.
- O Backend deve ser hospedado no AWS ECS Fargate.
- O Backend deve utilizar Python.
- Deve ser criado um scheduler para criar um arquivo no S3 utilizando AWS EventBridge.
- A infraestrutura deve ser testada com TFLint e Checkov.
- O backend deve possuir Unit Tests e deve ser testado com PyLint e Bandit
- O registro de imagens Docker deve utilizar o AWS ECR
- O EventBridge deve acionar uma Lambda para criar um arquivo no bucket S3
## Pipeline CI/CD
- O pipeline deve conter as seguintes etapas Build, Test, Deploy.
- O build deve criar os artefatos do conteiner e da aplicacao.
- A etapa de Test deve executar os linters, Unit tests, e testes de seguranca.
- Apos os testes deve ser gerada  imagem docker e  armazenada no AWS ECR.
- A etapa de Deploy deve atualizar a imagem do ECS fargate.
## Servicos AWS
- S3: Para hospedar o frontend estático e armazenar os arquivos gerados pela rotina diária.
- ECS Fargate: Para hospedar o backend em containers.
- EventBridge: Para agendar a rotina diária que insere arquivos no S3. 
- Lambda: Para criar um arquivo no S3 quando acionada pelo EventBridge.
- ECR: Para armazenar as imagens Docker do backend. 
- CodePipeline: Para orquestrar o pipeline CI/CD.
- CodeBuild: Para executar as etapas de build, test e deploy no pipeline CI/CD.
## Observações
