# Conda Installation and Environment Management

Here i'm going to describe the purpose, usage, and details of the `install_conda.sh`, which is designed to automate the installation of Anaconda (Conda) and provide an interactive interface for managing Conda environments on an Ubuntu-based system. The script ensures a specific version of Anaconda is installed and allows users to create or activate Python environments effortlessly.

## Overview

The `install_conda.sh` script serves two primary purposes:
1. **Installs Anaconda**: Downloads and sets up Anaconda 2021.11 if it’s not already present, ensuring a consistent Python ecosystem.
2. **Manages Conda Environments**: Offers an interactive menu to create new environments with specified Python versions or activate existing ones.

This script is ideal for developers or system administrators who need a reliable, automated way to set up and manage Python environments on Linux systems, particularly for projects requiring specific Python versions.

## Prerequisites

- **Operating System**: Ubuntu (e.g., 20.04 or 22.04).
- **Software**:
  - Bash shell.
  - `sudo` privileges.
  - Internet access for downloading Anaconda.
- **Hardware**: Linux x86_64 architecture.
- **Dependencies**: `wget` (installed by the script if missing).

## Installation

1. **Clone or Download the Repository**:
   ```bash
   git clone <repository-url>
   cd <repository-directory>
   ```
   Alternatively, download `install_conda.sh` directly.

2. **Set Execute Permissions**:
   ```bash
   chmod +x install_conda.sh
   ```

## Usage

Run the script to install Conda and manage environments:
```bash
./install_conda.sh
```

### Workflow
1. **Conda Installation Check**:
   - If Conda is not installed, the script downloads and installs Anaconda 2021.11.
   - If Conda is already present, it skips installation and ensures it’s sourced.

2. **Interactive Menu**:
   - **Create**: Prompts for an environment name and Python version (e.g., `3.9`), then creates the environment.
   - **Activate**: Prompts for an environment name and activates it in the current session.
   - **Quit**: Exits the script.

### Example Output
```bash
[INFO] Checking Conda installation...
[INFO] Conda not found. Installing...
[INFO] Updating repository index...
[INFO] Downloading Anaconda 2021.11...
[INFO] Installing Anaconda in batch mode...
[INFO] Conda installation completed successfully
[INFO] Conda environment management
Please choose an option (1-3):
1) create
2) activate
3) quit
1
Enter environment name: myenv
Enter Python version (e.g., 3.9): 3.9
[INFO] Creating environment 'myenv' with Python 3.9...
[INFO] Environment 'myenv' created. Activate it with: source ~/anaconda3/bin/activate myenv
```

## Script Details

- **File**: `install_conda.sh`
- **Author**: Mahmoud AbdelFattah
- **Date**: November 01, 2022
- **Version**: Installs Anaconda 2021.11 (customizable via `ANACONDA_VERSION`).

### Features
- **Robust Error Handling**: Uses `set -euo pipefail` to exit on errors, undefined variables, or pipeline failures.
- **Color-Coded Logging**: Green `[INFO]` for progress, red `[ERROR]` for failures.
- **Conda Installation**:
  - Downloads from `https://repo.anaconda.com/archive/`.
  - Installs to `$HOME/anaconda3` in batch mode (`-b`).
  - Initializes and updates Conda.
- **Environment Management**:
  - Interactive `select` menu for user-friendly operation.
  - Validates input to prevent empty environment names or versions.

### Constants
- `ANACONDA_VERSION="2021.11"`: Specifies the Anaconda version.
- `ANACONDA_FILE="Anaconda3-${ANACONDA_VERSION}-Linux-x86_64.sh"`: Filename for download.
- `ANACONDA_URL`: Download URL constructed from the version.

### Functions
- **`log_info`**: Prints green informational messages.
- **`log_error`**: Prints red error messages and exits.
- **`command_exists`**: Checks if a command (e.g., `wget`, `conda`) is available.
- **`install_conda`**: Handles Anaconda installation.
- **`manage_conda_env`**: Manages environment creation and activation.
- **`main`**: Orchestrates the workflow.

## Configuration

- **Installation Path**: Defaults to `$HOME/anaconda3` (modify `CONDA_BASE_DIR` in the script if needed).
- **Anaconda Version**: Change `ANACONDA_VERSION` to install a different version (e.g., `2022.05`).

## Troubleshooting

- **Download Fails**: Ensure internet access and verify the URL in `ANACONDA_URL`.
- **Permission Denied**: Run with `sudo` if necessary, though the script handles most `sudo` commands internally.
- **Conda Not Found After Install**: Manually source Conda:
  ```bash
  source ~/anaconda3/bin/activate
  ```
- **Environment Activation**: Activation is session-specific; re-run `source` in new terminals or add to `~/.bashrc`.

## Notes

- **Session Limitation**: Environment activation only persists in the current shell session. For permanent activation, modify your shell profile (e.g., `echo "source ~/anaconda3/bin/activate" >> ~/.bashrc`).
- **Customization**: Edit `ANACONDA_VERSION` or add more options to `manage_conda_env` (e.g., delete environments) as needed.
- **Interrupt Handling**: Press `Ctrl+C` to exit gracefully with a message.

