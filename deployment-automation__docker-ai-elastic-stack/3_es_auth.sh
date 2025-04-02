#!/bin/bash

# Script to add a user to Elasticsearch's internal_users.yml.
# Author: [Mahmoud AbdelFattah]
# Date: Jan 02, 2023

# Exit on errors, undefined variables, or pipeline failures
set -euo pipefail

# Constants
readonly ES_USER="${1:-}"
readonly ES_PASS="${2:-}"
readonly USERS_FILE="/usr/share/elasticsearch/plugins/opendistro_security/securityconfig/internal_users.yml"
readonly HASH_TOOL="/usr/share/elasticsearch/plugins/opendistro_security/tools/hash.sh"
readonly SECURITY_DIR="/usr/share/elasticsearch/plugins/opendistro_security/tools"

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

# add_es_user: Adds a user to Elasticsearch's internal_users.yml and updates security config.
add_es_user() {
    local es_pass_hash
    es_pass_hash=$(/bin/sh "$HASH_TOOL" -p "$ES_PASS" 2>/dev/null) || log_error "Failed to hash password"
    local users_marker="#user ${ES_USER} added to ES admins"

    log_info "Adding user $ES_USER to $USERS_FILE..."
    if [[ ! -f "$USERS_FILE" ]]; then
        log_error "Users file $USERS_FILE not found"
    fi

    if grep -Fxq "$users_marker" "$USERS_FILE"; then
        log_info "User $ES_USER already configured in $USERS_FILE"
    else
        cat <<EOT >> "$USERS_FILE" || log_error "Failed to update $USERS_FILE"
$users_marker
${ES_USER}:
  hash: ${es_pass_hash}
  reserved: true
  backend_roles:
  - "admin"
  description: "Main admin user"
EOT
        cd "$SECURITY_DIR" || log_error "Failed to change to $SECURITY_DIR"
        ./securityadmin.sh -cd ../securityconfig/ -icl -nhnv \
            -cacert ../../../config/root-ca.pem \
            -cert ../../../config/kirk.pem \
            -key ../../../config/kirk-key.pem \
            --accept-red-cluster || log_error "Failed to update security config"
        log_info "User $ES_USER added successfully"
    fi
}

# main: Orchestrates the user addition process.
main() {
    if [[ -z "$ES_USER" || -z "$ES_PASS" ]]; then
        log_error "Username or password not specified. Usage: $0 <username> <password>"
    fi
    add_es_user
}

# Trap interrupts for clean exit
trap 'log_info "Script interrupted by user"; exit 0' INT

# Execute main
main