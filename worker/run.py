import logging
import signal
import time
import os
import sys
from app.sqs_worker import process_messages

is_running = True


def handle_shutdown_signal(signum, frame):
    """Catches the termination signal and flips the kill switch"""
    global is_running
    logging.info(f"Caught signal {signum}. Initiating graceful shutdown...")
    is_running = False


def main():
    # Global config
    logging.basicConfig(
        # INFO is the sweet spot for production
        format='%(asctime)s:%(levelname)s:%(message)s', level=logging.INFO
    )
    # Spin up the logger for this module
    logger = logging.getLogger(__name__)

    signal.signal(signal.SIGTERM, handle_shutdown_signal)  # AWS/Docker signal
    signal.signal(signal.SIGINT, handle_shutdown_signal)

    # Tell the lifecycle story
    logger.info("Booting up the DocFLow Worker...")

    try:
        # Calls will go there
        logger.info("Fetching enviroment variables...")
        # load config()

        logger.info("Hooking up to the DynamoDB")
        # connect_db()

        logger.info(
            "listening to the SQS queue. Waiting for documents to drop...")
        # start_sqs_worker()

        while is_running:
            process_messages()

        logging.info("Worker gracefullly shut down!")

    except Exception as e:
        logger.error(f"Fatal error during worker startup: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
