# Docflow

Docflow is a high-performance, **Asynchronous Event-Driven Document Processing Pipeline**. It allows users to upload receipts or invoices which are then processed in the background to extract critical metadata such as total amounts, dates, and Tax IDs (CNPJ).

## Objective
The primary goal is to provide a seamless, non-blocking user experience. By utilizing **Presigned URLs**, the system ensures secure file transfers while offloading heavy extraction tasks (OCR/Parsing) to a scalable backend architecture.

## Tech Stack
* **Language:** Python
* **Document Processing:** PyPDF2 / OCR (Tesseract or AWS Textract)
* **Frontend Hosting:** AWS CloudFront + S3 (Static Web Hosting)
* **Messaging/Queuing:** AWS SQS
* **Containerization:** Docker on AWS ECS (Fargate/EC2)
* **Database:** DynamoDB

## Architecture & Workflow
1. **Secure Upload:** The frontend requests a **Presigned URL** from S3 to upload the document directly, reducing server overhead.
2. **Event Trigger:** Once the upload is complete, an event is sent to **AWS SQS**.
3. **Background Processing:** A Python worker running on **Docker (ECS)** consumes the message, processes the file, and extracts data.
4. **Persistence:** The extracted metadata is stored in **DynamoDB**.

## Current Progress (Backend Worker)
The core background worker infrastructure is currently built with production-ready patterns:
* **Graceful Shutdown:** Intercepts `SIGTERM` and `SIGINT` signals to prevent data corruption during container termination.
* **Fail-Fast Configuration:** Validates critical environment variables on startup, preventing silent failures.
* **SQS Long Polling:** Efficiently polls messages using `WaitTimeSeconds` to reduce AWS API costs, complete with poison-pill handling.
* **Serverless Persistence:** Integrates with DynamoDB to maintain document processing states and UTC audit trails.

## CI/CD Pipeline
The project implements a robust automation workflow:
* **Linting & Testing:** Automated Python unit tests.
* **Containerization:** Docker images are automatically built and pushed to **AWS ECR**.
* **Deployment:** Continuous Deployment to **AWS ECS** clusters via GitHub Actions or AWS CodePipeline.

## AWS Services Summary

| Service | Role |
| :--- | :--- |
| **CloudFront** | Global content delivery for the frontend. |
| **S3** | Secure object storage for document files. |
| **SQS** | Message broker to decouple upload and processing. |
| **ECS** | Managed container orchestration for the backend workers. |
| **DynamoDB** | Serverless NoSQL database to store document metadata and processing status. |

## Documentation & References used
- [Presigned URLs](https://docs.aws.amazon.com/boto3/latest/guide/s3-presigned-urls.html)
- [Logging](https://docs.python.org/3/howto/logging.html)
- [Signal Handlers](https://docs.python.org/3/library/signal.html)
- [Graceful shutdowns with ECS](https://aws.amazon.com/blogs/containers/graceful-shutdowns-with-ecs/)
- [classmethod() in Python](https://www.geeksforgeeks.org/python/classmethod-in-python/)
- [OOP in Python](https://realpython.com/python3-object-oriented-programming/)
- [ValueError](https://realpython.com/ref/builtin-exceptions/valueerror/)
- [DynamoDB Client](https://docs.aws.amazon.com/boto3/latest/reference/services/dynamodb.html)
- [DynamoDB put_item](https://docs.aws.amazon.com/boto3/latest/reference/services/dynamodb/client/put_item.html)
- [DynamoDB Table](https://docs.aws.amazon.com/boto3/latest/reference/services/dynamodb/table/)
- [SQS.Client.receive_message](https://docs.aws.amazon.com/boto3/latest/reference/services/sqs/client/receive_message.html)
- [Amazon SQS short and long polling](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-short-and-long-polling.html#sqs-long-polling)
- [SQS.Client.delete_message](https://docs.aws.amazon.com/boto3/latest/reference/services/sqs/client/delete_message.html)
- [S3.Client.get_object](https://docs.aws.amazon.com/boto3/latest/reference/services/s3/client/get_object.html#get-object)
- [Python Regex](https://www.w3schools.com/python/python_regex.asp)
- [pypdf lib: Exceptions, Warnings, Log messages](https://pypdf.readthedocs.io/en/3.17.1/user/suppress-warnings.html)