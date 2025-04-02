#!/bin/bash

# Script to manage Conda installation and environments
# Author: [Mahmoud AbdelFattah]
# Date: Oct 01, 2022
#=============================================================================



# Exit on any error
# -e: Exits on command failures (same as above).
# -u: Exits on undefined variables (e.g., echo "$undefined_var" fails).
# -o pipefail: Exits if any command in a pipeline "|" fails, not just the last one
set -euo pipefail  


# Constants: can't be unset or overwritten, equal to [declare -r]
readonly ANACONDA_VERSION="2021.11"
readonly ANACONDA_FILE="Anaconda3-${ANACONDA_VERSION}-Linux-x86_64.sh"
readonly ANACONDA_URL="https://repo.anaconda.com/archive/${ANACONDA_FILE}"
# Colors for output: set ASCI code colors to MARK over a text like [ERROR] or [INFO] with a suitable color
readonly RED='\033[0;31m' # red ASCI
readonly GREEN='\033[0;32m' # green ASCI
readonly NC='\033[0m' # No Color ASCI



# log_info: Outputs an informational message in green to stdout.
# Parameters:
#   $1 - The message to display.
# Returns: None
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"    # [INFO] would be in green, then $1 would be outputed next in normal color
}

# log_error: Outputs an error message in red to stderr and exits with failure.
# Parameters:
#   $1 - The error message to display.
# Returns: Exits with status code 1
log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

# command_exists: Checks if a given command is available in the system.
# Parameters:
#   $1 - The command name to check (e.g., "wget", "conda").
# Returns:
#   0 (true) if the command exists, 1 (false) otherwise.
command_exists() {
    command -v "$1" >/dev/null 2>&1     #  cares about exit code not the command path or output, so, 2>&1: Suppresses any error messages (e.g., if command -v fails), keeping the script silent.
}



# install_conda: Installs Anaconda if not already present on the system.
# Parameters: None
# Returns: None (exits on failure via log_error)
# Dependencies: Requires sudo privileges, internet access, and a Linux x86_64 system.
# --------------------------------------------------------------------------
install_conda() {
    log_info "Updating repository index..."
    sudo apt update || log_error "Failed to update package index"   # || (Logical OR) → Executes the command on the right side only if the left-side command fails.

    # Ensure wget is installed
    if ! command_exists wget; then
        log_info "Installing wget..."
        sudo apt install -y wget || log_error "Failed to install wget"
    fi

    log_info "Starting Conda installation..."
    cd "$HOME" || log_error "Failed to change to home directory"

    # Clean up existing Anaconda files
    rm -f "${ANACONDA_FILE}"*
    rm -rf "${CONDA_BASE_DIR}"

    log_info "Downloading Anaconda ${ANACONDA_VERSION}..."
    wget -q "$ANACONDA_URL" || {
        log_error "Failed to download Anaconda"
    }

    log_info "Installing Anaconda in batch mode..."
    bash "$ANACONDA_FILE" -b -p "$CONDA_BASE_DIR" || {
        log_error "Anaconda installation failed"
    }

    log_info "Initializing Conda..."
    "${CONDA_BASE_DIR}/bin/conda" init || log_error "Failed to initialize Conda"

    log_info "Updating Conda packages..."
    "${CONDA_BASE_DIR}/bin/conda" update -y --all || log_error "Failed to update Conda"

    rm -f "$ANACONDA_FILE"
    log_info "Conda installation completed successfully"
}



# manage_conda_env: Provides an interactive menu to create or activate Conda environments.
# Parameters: None
# Returns: None (exits loop on "quit" or successful operation)
# Dependencies: Requires Conda to be installed and sourced.
# ------------------------------------------------------------
manage_conda_env() {
    log_info "Conda environment management"

    PS3="Please choose an option (1-3): "
    local options=("create" "activate" "quit")
    select opt in "${options[@]}"; do
        case "$opt" in
            "create")
                read -p "Enter environment name: " env_name
                read -p "Enter Python version (e.g., 3.9): " py_version

                if [[ -z "$env_name" || -z "$py_version" ]]; then
                    log_error "Environment name and Python version cannot be empty"
                fi

                log_info "Creating environment '$env_name' with Python $py_version..."
                "${CONDA_BASE_DIR}/bin/conda" create --name "$env_name" python="$py_version" -y || {
                    log_error "Failed to create environment '$env_name'"
                }
                log_info "Environment '$env_name' created. Activate it with: source $CONDA_BASE_DIR/bin/activate $env_name"
                break
                ;;

            "activate")
                read -p "Enter environment name to activate: " env_name

                if [[ -z "$env_name" ]]; then # -z: return true for empty var
                    log_error "Environment name cannot be empty"
                fi

                log_info "Activating environment '$env_name'..."
                if source "${CONDA_BASE_DIR}/bin/activate" "$env_name"; then
                    log_info "Environment '$env_name' activated in this session"
                    break
                else
                    log_error "Failed to activate environment '$env_name'"
                fi
                ;;

            "quit")
                log_info "Exiting Conda management"
                break
                ;;

            *)
                log_error "Invalid option: $REPLY"
                ;;
        esac
    done
}

# main: Orchestrates the script's workflow serving as an entrypoint by checking Conda and managing environments.
# Parameters: None
# Returns: None (exits on failure or user interrupt)
# Dependencies: Calls install_conda and manage_conda_env functions as needed.
# --------------------------------------------------------------
main() {
    log_info "Checking Conda installation..."

    if ! command_exists conda; then
        log_info "Conda not found. Installing..."
        install_conda

        # Source Conda for this session: adding conda to PATH
        if [[ -f "${CONDA_BASE_DIR}/bin/activate" ]]; then
            source "${CONDA_BASE_DIR}/bin/activate"
        else
            log_error "Conda installed but activation script not found"
        fi
    else
        log_info "Conda already installed"
        # Sources the conda.sh script, which sets up Conda’s environment (e.g., adds conda to PATH, defines conda activate).
        local conda_base
        conda_base=$(conda info --base 2>/dev/null) || true
        if [[ -n "$conda_base" && -f "$conda_base/etc/profile.d/conda.sh" ]]; then
            source "$conda_base/etc/profile.d/conda.sh"
        fi
    fi

    manage_conda_env
}


# This trap gives your script a polite "goodbye" when interrupted
# A Bash built-in command that specifies an action to take when a signal is received by the script.
# when it recieves a SIGNAL of type "INT" which is equal to [Ctrl+C], it executes command included in quotes '' right after trap
# -----------------------------------------------------------------
trap 'log_info "Script interrupted by user"; exit 0' INT


# Run main
# ----------
main