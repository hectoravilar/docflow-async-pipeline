# Dreamsquad App

## Objetivo
Criar um site estático simples para demonstrar um pipeline CI/CD completo e automatizado na AWS, utilizando as melhores práticas de Infraestrutura como Código.

## Requisitos
- Configurar uma aplicação de FrontEnd estático simples que consome a API do backend.
- Configurar o deploy de uma aplicação de BackEnd utilizando tecnologia de container.
- Configurar um serviço que executa uma rotina diária às 10:00am para inserir um arquivo no S3. O nome do arquivo gerado deve ser a data/hora exata da execução da rotina.
- Toda a infraestrutura deve ser provisionada utilizando Terraform.

## Tecnologias
- O Frontend estático é hospedado no AWS S3 e realiza chamadas para a API do backend.
- O Backend é desenvolvido em Python e hospedado no AWS ECS Fargate.
- Um scheduler é criado utilizando AWS EventBridge, que aciona uma Lambda para criar um arquivo no bucket S3.
- A infraestrutura é validada com TFLint e Checkov.
- O backend possui Unit Tests e é testado com PyLint e Bandit.
- O registro de imagens Docker utiliza o AWS ECR (com bypass de imagem para o Amazon ECR Public Gallery para evitar Rate Limit do Docker Hub).

## Pipeline CI/CD
O pipeline orquestra todo o fluxo com as seguintes etapas:
- **Build:** Cria os artefatos da aplicação e constrói a imagem Docker.
- **Test:** Executa os linters (PyLint), testes unitários, testes de segurança (Bandit) e valida a infraestrutura (TFLint e Checkov).
- **Deploy:** Após a geração e armazenamento da imagem Docker no AWS ECR, atualiza a imagem no ECS Fargate.

## Servicos AWS
- **S3**: Para hospedar o frontend estático e armazenar os arquivos gerados pela rotina diária.
- **ECS Fargate:** Para hospedar o backend em containers.
- **EventBridge:** Para agendar a rotina diária que insere arquivos no S3.
- **Lambda:** Para criar um arquivo no S3 quando acionada pelo EventBridge.
- **ECR:** Para armazenar as imagens Docker do backend.
- **CodePipeline:** Para orquestrar o pipeline CI/CD.
- **CodeBuild:** Para executar as etapas de build, test e deploy no pipeline CI/CD.

## Como Executar

### Configuração do Repositório (GitLab vs GitHub)
Por padrão, o pipeline está configurado para o GitLab. Se você for utilizar o GitHub, faça as seguintes alterações no arquivo cicd.tf:
1. No recurso **aws_codestarconnections_connection**, altere o **provider_type** para **"GitHub"**.
2. No recurso **aws_codepipeline**(na etapa Source), atualize o caminho do seu repositório:
   **FullRepositoryId** = "seu-usuario/seu-repositorio"

### Passos para Deploy
1. Clone este repositório.
2. Inicialize o **Terraform** para baixar os providers executando: **terraform init**
3. Valide o plano de infraestrutura executando: **terraform plan**
4. Aplique a configuração para criar os recursos na AWS executando: **terraform apply**
5. **Atenção:** Após o primeiro apply, acesse o console da AWS em **CodePipeline -> Settings -> Connections** para autorizar manualmente a conexão com o seu provedor **Git (GitLab ou GitHub).**
6. Após a autorização, realize um novo commit no seu repositório ou clique em **Release change no CodePipeline** para iniciar o primeiro deploy completo da aplicação.

## Observações
- Certifique-se de ter as credenciais da AWS configuradas na sua máquina.
- O Terraform deve estar na versão 1.5.0 ou superior.
- Este projeto foca na separação de responsabilidades (SoC), onde o Terraform cuida da infraestrutura e o CodeBuild cuida do ciclo de vida da aplicação.