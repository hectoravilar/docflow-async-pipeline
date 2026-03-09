#Imagem base original do Docker Hub (comentada devido ao Rate Limit)
# FROM python:3.12-slim

# Espelho oficial da AWS (ECR Public Gallery) para evitar bloqueios no CodeBuild
FROM public.ecr.aws/docker/library/python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

EXPOSE 8080

CMD ["python", "app.py"]