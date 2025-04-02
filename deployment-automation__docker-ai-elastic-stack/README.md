# QnA and Sentiment Analysis Deployment Suite

This repository contains a suite of Bash scripts to automate the setup, deployment, and management of a Dockerized environment for AI services backed by Elasticsearch stack on an Ubuntu-based system. The scripts sequentially build a secure, on-premises environment by creating a dedicated user, installing Python with SSL support, setting up Docker and AWS tools, deploying services with encrypted configurations, and ensuring automatic startup.

## Overview

These scripts work together to:
1. Create a dedicated user with sudo privileges.
2. Install a specific Python version with SSL support.
3. Install Docker, AWS CLI, and an encrypted CodeCommit repository for configuration management.
4. Deploy Elasticsearch, QnA, and Sentiment services with encrypted `.env` files.
5. Configure Elasticsearch users.
6. Set up automatic service startup via systemd.

The deployment targets an Ubuntu system, leveraging AWS services (S3, ECR, CodeCommit) and Docker for containerized applications.

## Prerequisites

- **Operating System**: Ubuntu (e.g., 20.04 or 22.04).
- **Software**:
  - Bash shell.
  - `sudo` privileges.
  - Internet access for downloading packages and AWS resources.
- **AWS Access**:
  - AWS CLI credentials with access to S3, ECR, and CodeCommit.
  - Permissions to pull images from `dkr.ecr.us-east-1.amazonaws.com`.
- **Files**:
  - `es_auth.sh` (for Elasticsearch user management).
  - `services-startup.service` (for systemd setup).

## Installation

1. **Clone the Repository**:
   ```bash
   git clone <repository-url>
   cd <repository-directory>
   ```

2. **Set Permissions**:
   ```bash
   chmod +x *.sh
   ```

## Usage

Run the scripts in sequence as described below. Each script builds on the previous one to complete the deployment.

### Step-by-Step Script Execution

#### 1. Create a Dedicated User (`create_user.sh`)
- **Purpose**: Creates a user `WB-Services` with sudo privileges and a home directory for service deployment.
- **Usage**:
  ```bash
  sudo ./create_user.sh
  ```
  - Prompts for a password for the new user.
- **Output**: Adds `WB-Services` to the system and grants passwordless sudo access via `/etc/sudoers`.
- **Next Step**: Log in as `WB-Services` manually or adjust subsequent scripts to run as this user.

#### 2. Install Python with SSL Support (`install_python.sh`)
- **Purpose**: Compiles and installs a specified Python version from source, ensuring SSL support for secure connections.
- **Usage**:
  ```bash
  ./install_python.sh 3.9
  ```
  - Replace `3.9` with your desired version (e.g., `3.9.10`).
- **Output**: Installs Python 3.9 with dependencies and configures it with OpenSSL.
- **Next Step**: Use this Python version for subsequent scripts requiring Python (e.g., encryption).

#### 3. Install Docker, AWS CLI, and Encryption Repo (`install_docker_aws.sh`)
- **Purpose**: Sets up Docker, AWS CLI, and clones an encrypted CodeCommit repository for configuration management.
- **Usage**:
  ```bash
  ./install_docker_aws.sh 3.9
  ```
  - Requires the Python version installed in Step 2.
- **Output**: Installs Docker and AWS CLI, configures AWS credentials, and clones the `encryption-script` repository into `$HOME/env`.
- **Next Step**: Proceed to deploy services using the installed tools.

#### 4. Deploy Services (`deploy_services.sh`)
- **Purpose**: Deploys Elasticsearch, QnA, and Sentiment services with encrypted `.env` files, pulling images from ECR.
- **Usage**:
  ```bash
  ./deploy_services.sh 3.9
  ```
  - Prompts for S3 URIs, Elasticsearch credentials, encryption keys, and ECR details.
- **Output**: Sets up Elasticsearch via Docker Compose, configures `.env` files with Elasticsearch credentials and disk serial, encrypts them, and deploys QnA and Sentiment containers.
- **Dependencies**: Requires `es_auth.sh` in the same directory and the `encryption-script` repository from Step 3.
- **Next Step**: Configure Elasticsearch users if needed (handled internally, but can be run separately).

#### 5. Configure Elasticsearch User (`es_auth.sh`)
- **Purpose**: Adds an admin user to Elasticsearch’s `internal_users.yml` (called by `deploy_services.sh`).
- **Usage** (if run independently):
  ```bash
  ./es_auth.sh <username> <password>
  ```
- **Output**: Updates Elasticsearch security config with the new user.
- **Context**: Typically executed within the `odfe-node1` container by `deploy_services.sh`.
- **Next Step**: Set up automatic startup.

#### 6. Enable Automatic Startup (`setup_service.sh` and `services_startup.sh`)
- **Purpose**: Configures services to start on boot.
- **Sub-steps**:
  1. **Start Services Manually (`services_startup.sh`)**:
     - **Purpose**: Cleans up Docker and starts Elasticsearch, QnA, and Sentiment services.
     - **Usage**:
       ```bash
       ./services_startup.sh
       ```
     - **Output**: Ensures all services are running.
  2. **Install Systemd Service (`setup_service.sh`)**:
     - **Purpose**: Installs a systemd service to run `services_startup.sh` on boot.
     - **Usage**:
       ```bash
       sudo ./setup_service.sh
       ```
     - **Requirements**: `services-startup.service` file must exist with the correct path to `services_startup.sh`.
     - **Output**: Enables automatic startup of services.

## Sequential Workflow

1. **User Setup**: `create_user.sh` creates `WB-Services` to isolate service operations.
2. **Python Installation**: `install_python.sh` provides a Python environment with SSL for secure operations.
3. **Tooling Setup**: `install_docker_aws.sh` installs Docker, AWS CLI, and the encryption repository.
4. **Service Deployment**: `deploy_services.sh` orchestrates the full deployment, using `es_auth.sh` for Elasticsearch configuration.
5. **Startup Automation**: `services_startup.sh` and `setup_service.sh` ensure services persist across reboots.

## Configuration

- **Paths**: Services deploy to `$HOME/env/{opendistro_es,qna,ar_sent,en_sent}`.
- **Disk Serial**: Hardcoded as `5916P1XFT` in `deploy_services.sh`.
- **ECR Images**: Uses `dkr.ecr.us-east-1.amazonaws.com/{qna,ar-sentiment,en-sentiment}:on-prem`.
- **Systemd**: Edit `services-startup.service` to point to the absolute path of `services_startup.sh`.

## Troubleshooting

- **Permission Denied**: Run scripts with `sudo` where required or as `WB-Services`.
- **AWS Errors**: Verify AWS CLI credentials (`aws configure`) and permissions.
- **Docker Issues**: Ensure Docker is running (`sudo systemctl start docker`).
- **Encryption Fails**: Check the `encryption-script` repository exists and Python 3.9 is installed.
- **Service Logs**: Inspect `$HOME/env/*/logs` or `docker logs <container>`.

## Notes

- **Security**: `.env` files are encrypted; manage keys securely.
- **Customization**: Adjust constants (e.g., Python version, ECR images) in the scripts as needed.
- **Execution Order**: Follow the sequence for a complete setup.


