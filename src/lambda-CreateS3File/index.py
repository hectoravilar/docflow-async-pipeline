"""
Function name: CreateS3File
Runner: AWS Lambda
Handler: lambda_handler
Language: Python3.12
Variables: bucket_name

Description:
This is an AWS Lambda function to create an File in the S3 Bucket.
The file name should be the current time and date, following UTC.s
"""
import boto3
import os
from datetime import datetime

def lambda_handler(event, context):
    s3 = boto3.client('s3')
    bucket_name = os.environ['bucket_name']
    filename = datetime.utcnow().strftime('%Y-%m-%d_%H-%M-%S.txt')
    
    s3.put_object(
        Bucket=bucket_name,
        Key=filename,
        Body=f'File created at {datetime.utcnow().isoformat()}Z'
    )
    
    return {'statusCode': 200, 'body': f'File {filename} created successfully'}
