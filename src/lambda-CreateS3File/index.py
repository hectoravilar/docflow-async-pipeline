"""Lambda para criar arquivo diário no S3.

Esta função é acionada pelo EventBridge às 10:00am diariamente
para inserir um arquivo no bucket S3 com timestamp da execução.
"""

import boto3
import os
from datetime import datetime

def lambda_handler(event, context):
    """Handler principal da função Lambda.
    
    Args:
        event: Evento recebido do EventBridge
        context: Contexto de execução da Lambda
        
    Returns:
        dict: Resposta com statusCode e mensagem de sucesso
    """
    # Inicializa cliente S3
    s3 = boto3.client('s3')
    
    # Obtém nome do bucket da variável de ambiente
    bucket_name = os.environ['bucket_name']
    
    # Gera nome do arquivo com data/hora da execução
    filename = datetime.utcnow().strftime('%Y-%m-%d_%H-%M-%S.txt')
    
    # Cria arquivo no S3 com conteúdo contendo timestamp
    s3.put_object(
        Bucket=bucket_name,
        Key=filename,
        Body=f'File created at {datetime.utcnow().isoformat()}Z'
    )
    
    return {'statusCode': 200, 'body': f'File {filename} created successfully'}
