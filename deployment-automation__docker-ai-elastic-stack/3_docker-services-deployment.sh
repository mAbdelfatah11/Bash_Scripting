#!/bin/bash

# Script to deploy Elasticsearch, QnA, and Sentiment services with encrypted .env files.
# Author: [Mahmoud AbdelFattah]
# Date: Jan 02, 2023

# Exit on errors, undefined variables, or pipeline failures
set -euo pipefail

# Constants
readonly PYTHON_VERSION="${1:-}"  # Python version from first argument (e.g., 3.9)
readonly SCRIPT_DIR="$(pwd)"
readonly ES_DIR="${HOME}/env/opendistro_es"
readonly QNA_DIR="${HOME}/env/qna"
readonly AR_SENT_DIR="${HOME}/env/ar_sent"
readonly EN_SENT_DIR="${HOME}/env/en_sent"
readonly ES_CONTAINER="odfe-node1"
readonly ES_AUTH_FILE="es_auth.sh"
readonly DISK_SERIAL="5916P1XFT"  # Hardcoded as per original
readonly ENCR_REPO="${HOME}/env/encryption-script"
readonly QNA_SERVICE="qna"
readonly AR_SENT_SERVICE="ar-sentiment"
readonly EN_SENT_SERVICE="en-sentiment"

# Colors for output
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly NC='\033[0m' # No Color

# Arrays for S3 resources and environment files
readonly -a S3_RESOURCES=(
    "${QNA_DIR}/.env"
    "${AR_SENT_DIR}/.env"
    "${EN_SENT_DIR}/.env"
)
readonly -a ENV_FILES=(
    "${QNA_DIR}/.env"
    "${AR_SENT_DIR}/.env"
    "${EN_SENT_DIR}/.env"
)

# log_info: Outputs an informational message in green to stdout.
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# log_error: Outputs an error message in red to stderr and exits with failure.
log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

# command_exists: Checks if a given command is available in the system.
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# install_prerequisites: Installs required files and directories from S3.
install_prerequisites() {
    log_info "Installing required files..."
    for dir in "$ES_DIR" "$QNA_DIR" "$AR_SENT_DIR" "$EN_SENT_DIR"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir" || log_error "Failed to create $dir"
        fi
    done

    if [[ ! -f "${ES_DIR}/docker-compose.yml" ]]; then
        log_info "Elasticsearch docker-compose.yml not found"
        read -p "Enter the S3 URI for docker-compose.yml [e.g., s3://wb-ai/qna/qna-deployment/docker-compose.yml]: " compose_file
        aws s3 cp "$compose_file" "$ES_DIR" || log_error "Failed to download docker-compose.yml from $compose_file"
    fi

    for s3_file in "${S3_RESOURCES[@]}"; do
        if [[ ! -f "$s3_file" ]]; then
            log_info "Installing .env file for $s3_file..."
            read -p "Enter the S3 URI for $s3_file [e.g., s3://wb-ai/{object-location}]: " loaded_file
            aws s3 cp "$loaded_file" "${s3_file%/*}" --region us-east-1 || log_error "Failed to download $loaded_file"
        else
            log_info "Prerequisite file $s3_file already installed"
        fi
    done
}

# deploy_elasticsearch: Deploys Elasticsearch and Kibana using Docker Compose.
deploy_elasticsearch() {
    log_info "Deploying Elasticsearch and Kibana..."
    if docker ps | grep -q "$ES_CONTAINER"; then
        log_info "Elasticsearch container $ES_CONTAINER already running"
    else
        log_info "Setting vm.max_map_count for Elasticsearch..."
        sudo sysctl -w "vm.max_map_count=262144" || log_error "Failed to set vm.max_map_count"
        sudo chmod o+w /etc/sysctl.conf || log_error "Failed to set permissions on sysctl.conf"
        echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf >/dev/null || log_error "Failed to update sysctl.conf"

        cd "$ES_DIR" || log_error "Failed to change to $ES_DIR"
        sudo docker-compose down 2>/dev/null || true
        sudo docker-compose up -d || log_error "Failed to start Elasticsearch"
        log_info "Waiting 20 seconds for Elasticsearch to initialize..."
        sleep 20
    fi

    cd "$SCRIPT_DIR" || log_error "Failed to return to $SCRIPT_DIR"
    local es_running
    es_running=$(docker inspect "$ES_CONTAINER" --format "{{.State.Running}}" 2>/dev/null || echo "false")
    if [[ "$es_running" == "true" ]]; then
        log_info "Elasticsearch initialized successfully"
        sleep 2
        configure_env_files
    else
        log_error "Elasticsearch failed to initialize"
    fi
}

# configure_env_files: Configures and optionally encrypts .env files for QnA and Sentiment services.
configure_env_files() {
    log_info "Configuring .env files and applying encryption..."
    sleep 2

    log_info "List of QnA and Sentiment environment files to sync and encrypt:"
    for item in "${ENV_FILES[@]}"; do
        echo "$item"
    done
    sleep 2

    for env_file in "${ENV_FILES[@]}"; do
        local if_decrypted
        if_decrypted=$(file "$env_file" | grep -i "ASCII" || true)
        
        if [[ -f "$env_file" && -n "$if_decrypted" ]]; then
            if [[ "$env_file" == "${QNA_DIR}/.env" ]]; then
                log_info "Configuring QnA .env for Elasticsearch user..."
                sleep 2
                configure_qna_env "$env_file"
            elif [[ "$env_file" == "${AR_SENT_DIR}/.env" || "$env_file" == "${EN_SENT_DIR}/.env" ]]; then
                log_info "Configuring Sentiment .env for disk serial..."
                sleep 2
                configure_sentiment_env "$env_file" "$DISK_SERIAL"
            fi
        elif [[ -f "$env_file" && -z "$if_decrypted" ]]; then
            if [[ "$env_file" == "${QNA_DIR}/.env" ]]; then
                log_info "QnA .env file $env_file already encrypted"
                read -p "Decrypt to add a new Elasticsearch user? [y/n]: " decr
                if [[ "$decr" == "n" ]]; then
                    log_info "Proceeding with QnA deployment..."
                    deploy_qna
                else
                    log_info "Decrypting $env_file..."
                    decrypt_env_file "$env_file"
                    log_info "Reconfiguring QnA .env with new Elasticsearch user..."
                    sleep 2
                    configure_qna_env "$env_file"
                fi
            elif [[ "$env_file" == "${AR_SENT_DIR}/.env" || "$env_file" == "${EN_SENT_DIR}/.env" ]]; then
                log_info "Sentiment .env file $env_file already encrypted"
                read -p "Decrypt? [y/n]: " decr
                if [[ "$decr" == "n" ]]; then
                    if [[ "$env_file" == "${AR_SENT_DIR}/.env" ]]; then
                        log_info "Proceeding with Arabic Sentiment deployment..."
                        deploy_ar_sentiment
                    else
                        log_info "Proceeding with English Sentiment deployment..."
                        deploy_en_sentiment
                    fi
                else
                    log_info "Decrypting $env_file..."
                    decrypt_env_file "$env_file"
                fi
            fi
        fi
    done
}

# configure_qna_env: Configures QnA .env with Elasticsearch credentials and encrypts it.
configure_qna_env() {
    local env_file="$1"
    read -p "Enter the new Elasticsearch username: " es_user
    local qna_marker="#qna-envfile-Configured-with-the-Following-ES-user:${es_user}"

    if grep -Fxq "$qna_marker" "$env_file"; then
        log_info "File $env_file already configured with user $es_user"
        encrypt_env_file "$env_file"
        deploy_qna
    else
        read -p "Enter the user password (chars only, no numbers): " es_pass
        log_info "Adding $es_user to Elasticsearch..."
        sudo docker exec "$ES_CONTAINER" bash -c "rm /tmp/es_auth*" 2>/dev/null || true
        sudo docker cp "${SCRIPT_DIR}/${ES_AUTH_FILE}" "${ES_CONTAINER}:/tmp/" || log_error "Failed to copy $ES_AUTH_FILE"
        sudo docker exec "$ES_CONTAINER" bash -c ". /tmp/${ES_AUTH_FILE} ${es_user} ${es_pass}" >> es_auth_ScriptOutput.txt 2>/dev/null || log_error "Failed to execute $ES_AUTH_FILE"

        local es_line="'https://${es_user}:${es_pass}@172.17.0.1:9200'"
        sudo sed -i "/^#qna-envfile.*$/d" "$env_file" || log_error "Failed to clean $env_file"
        sudo sed -i "/^ES_CONNECTION.*$/d" "$env_file" || log_error "Failed to update $env_file"
        echo -e "$qna_marker\nES_CONNECTION_LINE=${es_line}" | sudo tee -a "$env_file" >/dev/null || log_error "Failed to append to $env_file"
        sudo sed -i "s/^DISK_SERIAL.*$/DISK_SERIAL=${DISK_SERIAL}/g" "$env_file" || log_error "Failed to set DISK_SERIAL"

        if grep -Fxq "$qna_marker" "$env_file"; then
            log_info "QnA .env synced with ES user $es_user"
            grep -i "ES_CONNECTION_LINE" "$env_file"
            encrypt_env_file "$env_file"
            deploy_qna
        else
            log_error "Failed to configure $env_file with ES user $es_user"
        fi
    fi
}

# configure_sentiment_env: Configures Sentiment .env with disk serial and encrypts it.
configure_sentiment_env() {
    local env_file="$1"
    local disk_serial="$2"
    local sent_marker="#envfile-added-with-serial-${disk_serial}"

    if grep -i "$sent_marker" "$env_file"; then
        log_info "File $env_file already configured with disk serial"
        encrypt_env_file "$env_file"
        if [[ "$env_file" == "${AR_SENT_DIR}/.env" ]]; then
            deploy_ar_sentiment
        else
            deploy_en_sentiment
        fi
    else
        sudo sed -i "s/^DISK_SERIAL.*$/${sent_marker}\nDISK_SERIAL=${disk_serial}/g" "$env_file" || log_error "Failed to update $env_file"
        if grep -i "$sent_marker" "$env_file"; then
            log_info "Disk serial added to $env_file"
            sleep 1
            encrypt_env_file "$env_file"
            if [[ "$env_file" == "${AR_SENT_DIR}/.env" ]]; then
                deploy_ar_sentiment
            else
                deploy_en_sentiment
            fi
        else
            log_error "Failed to configure $env_file with disk serial"
        fi
    fi
}

# encrypt_env_file: Encrypts an .env file using the encryption repository script.
encrypt_env_file() {
    local env_file="$1"
    sleep 2
    if [[ ! -d "$ENCR_REPO" ]]; then
        log_error "Encryption repository not found at $ENCR_REPO. Run the previous deployment script first."
    fi
    log_info "Encrypting $env_file..."
    "python${PYTHON_VERSION}" "${ENCR_REPO}/main.py" encrypt "$env_file" --prompt || log_error "Failed to encrypt $env_file"
    log_info "$env_file encrypted successfully"
}

# decrypt_env_file: Decrypts an .env file using the encryption repository script.
decrypt_env_file() {
    local env_file="$1"
    sleep 2
    if [[ ! -d "$ENCR_REPO" ]]; then
        log_error "Encryption repository not found at $ENCR_REPO. Run the previous deployment script first."
    fi
    log_info "Decrypting $env_file..."
    "python${PYTHON_VERSION}" "${ENCR_REPO}/main.py" decrypt "$env_file" --prompt || log_error "Failed to decrypt $env_file"
    log_info "$env_file decrypted successfully"
}

# authenticate_ecr: Authenticates with AWS ECR and pulls an image.
authenticate_ecr() {
    log_info "Authenticating to AWS ECR repository..."
    sleep 1

    read -p "Enter the ECR repository name [e.g., 074697765782.dkr.ecr.us-east-1.amazonaws.com/qna]: " ECR_REPO
    read -p "Enter the image tag [e.g., on-prem]: " IMG_TAG
    read -p "Enter your default region: " AWS_REGION

    if [[ -n "$ECR_REPO" && -n "$IMG_TAG" && -n "$AWS_REGION" ]]; then
        log_info "Checking image availability with current ECR token..."
        sleep 2
        if docker pull "$ECR_REPO:$IMG_TAG" 2>/dev/null; then
            log_info "Docker image $ECR_REPO:$IMG_TAG pulled successfully with existing token"
        else
            log_info "Existing ECR token invalid. Fetching new token..."
            docker login -u AWS -p "$(aws ecr get-login-password --region "$AWS_REGION")" "$ECR_REPO" || log_error "Failed to authenticate with ECR"
            log_info "Pulling image $ECR_REPO:$IMG_TAG..."
            docker pull "$ECR_REPO:$IMG_TAG" || log_error "Failed to pull $ECR_REPO:$IMG_TAG"
        fi
    else
        log_error "Missing ECR repository, tag, or region"
    fi
}

# deploy_qna: Deploys the QnA service from ECR.
deploy_qna() {
    log_info "Deploying QnA service..."
    sleep 2
    if ! docker image ls | grep -q "$QNA_SERVICE"; then
        authenticate_ecr
    fi

    docker rm -vf "$QNA_SERVICE" 2>/dev/null || true
    docker run -dp 8081:8081 --name "$QNA_SERVICE" \
        -v "${QNA_DIR}/.env:/qna/.env" \
        -v "${QNA_DIR}/logs/:/qna/logs" \
        -v /run/udev:/run/udev:ro \
        --privileged --pid=host \
        "074697765782.dkr.ecr.us-east-1.amazonaws.com/qna:on-prem" || log_error "Failed to deploy QnA"
    log_info "QnA deployed successfully"
}

# deploy_ar_sentiment: Deploys the Arabic Sentiment service from ECR.
deploy_ar_sentiment() {
    log_info "Deploying Arabic Sentiment service..."
    sleep 2
    if ! docker image ls | grep -q "$AR_SENT_SERVICE"; then
        authenticate_ecr
    fi

    docker rm -vf "$AR_SENT_SERVICE" 2>/dev/null || true
    docker run -dp 8084:8084 --name "$AR_SENT_SERVICE" \
        -v "${AR_SENT_DIR}/.env:/ar-multi-sentiment-analysis/.env" \
        -v "${AR_SENT_DIR}/logs:/ar-multi-sentiment-analysis/logs" \
        "074697765782.dkr.ecr.us-east-1.amazonaws.com/ar-sentiment:on-prem" || log_error "Failed to deploy Arabic Sentiment"
    log_info "Arabic Sentiment deployed successfully"
}

# deploy_en_sentiment: Deploys the English Sentiment service from ECR.
deploy_en_sentiment() {
    log_info "Deploying English Sentiment service..."
    sleep 2
    if ! docker image ls | grep -q "$EN_SENT_SERVICE"; then
        authenticate_ecr
    fi

    docker rm -vf "$EN_SENT_SERVICE" 2>/dev/null || true
    docker run -dp 8085:8085 --name "$EN_SENT_SERVICE" \
        -v "${EN_SENT_DIR}/.env:/en-multi-sentiment-analysis/.env" \
        -v "${EN_SENT_DIR}/logs:/en-multi-sentiment-analysis/logs" \
        "074697765782.dkr.ecr.us-east-1.amazonaws.com/en-sentiment:on-prem" || log_error "Failed to deploy English Sentiment"
    log_info "English Sentiment deployed successfully"
}

# main: Orchestrates the deployment process.
main() {
    if [[ -z "$PYTHON_VERSION" ]]; then
        log_error "Python version not specified. Usage: $0 <python_version> (e.g., 3.9)"
    fi
    if ! command_exists "python${PYTHON_VERSION}"; then
        log_error "Python ${PYTHON_VERSION} not found. Please install it first."
    fi

    install_prerequisites
    deploy_elasticsearch
}

# Trap interrupts for clean exit
trap 'log_info "Script interrupted by user"; exit 0' INT

# Execute main
main