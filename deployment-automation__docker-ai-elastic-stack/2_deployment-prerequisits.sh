#!/bin/bash

# Script to install Docker, AWS CLI, authenticate with AWS, and set up an encrypted CodeCommit repository which we have installed a specific python version for.
# Author: [Mahmoud AbdelFattah]
# Date: Jan 02, 2023

# Exit on errors, undefined variables, or pipeline failures
set -euo pipefail

# Constants
readonly PYTHON_VERSION="${1:-}"  # Python version from first argument (e.g., 3.9)
readonly ENV_DIR="${HOME}/env"    # Directory for virtual environment
readonly DOCKER_GPG_KEY="/etc/apt/keyrings/docker.gpg"
readonly DOCKER_REPO_FILE="/etc/apt/sources.list.d/docker.list"

# Colors for output
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly NC='\033[0m' # No Color

# Docker dependencies array
readonly -a DOCKER_DEPS=(
    ca-certificates
    curl
    gnupg
    lsb-release
)

# log_info: Outputs an informational message in green to stdout.
# Parameters:
#   $1 - The message to display.
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# log_error: Outputs an error message in red to stderr and exits with failure.
# Parameters:
#   $1 - The error message to display.
log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

# command_exists: Checks if a given command is available in the system.
# Parameters:
#   $1 - The command name to check (e.g., "docker", "aws").
# Returns:
#   0 (true) if the command exists, 1 (false) otherwise.
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# install_docker: Installs Docker and Docker Compose if not already present.
# Parameters: None
# Dependencies: Requires sudo privileges and an apt-based system (e.g., Ubuntu).
install_docker() {
    log_info "Installing Docker and Docker Compose..."
    if command_exists docker; then
        log_info "Docker is already installed"
        sleep 1
    else
        log_info "Updating package index..."
        sudo apt-get update || log_error "Failed to update package index"

        log_info "Installing Docker dependencies..."
        for dep in "${DOCKER_DEPS[@]}"; do
            if dpkg -s "$dep" >/dev/null 2>&1; then
                log_info "$dep is already installed"
            else
                sudo apt-get install -y "$dep" || log_error "Failed to install $dep"
            fi
        done

        log_info "Adding Docker's official GPG key..."
        sudo mkdir -p /etc/apt/keyrings || log_error "Failed to create keyrings directory"
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o "$DOCKER_GPG_KEY" || log_error "Failed to add GPG key"
        sudo chmod a+r "$DOCKER_GPG_KEY" || log_error "Failed to set permissions on GPG key"

        log_info "Setting up Docker stable repository..."
        echo "deb [arch=$(dpkg --print-architecture) signed-by=$DOCKER_GPG_KEY] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee "$DOCKER_REPO_FILE" >/dev/null || log_error "Failed to set up repository"

        log_info "Updating packages with new repository..."
        sudo apt-get update -y || log_error "Failed to update packages"

        log_info "Installing Docker..."
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin || log_error "Failed to install Docker"

        log_info "Installing Docker Compose..."
        sudo apt install -y docker-compose || log_error "Failed to install Docker Compose"

        log_info "Adding user to docker group..."
        sudo usermod -aG docker "${USER}" || log_error "Failed to add user to docker group"

        if command_exists docker; then
            log_info "Docker successfully installed"
            sleep 1
        else
            log_error "Docker installation failed"
        fi
    fi
}

# install_aws_cli: Installs the AWS CLI if not already present.
# Parameters: None
# Dependencies: Requires sudo privileges and an apt-based system.
install_aws_cli() {
    log_info "Installing AWS CLI..."
    sleep 1
    if command_exists aws; then
        log_info "AWS CLI is already installed"
    else
        log_info "Updating package index..."
        sudo apt-get update -y || log_error "Failed to update package index"

        log_info "Installing AWS CLI..."
        sudo apt-get install -y awscli || log_error "Failed to install AWS CLI"

        if command_exists aws; then
            log_info "AWS CLI successfully installed"
        else
            log_error "AWS CLI installation failed"
        fi
    fi
}

# authenticate_aws_cli: Configures AWS CLI credentials if not already set.
# Parameters: None
# Dependencies: Requires awscli to be installed.
authenticate_aws_cli() {
    log_info "Configuring AWS CLI authentication..."
    sleep 1

    if grep -i "default" ~/.aws/credentials >/dev/null 2>&1; then
        log_info "Default IAM profile already configured"
    else
        log_info "No default credentials found. Prompting for AWS credentials..."
        read -p "Enter your aws_access_key_id: " AWS_ACCESS_KEY_ID
        read -p "Enter your aws_secret_access_key: " AWS_ACCESS_KEY_SECRET
        read -p "Enter your default region: " AWS_REGION

        if [[ -n "$AWS_ACCESS_KEY_ID" && -n "$AWS_ACCESS_KEY_SECRET" && -n "$AWS_REGION" ]]; then
            aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID" || log_error "Failed to set access key"
            aws configure set aws_secret_access_key "$AWS_ACCESS_KEY_SECRET" || log_error "Failed to set secret key"
            aws configure set default.region "$AWS_REGION" || log_error "Failed to set region"
            sleep 1
            log_info "IAM user successfully connected to AWS APIs"
        else
            log_error "One or more credentials are empty"
        fi
    fi
}

# install_git_remote_codecommit: Installs git-remote-codecommit for CodeCommit authentication.
# Parameters:
#   $1 - Python version to use (e.g., 3.9).
# Dependencies: Requires Python and pip for the specified version.
install_git_remote_codecommit() {
    local py_version="$1"
    log_info "Installing git-remote-codecommit for CodeCommit authentication..."
    sleep 2

    if command_exists git-remote-codecommit; then
        log_info "git-remote-codecommit is already installed"
        sleep 1
    else
        log_info "Creating isolated Python environment..."
        if [[ ! -d "$ENV_DIR" ]]; then
            mkdir -p "$ENV_DIR" || log_error "Failed to create $ENV_DIR"
        fi
        cd "$ENV_DIR" || log_error "Failed to change to $ENV_DIR"
        "python${py_version}" -m venv "env-py${py_version}" || log_error "Failed to create virtual environment"
        source "env-py${py_version}/bin/activate" || log_error "Failed to activate virtual environment"

        log_info "Installing git and git-remote-codecommit..."
        sudo apt install -y git || log_error "Failed to install git"
        "pip${py_version}" install git-remote-codecommit || log_error "Failed to install git-remote-codecommit"

        if command_exists git-remote-codecommit; then
            log_info "git-remote-codecommit successfully installed"
        else
            log_error "git-remote-codecommit installation failed"
        fi
    fi
}

# clone_encrypted_repo: Clones an encrypted CodeCommit repository.
# Parameters:
#   $1 - Directory to clone into (e.g., $HOME/env).
#   $2 - Python version Compatible with the cloned repo code (e.g., 3.9)
# Dependencies: Requires python compatible version, git-remote-codecommit utility and AWS CLI configured.
clone_encrypted_repo() {
    local env_dir="$1"
    local py_version="$2"
    log_info "Cloning encrypted CodeCommit repository..."
    sleep 2

    if ! command_exists git-remote-codecommit; then
        log_error "git-remote-codecommit not installed. Run install_git_remote_codecommit first."
    fi

    read -p "Enter the name of the encrypted repository in CodeCommit: " encr_repo
    local repo_dir="${env_dir}/${encr_repo}"

    if [[ -d "$repo_dir" ]]; then
        log_info "Repository $encr_repo already cloned at $repo_dir"
    else
        if [[ ! -d "$env_dir" ]]; then
            mkdir -p "$env_dir" || log_error "Failed to create $env_dir"
        fi
        cd "$env_dir" || log_error "Failed to change to $env_dir"
        git clone "codecommit::us-east-1://$encr_repo" "$encr_repo" || log_error "Failed to clone repository $encr_repo"
        cd "$encr_repo" || log_error "Failed to change to $repo_dir"

        if [[ -f "requirements.txt" ]]; then
            log_info "Installing repository dependencies..."
            "pip${py_version}" install -r requirements.txt || log_error "Failed to install requirements"
        fi

        if [[ -d "$repo_dir" ]]; then
            log_info "Repository $encr_repo cloned successfully to $repo_dir"
        else
            log_error "Repository cloning failed"
        fi
    fi
}

# main: Orchestrates the installation and setup process.
# Parameters: None (uses global PYTHON_VERSION)
main() {
    if [[ -z "$PYTHON_VERSION" ]]; then
        log_error "Python version not specified. Usage: $0 <python_version> (e.g., 3.9)"
    fi

    if ! command_exists "python${PYTHON_VERSION}"; then
        log_error "Python ${PYTHON_VERSION} not found. Please install it first."
    fi

    install_docker
    install_aws_cli
    authenticate_aws_cli
    install_git_remote_codecommit "$PYTHON_VERSION"
    clone_encrypted_repo "$ENV_DIR" "$PYTHON_VERSION"
}

# Trap interrupts for clean exit
trap 'log_info "Script interrupted by user"; exit 0' INT

# Execute main
main