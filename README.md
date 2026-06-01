# Proxmox Template Creator

Bash script to automate Proxmox VE template creation from cloud-init images.
This is what I use to spin up VMs in my homelab, standardizing the process
and avoiding repetitive manual `qm` commands.

## What it does
- Downloads a cloud-init compatible image (Debian/Ubuntu).
- Creates a Proxmox VM with predefined resources.
- Imports the disk, attaches cloud-init drive, and configures network.
- Converts the VM into a reusable template.

## Requirements
- Proxmox VE 7.x or 8.x
- `qm`, `wget`, `bash`
- Root or sudo access on the Proxmox host

## Configuration
Edit the variables at the top of `create_template.sh`:

| Variable     | Default       | Description              |
|--------------|---------------|--------------------------|
| `VMID`       | 9000          | Template VM ID           |
| `STORAGE`    | local-lvm     | Storage target           |
| `BRIDGE`     | vmbr0         | Network bridge           |
| `DISK_SIZE`  | 20G           | Disk size                |
| `IMAGE_URL`  | (Debian 12)   | Cloud image URL          |

## Usage
```bash
git clone https://github.com/polar-n0de/proxmox-template-creator.git
cd proxmox-template-creator
chmod +x create_template.sh
sudo ./create_template.sh
```

After completion, clone the template from the Proxmox UI or via:
```bash
qm clone 9000 101 --name my-new-vm --full
```

## License
MIT
