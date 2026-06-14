# Proxmox Template Creator

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Proxmox](https://img.shields.io/badge/Proxmox-E57000?style=flat&logo=proxmox&logoColor=white)](https://www.proxmox.com)
[![Shell Script](https://img.shields.io/badge/bash-5.0+-4EAA25?logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)

Automated Proxmox VE template creator with cloud-init support. Simplify VM deployment by creating standardized, reusable templates with customizable configurations—no manual `qm` commands needed.

## Quick Overview
- ✅ Interactive multi-distribution support (Debian, Ubuntu, Rocky, AlmaLinux, Fedora)
- ✅ Automated cloud image download & customization
- ✅ Flexible networking (DHCP, static IP, multiple NICs, DNS override)
- ✅ Optional Ansible-ready templates with pre-installed packages
- ✅ SSH key injection for automated access
- ✅ Comprehensive logging & error recovery
- ✅ Zero manual Proxmox CLI commands

## Features

### Supported Distributions
- **Debian**: 12 (Bookworm), 13 (Trixie)
- **Ubuntu**: 22.04 LTS (Jammy), 24.04 LTS (Noble), 26.04(Resolute)
- **Rocky Linux**: 8,9
- **AlmaLinux**: 8, 9
- **Fedora**: 44
- **OpenSuse**: 15.6

### Cloud-Init Configuration
- **IP Assignment**: DHCP or static IP with CIDR notation
- **DNS**: Custom DNS servers & search domains
- **Networking**: Primary bridge + additional NICs
- **SSH Keys**: Inject public key for passwordless access
- **Users**: Distribution-specific cloud-init user (debian, ubuntu, rocky, etc.)

### VM Customization
- **Resources**: Configurable CPU cores, RAM, disk size
- **CPU Type**: host, kvm64, x86-64-v2-AES (for migration)
- **Storage**: Auto-detect available Proxmox storage
- **Timezone**: Set to any valid timezone
- **Serial Console**: Optional for troubleshooting

### Package Management
- **Minimal Profile**: qemu-guest-agent, cloud-init, openssh only
- **Standard Profile**: Monitoring, security, backup, and network tools (fail2ban, cockpit, restic, btop, etc.)
- **Custom Profile**: Specify your own package list

### Ansible-Ready (Optional)
**Prompt during creation**: `Include Ansible-ready packages? (y/n) [y]`

- **Default**: **yes** - adds Python 3 + package manager modules
- **Answer y**: Includes python3, python3-apt (Debian/Ubuntu) or python3-dnf (RHEL/Fedora)
- **Answer n**: Skips Ansible packages (creates lighter template)

Templates with Ansible enabled are immediately ready for playbooks without additional setup.

## Requirements

- **Proxmox VE** 7.x or 8.x
- **Proxmox node**: Root or passwordless sudo access
- **Tools**: bash, qm, wget, virt-customize (libguestfs-tools)
- **Network**: Internet access for cloud image download
- **Disk Space**: Minimum 20GB free in selected storage

## Installation

```bash
git clone https://github.com/polar-n0de/proxmox-template-creator.git
cd proxmox-template-creator
chmod +x create_template.sh
sudo ./create_template.sh
```

## Usage

### Basic Workflow
```bash
sudo ./create_template.sh
```

1. **Select Distribution** - Choose from 8 supported options
2. **Image Source** - Download official image or use local file
3. **Storage Selection** - Pick Proxmox storage destination
4. **VM Configuration** - Set ID, name, CPU, RAM, disk
5. **Network Setup** - Configure IP (DHCP or static), DNS, NICs
6. **Software Profile** - Choose packages (Minimal, Standard, Custom)
7. **Ansible Packages** - Include Ansible support? (defaults to yes)
8. **SSH Keys** - Optionally inject public key
9. **Review & Confirm** - Summary of all settings
10. **Template Creation** - Automated customization & deployment

### Example: Ubuntu 24.04 LTS Template
```
Select distribution [1-8]: 4          # Ubuntu 24.04 LTS
Select option [2]: 2                  # Download official image
Select storage [1-X]: 1               # Choose storage
Enter VM/Template ID: 9000
Enter template name [ubuntu-24.04-template]: ubuntu-24
CPU cores [2]: 4
RAM in MB [2048]: 4096
Disk size in GB (minimum 20) [50]: 100
Network bridge [vmbr0]: vmbr0
Select IP configuration [1]: 2        # Static IP
Enter static IP address: 192.168.1.100
Enter CIDR netmask: 24
Enter gateway IP: 192.168.1.1
Enter primary DNS server [1.1.1.1]: 1.1.1.1
Select profile [2]: 2                 # Standard (with monitoring tools)
Include Ansible-ready packages? (y/n) [y]: y
Inject SSH public key? (y/n) [n]: y
Enter SSH public key or path: ~/.ssh/id_rsa.pub
Set timezone [UTC]: Europe/Amsterdam
Enable serial console? (y/n) [y]: y
Proceed? (y/n/edit) [y]: y
```

Result: **ubuntu-24** template (ID: 9000) ready for cloning.

### Clone Template to New VM
```bash
# Via CLI
qm clone 9000 101 --name production-server --full

# Via Proxmox Web UI
# 1. Right-click template → Clone
# 2. Set new VM ID & hostname
# 3. Start VM
```

## Configuration Options

### VM Parameters
| Parameter | Default | Range | Notes |
|-----------|---------|-------|-------|
| VM ID | User input | 1-999999 | Must be unique |
| CPU Cores | 2 | 1-64 | Depends on host |
| RAM | 2048 MB | 256-999999 | In megabytes |
| Disk Size | 50 GB | 20+ | Minimum varies by distro |
| CPU Type | host | host, kvm64, x86-64-v2-AES | host = best perf, kvm64 = portable |

### Network Configuration
| Option | Type | Example | Notes |
|--------|------|---------|-------|
| IP (DHCP) | Auto | N/A | Uses DHCP server |
| IP (Static) | Manual | 192.168.1.100/24 | Requires gateway, DNS |
| Gateway | Manual | 192.168.1.1 | Required for static IP |
| Primary DNS | Manual | 1.1.1.1 | Cloudflare, Google, etc. |
| Secondary DNS | Manual | 8.8.8.8 | Optional override |
| Search Domain | Manual | example.com | Optional DNS suffix |
| Additional NICs | Optional | vmbr1, vmbr2 | Multiple networks |

### Package Profiles
#### Minimal
```
qemu-guest-agent cloud-init openssh-server
```
Best for: Lightweight templates, minimal dependencies

#### Standard (Recommended)
```
Monitoring: btop iftop iotop sysstat
Security: fail2ban auditd ufw rkhunter
Tools: restic curl vim jq tmux ncdu
Network: nmap iptraf-ng tcpdump net-tools
Admin: cockpit cockpit-machines
Storage: smartmontools mdadm nfs-common open-iscsi
```
Best for: Production workloads, flexibility

#### Custom
Define your own package list (comma-separated).

## Repository Structure
```
proxmox-template-creator/
├── create_template.sh       # Main script
├── docs/
│   └── EXAMPLES.md         # Use cases & examples
├── README.md               # This file
├── LICENSE                 # MIT License
└── .gitignore
```

## Output & Logging

Each run creates a timestamped log file:
```
template-creation-20250109-143022.log
```

Contains:
- All user inputs
- Command outputs
- Timestamps
- Error messages (if any)
- Final summary

## Troubleshooting

### "qm not found"
**Cause**: Script not run from Proxmox host  
**Solution**: Execute on Proxmox VE node directly, not remotely

### "libguestfs-tools not installed"
**Cause**: virt-customize unavailable  
**Solution**: Script auto-installs, but requires apt/dnf access

### Image download fails
**Cause**: Network issue or URL changed  
**Solution**: Use local image option, specify path to `.qcow2` file

### Cloud-init not executing
**Cause**: Cloud-init package not installed  
**Solution**: Verify with: `qm config <VM_ID> | grep -i cloudinit`

### SSH key not injected
**Cause**: Invalid key format or permissions  
**Solution**: Verify SSH key: `cat ~/.ssh/id_rsa.pub | wc -c` (should be 300+ chars)

### Static IP not applying
**Cause**: Network misconfiguration  
**Solution**: Check IP config: `qm config <VM_ID> | grep ipconfig`; verify gateway is reachable

### Ansible not available in template
**Cause**: Answered "n" to Ansible prompt  
**Solution**: Create new template with "y" to Ansible question, or manually install: `apt install python3 python3-apt` (Debian)

## Advanced Usage

### Export Template Configuration
```bash
qm config 9000 > template-config.txt
```

### Backup Template
```bash
vzdump 9000 --storage local --compress gzip
```

### Clone Template to Another Storage
```bash
qm clone 9000 9001 --name backup --storage other-storage --full
```

### Automate Template Updates
Use with cron/systemd timer to update templates periodically:
```bash
0 2 1 * * /root/proxmox-template-creator/create_template.sh
```

## Performance Tips

- **Faster creation**: Use local SSD storage (`local-lvm`)
- **Smaller templates**: Use Minimal package profile
- **Parallel builds**: Run multiple script instances with different VM IDs (slow on single-core)
- **Network**: Pre-download image to `/tmp` for repeated use
- **Ansible overhead**: Skip Ansible packages if not using playbooks

## Known Limitations

- Script must run **on** Proxmox node (not remotely)
- Cannot modify existing templates (create new ones instead)
- Some distributions may require Proxmox 8.x+ for full cloud-init support
- Serial console disables VNC display (enable one or the other)

## Contributing

Issues, feature requests, and pull requests welcome!

**Ideas:**
- Support for custom cloud-init scripts
- GUI configuration builder
- Template versioning system
- Backup/restore automation
- Multi-node deployment

## License
MIT License © 2024

---

**Questions?** Check [Proxmox Cloud-Init Docs](https://pve.proxmox.com/wiki/Cloud-Init_Support) or review examples in `docs/EXAMPLES.md` 
