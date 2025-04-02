#!/bin/bash

# Script to automate startup of Elasticsearch, QnA, and Sentiment services.
# Author: [Mahmoud AbdelFattah]
# Date: Jan 02, 2023

# Exit on errors, undefined variables, or pipeline failures
set -euo pipefail

# Constants
readonly ES_DIR="${HOME}/env/opendistro_es"
readonly QNA_DIR="${HOME}/env/qna"
readonly AR_SENT_DIR="${HOME}/env/ar_sent"
readonly EN_SENT_DIR="${HOME}/env/en_sent"
readonly QNA_SERVICE="qna"
readonly AR_SENT_SERVICE="ar-sentiment"
readonly EN_SENT_SERVICE="en-sentiment"

# Colors for output
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly NC='\033[0m' # No Color

# log_info: Outputs an informational message in green to stdout.
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# log_error: Outputs an error message in red to stderr and exits with failure.
log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

# cleanup_docker: Removes exited containers.
cleanup_docker() {
    log_info "Cleaning up previous Docker environments..."
    docker rm -v $(docker ps --filter status=exited -q 2>/dev/null) 2>/dev/null || true
}

# remove_stopped_container: Removes a stopped container if it exists.
remove_stopped_container() {
    local container="$1"
    local state
    state=$(docker inspect "$container" --format "{{.State.Running}}" 2>/dev/null || echo "false")

    if [[ "$state" == "false" ]]; then
        docker rm -v "$container" 2>/dev/null || log_error "Failed to remove $container"
        log_info "Removed stopped container $container"
    elif [[ "$state" == "true" ]]; then
        log_info "$container already running"
    fi
}

# start_opensearch: Starts Elasticsearch services.
start_opensearch() {
    log_info "Starting OpenSearch services..."
    cd "$ES_DIR" || log_error "Failed to change to $ES_DIR"
    docker-compose down 2>/dev/null || true
    docker-compose up -d || log_error "Failed to start OpenSearch"
    log_info "OpenSearch started"
}

# start_qna: Starts the QnA service.
start_qna() {
    log_info "Starting QnA service..."
    remove_stopped_container "$QNA_SERVICE"
    docker run -dp 8081:8081 --name "$QNA_SERVICE" \
        -v "${QNA_DIR}/.env:/qna/.env" \
        -v "${QNA_DIR}/logs:/qna/logs" \
        "dkr.ecr.us-east-1.amazonaws.com/on-prem" || log_error "Failed to start QnA"
    log_info "QnA started"
}

# start_ar_sentiment: Starts the Arabic Sentiment service.
start_ar_sentiment() {
    log_info "Starting Arabic Sentiment service..."
    remove_stopped_container "$AR_SENT_SERVICE"
    docker run -dp 8084:8084 --name "$AR_SENT_SERVICE" \
        -v "${AR_SENT_DIR}/.env:/ar-multi-sentiment-analysis/.env" \
        -v "${AR_SENT_DIR}/logs:/ar-multi-sentiment-analysis/logs" \
        "dkr.ecr.us-east-1.amazonaws.com/ar-sentiment" || log_error "Failed to start Arabic Sentiment"
    log_info "Arabic Sentiment started"
}

# start_en_sentiment: Starts the English Sentiment service.
start_en_sentiment() {
    log_info "Starting English Sentiment service..."
    remove_stopped_container "$EN_SENT_SERVICE"
    docker run -dp 8085:8085 --name "$EN_SENT_SERVICE" \
        -v "${EN_SENT_DIR}/.env:/en-multi-sentiment-analysis/.env" \
        -v "${EN_SENT_DIR}/logs:/en-multi-sentiment-analysis/logs" \
        "dkr.ecr.us-east-1.amazonaws.com/en-sentiment" || log_error "Failed to start English Sentiment"
    log_info "English Sentiment started"
}

# main: Orchestrates the service startup process.
main() {
    cleanup_docker
    start_opensearch
    start_qna
    start_ar_sentiment
    start_en_sentiment
}

# Trap interrupts for clean exit
trap 'log_info "Script interrupted by user"; exit 0' INT

# Execute main
main