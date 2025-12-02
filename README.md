# Proxmox Template Creator Script

A simple script to create a custom Proxmox template for streamlined VM deployment. This script automates the process of creating and configuring a Proxmox template, saving time and reducing manual errors.

## Features

- Automatically create a custom Proxmox template.
- Pre-configured for easy VM creation.
- Supports Proxmox's PVE API (or CLI commands).
- Quick and efficient way to roll out templates for multiple VMs.

## Prerequisites

- Proxmox VE server.
- SSH access to Proxmox server.
- Proxmox CLI tools (like `qm`).
- Bash shell.

## Installation

1. Clone this repository:

    ```bash
    git clone https://github.com/yourusername/proxmox-template-creator.git
    ```

2. Make sure the script is executable:

    ```bash
    chmod +x create_template.sh
    ```

3. Optionally, add any configuration in the script (e.g., template name, resources).

## Usage

Run the script to create your custom Proxmox template:

```bash
./create_template.sh
