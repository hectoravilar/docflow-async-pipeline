# Docflow

Docflow is a high-performance, **Asynchronous Event-Driven Document Processing Pipeline**. It allows users to upload receipts or invoices which are then processed in the background to extract critical metadata such as total amounts, dates, and Tax IDs (CNPJ).

## Objective
The primary goal is to provide a seamless, non-blocking user experience. By utilizing **Presigned URLs**, the system ensures secure file transfers while offloading heavy extraction tasks (OCR/Parsing) to a scalable backend architecture.

##  Tech Stack
* **Language:** Python
* **Document Processing:** PyPDF2 / OCR (Tesseract or AWS Textract)
* **Frontend Hosting:** AWS CloudFront + S3 (Static Web Hosting)
* **Messaging/Queuing:** AWS SQS
* **Containerization:** Docker on AWS ECS (Fargate/EC2)
* **Database:** AWS RDS PostgreSQL

##  Architecture & Workflow
1. **Secure Upload:** The frontend requests a **Presigned URL** from S3 to upload the document directly, reducing server overhead.
2. **Event Trigger:** Once the upload is complete, an event is sent to **AWS SQS**.
3. **Background Processing:** A Python worker running on **Docker (ECS)** consumes the message, processes the file, and extracts data.
4. **Persistence:** The extracted metadata is stored in **RDS PostgreSQL** for user retrieval.

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
| **RDS** | Fully managed PostgreSQL database for metadata storage. |

## Documentation & References used
- For [Presigned URLs](https://docs.aws.amazon.com/boto3/latest/guide/s3-presigned-urls.html)
- For [Logging](https://docs.python.org/3/howto/logging.html)