import logging
import re
import boto3
from io import BytesIO
from pypdf import PdfReader
from worker.app.config import Config

logger = logging.getLogger(__name__)

s3_client = boto3.client('s3', region_name=Config.AWS_REGION)


def extract_cnpj_from_pdf(bucket_name: str, object_key: str):
    try:
        logger.info(f"Downloading PDF from S3:{bucket_name}/{object_key}")
        response = s3_client.get_object(Bucket=bucket_name, Key=object_key)
        pdf_bytes = BytesIO(response['Body'].read())
        reader = PdfReader(pdf_bytes)
        text = ""
        for page in reader.pages:
            text += page.extract_text() or ""
        pattern = r'\d{2}\.?\d{3}\.?\d{3}/?\d{4}-?\d{2}'
        cnpjs = re.findall(pattern, text)
        logger.info(f"Extration complete. Found {len(cnpjs)} CNPJs")
        return cnpjs
    except Exception as e:
        logger.error(f"Error ocurred while processing PDF {object_key}: {e}")
        raise e
