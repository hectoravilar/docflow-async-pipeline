import boto3
import json
import logging


from app.config import Config
from app.database import save_document

logger = logging.getLogger(__name__)

sqs_client = boto3.client('sqs', region_name=Config.AWS_REGION)


def process_messages():

    try:
        response = sqs_client.receive_message(
            QueueUrl=Config.SQS_QUEUE_URL,
            MaxNumberOfMessages=10,
            WaitTimeSeconds=20
        )
        if 'Messages' in response:
            for message in response['Messages']:
                try:
                    body = json.loads(message['Body'])
                    document_id = body.get('document_id')
                    s3_path = body.get('s3_path')
                    if document_id and s3_path:
                        save_document(document_id, s3_path)
                        logger.info(
                            f"Processed document {document_id} from SQS")
                    else:
                        logger.warning(
                            f"Invalid message format: {message['Body']}")
                        sqs_client.delete_message(
                            QueueUrl=Config.SQS_QUEUE_URL,
                            ReceiptHandle=message['ReceiptHandle']
                        )
                except Exception as e:
                    logger.error(f"Error processing message: {e}")
        else:
            logger.error(f"No messages in queue. Waiting...")

    except Exception as e:
        logger.error(f"Error connecting to SQS: {e}")
