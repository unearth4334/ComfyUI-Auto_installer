# UmeAiRT's ComfyUI Auto-Installer

![Bash](https://img.shields.io/badge/Bash-4.0%2B-green.svg)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20Windows-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

This project provides a suite of scripts to fully automate the installation and configuration of ComfyUI on Linux and Windows. The approach uses a clean installation based on `git` and a Python virtual environment (`venv`), ensuring an isolated, easy-to-update, and maintainable setup.

## Features

- **Clean Installation:** Clones the latest version of ComfyUI from the official repository and installs it in a dedicated Python virtual environment (`venv`).
- **Dependency Management:** Automatically checks for and installs necessary tools via package managers:
    - Python 3.12 (installed via system package manager)
    - Git
    - Build tools (gcc, cmake, etc.)
    - Aria2 (for accelerated downloads)
    - Compression tools (p7zip, unzip)
- **CSV-Managed Custom Nodes:** Installs a comprehensive list of custom nodes defined in an external `custom_nodes.csv` file, making it simple to add new nodes.
- **Interactive Model Downloaders:** Dedicated scripts guide you with menus to download the model packs you want (FLUX, WAN, HIDREAM, LTXV), with recommendations based on your graphics card's VRAM.
- **Dedicated Update Script:** A specific `update-comfyui.sh` script allows you to update ComfyUI, all custom nodes, and workflows with a single command.
- **Automated Launchers:** The project generates shell scripts to run the installation, updates, and the final application, automatically handling root privileges when needed.
- **Supplementary modules:** The script also installs complex modules such as: Sageattention, Triton, build tools, etc.
- **Workflow included:** A large amount of workflows are pre-installed for each model.

## Prerequisites

- Linux distribution (Ubuntu, Debian, Fedora, CentOS, Arch, openSUSE supported) or Windows 10/11
- An active internet connection
- Root/sudo privileges for system package installation (Linux) or Administrator privileges (Windows)
- An NVIDIA GPU is strongly recommended to use the models

## Installation and Usage

The entire process is designed to be as simple as possible.

### Linux Installation

1.  **Download the Project:** Download this repository as a ZIP file from GitHub and extract it to a folder of your choice (e.g., `/home/user/UmeAiRT-Installer`).

2.  **Run the Installer:**
    - In the folder, find and run the file `install-comfyui.sh`.
    - You will need to run it with sudo privileges:
      ```bash
      sudo ./install-comfyui.sh
      ```
    - The script will first download the latest versions of all installation scripts from the repository to ensure you are using the most recent version.

3.  **Follow the Instructions:**
    - The main installation script will then launch. It will install Python (if necessary), Git, build tools, Aria2, and then ComfyUI.
    - Next, it will install all custom nodes and their Python dependencies into the virtual environment.
    - Finally, it will ask you a series of questions about which model packs you wish to download. Simply answer `y` (yes) or `n` (no) to each question.

### Windows Installation

1.  **Download the Project:** Download this repository as a ZIP file from GitHub and extract it to a folder of your choice.

2.  **Run the Installer:**
    - In the folder, find and run the file `UmeAiRT-Install-ComfyUI.bat` as Administrator.
    - The PowerShell script will handle the installation automatically.

3.  **Custom Nodes Only (Windows):**
    - If you already have ComfyUI installed and only want to add custom nodes, run `UmeAiRT-Install-Custom-Nodes.bat` as Administrator.

At the end of the process, your ComfyUI installation will be complete and ready to use.

## Post-Installation Usage

Three main shell scripts will be available in your folder to manage the application:

- **`start-comfyui.sh`**
    - This is the file you will use to **launch ComfyUI**. It activates the virtual environment and starts the server.
    - Run with: `./start-comfyui.sh`

- **`download-models.sh`**
    - Run this script if you want to **add more model packs** later without reinstalling everything. It will present you with the same selection menu as the initial installation.
    - Run with: `./download-models.sh`

- **`update-comfyui.sh`**
    - Execute this script to **update your entire installation**. It will update the code for ComfyUI, all custom nodes, and your workflows, and install any new Python dependencies if required.
    - Run with: `./update-comfyui.sh`

- **`install-custom-nodes.sh`**
    - Use this script to **install only custom nodes** when ComfyUI is already installed. This is useful if you want to add custom nodes to an existing ComfyUI installation without reinstalling everything.
    - The script validates that ComfyUI is properly installed before proceeding.
    - Run with: `./install-custom-nodes.sh`

## File Structure

- **`/` (your root folder)**
    - `install-comfyui.sh` (Main installer script)
    - `start-comfyui.sh` (Created after installation to launch ComfyUI)
    - `update-comfyui.sh` (Launcher for the update script)
    - `download-models.sh` (Menu to download more models later)
    - `install-custom-nodes.sh` (Install only custom nodes to existing ComfyUI)
    - **`scripts/`** (Contains all bash scripts)
        - `install-comfyui-main.sh`
        - `update-comfyui-main.sh`
        - `install-custom-nodes.sh`
        - `download-flux-models.sh` (and other model downloaders)
        - `custom_nodes.csv` (The list of all custom nodes to install)
        - `dependencies.json` (Linux-compatible dependencies)
    - **`ComfyUI/`** (Created after installation, contains the application)
    - **`logs/`** (Created, contains installation/update logs)

## Distribution Support

The installer automatically detects your Linux distribution and uses the appropriate package manager:

- **Ubuntu/Debian:** Uses `apt-get`
- **Fedora/CentOS/RHEL:** Uses `dnf` or `yum`
- **Arch/Manjaro:** Uses `pacman`
- **openSUSE:** Uses `zypper`

For other distributions, you may need to install dependencies manually.

## Contributing

Suggestions and contributions are welcome. If you find a bug or have an idea for an improvement to the scripts, feel free to open an "Issue" on this GitHub repository.

## License

This project is under the MIT License. See the `LICENSE` file for more details.

## Acknowledgements

- To **Comfyanonymous** for creating the incredible ComfyUI.
- To the authors of all the **custom nodes** that enrich the ecosystem.
