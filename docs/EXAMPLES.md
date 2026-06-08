# Usage Examples & Scenarios

## Quick Start Examples

### Example 1: Ubuntu 24.04 LTS with Standard Setup (With Ansible)

**Scenario**: You want a general-purpose Ubuntu template for development VMs with Ansible support.

```bash
sudo ./proxmox_template_creator.sh
```

**Answers**:
```
Select distribution [1-8]: 4          # Ubuntu 24.04 LTS
Select option [2]: 2                  # Download image
Select storage [1-X]: 1               # local-lvm
Enter VM/Template ID: 9000
Enter template name [ubuntu-24.04-template]: ubuntu-24-prod
CPU cores [2]: 4
RAM in MB [2048]: 4096
Disk size in GB (minimum 20) [50]: 100
Network bridge [vmbr0]: vmbr0
Select IP configuration [1]: 1        # DHCP
Override DNS servers? (y/n) [n]: n
Add additional network interfaces? (y/n) [n]: n
Select profile [2]: 2                 # Standard
Include Ansible-ready packages? (y/n) [y]: y    # YES - adds Python 3 + apt
Inject SSH public key? (y/n) [n]: y
Enter SSH public key or path: /root/.ssh/id_rsa.pub
Set timezone [UTC]: UTC
Enable serial console? (y/n) [y]: y
Proceed? (y/n/edit) [y]: y
```

**Result**: Ubuntu template 9000 with:
- 4 CPU cores, 4GB RAM, 100GB disk
- DHCP networking
- Standard monitoring/security tools
- **Python 3 + python3-apt** (Ansible-ready)
- Your SSH key pre-configured

**Clone new VM**:
```bash
qm clone 9000 101 --name web-server --full

# Immediately run Ansible
ansible-playbook -i inventory site.yml
```

---

### Example 2: Debian 12 Minimal Server (NO Ansible)

**Scenario**: Lightweight template for API servers, minimal bloat, no need for Ansible.

```bash
sudo ./create_template.sh
```

**Answers**:
```
Select distribution [1-8]: 1          # Debian 12
Select option [2]: 2
Select storage [1-X]: 1
Enter VM/Template ID: 9001
Enter template name: debian-12-minimal
CPU cores [2]: 2
RAM in MB [2048]: 2048
Disk size in GB [50]: 30
Network bridge [vmbr0]: vmbr0
IP configuration [1]: 1               # DHCP
Additional interfaces? [n]: n
Select profile [2]: 1                 # Minimal (qemu-guest-agent, cloud-init, openssh)
Include Ansible-ready packages? (y/n) [y]: n    # NO - skip Python 3, smaller footprint
Inject SSH public key? (y/n) [n]: y
Enter SSH public key or path: /root/.ssh/id_rsa.pub
Set timezone: UTC
Serial console? [y]: y
```

**Result**: Lightweight Debian template (30GB disk, 2GB RAM) without Ansible overhead.

---

### Example 3: Rocky Linux 9 with Static IP (With Ansible)

**Scenario**: Production-ready RHEL-compatible template with fixed IP and Ansible support.

```bash
sudo ./create_template.sh
```

**Answers**:
```
Select distribution [1-8]: 5          # Rocky Linux 9
Select option [2]: 2
Select storage [1-X]: 1
Enter VM/Template ID: 9002
Enter template name: rocky-9-prod
CPU cores [2]: 6
RAM in MB [2048]: 8192
Disk size in GB [50]: 150
Network bridge [vmbr0]: vmbr0
IP configuration [1]: 2               # Static IP
Enter static IP: 192.168.1.50
Enter CIDR: 24
Enter gateway: 192.168.1.1
Primary DNS [1.1.1.1]: 1.1.1.1
Secondary DNS [8.8.8.8]: 8.8.8.8
DNS search domain: lab.local
Additional NICs? (y/n) [n]: y
How many: 2
Bridge for NIC 1 [vmbr1]: vmbr1
Bridge for NIC 2 [vmbr2]: vmbr2
Select profile [2]: 2                 # Standard
Include Ansible-ready packages? (y/n) [y]: y    # YES - adds Python 3 + dnf
Inject SSH public key? (y/n) [n]: y
Enter SSH public key or path: /root/.ssh/id_rsa.pub
Set timezone: Europe/Amsterdam
Serial console? [y]: y
Proceed? [y]: y
```

**Result**: Production template with:
- Static IP: 192.168.1.50/24
- 3 network interfaces (primary + 2 additional)
- 6 cores, 8GB RAM
- DNS: 1.1.1.1 + 8.8.8.8
- **Python 3 + python3-dnf** (Ansible-ready)
- Search domain: lab.local

---

## Understanding the Ansible Prompt

### Ansible-Ready Option During Template Creation

**Prompt**:
```
Include Ansible-ready packages? (y/n) [y]:
```

**What it does:**

| Answer | Action | Template Size | Use Case |
|--------|--------|---------------|----------|
| **y** (default) | Installs Python 3 + package manager (python3-apt for Debian/Ubuntu, python3-dnf for RHEL) | +300MB | Ansible automation, complex deployments |
| **n** | Skips Ansible packages | Minimal | Stateless workloads, containers, lightweight VMs |
| Press Enter | Uses default (**y**) | | Recommended for most deployments |

### When to Answer YES (y)
- Planning to use Ansible playbooks
- Need automation for configuration management
- Want quick provisioning without manual steps
- Building VMs for infrastructure-as-code workflows

### When to Answer NO (n)
- Creating minimal/lightweight templates
- No automation framework in use
- Disk space is critical
- Simple SSH-based provisioning only

### Example: NO Ansible Answer
```
Include Ansible-ready packages? (y/n) [y]: n
[OK] Ansible packages will NOT be included
```

Result: Smaller template, no Python 3 (can be installed later if needed)

---

## Real-World Scenarios

### Scenario A: Web Application Stack (With Ansible)

Create a template suitable for multi-tier web apps with Ansible automation.

```bash
# Template: 9010 (Ubuntu 24.04)
# Answer YES to Ansible
# 4 cores, 8GB RAM, 100GB disk
# Standard profile + Ansible

# Clone for production
qm clone 9010 101 --name web-frontend --full
qm clone 9010 102 --name web-api --full
qm clone 9010 103 --name web-db --full

# All VMs are immediately Ansible-ready
ansible-playbook -i inventory.yml site.yml
```

**Template includes:**
- ✅ qemu-guest-agent (Proxmox integration)
- ✅ Docker-ready (curl, jq for scripting)
- ✅ Monitoring (btop, iftop, sysstat)
- ✅ Security (fail2ban, ufw)
- ✅ Backup tools (restic)
- ✅ **Python 3 + python3-apt** (Ansible engine)

---

### Scenario B: Database Server (NO Ansible)

Create a minimal, high-performance template for databases without Ansible overhead.

```bash
# Select: Rocky Linux 9
# Answer NO to Ansible (no need for automation)
# Profile: Custom packages

Custom packages:
- qemu-guest-agent
- cloud-init
- openssh-server
- postgresql-15
- pgbackrest
- monitoring-plugins
- tuned
- sysstat
- htop
```

**VM Configuration:**
- 8 cores, 32GB RAM (database workload)
- 500GB+ disk (data volume)
- Static IP on dedicated storage network
- Multiple NICs (data + replication)

**Result**: Lean template optimized for database performance.

---

### Scenario C: Kubernetes/Container Nodes (With Ansible)

Lightweight template for k3s with Ansible for cluster setup.

```bash
# Ubuntu 24.04
# Profile: Minimal
# Ansible: YES (for k3s provisioning)

qm clone 9100 201 --name k3s-master --full
qm clone 9100 202 --name k3s-worker-1 --full
qm clone 9100 203 --name k3s-worker-2 --full

# Ansible playbook configures k3s
ansible-playbook k3s-install.yml
```

**Ansible playbook example:**
```yaml
---
- name: Configure k3s cluster
  hosts: k3s_nodes
  tasks:
    - name: Install k3s
      shell: curl -sfL https://get.k3s.io | sh -
    - name: Install CNI plugin
      shell: kubectl apply -f https://example.com/cni.yaml
```

---

### Scenario D: Multi-Environment Templates

Create separate templates for different environments with appropriate Ansible settings.

```bash
# DEVELOPMENT
Template 9100: Debian 12
- Ansible: YES (for rapid iteration)
- 2 cores, 2GB RAM
- Profile: Standard

# STAGING
Template 9101: Ubuntu 24.04
- Ansible: YES (mirrors production)
- 4 cores, 8GB RAM
- Profile: Standard

# PRODUCTION
Template 9102: Rocky 9
- Ansible: YES (for infrastructure-as-code)
- 8 cores, 16GB RAM
- Profile: Minimal + hardening
- Ansible for compliance automation
```

**Consistent automation across all environments:**
```bash
# Deploy to all environments with same playbooks
ansible-playbook -i inventory/dev site.yml
ansible-playbook -i inventory/staging site.yml
ansible-playbook -i inventory/prod site.yml
```

---

## Log File Example

**template-creation-20250109-120000.log:**
```
[INFO] Starting template creation...
[STEP] Checking prerequisites...
[OK] libguestfs-tools is already installed
[STEP] Select Linux Distribution
[OK] Selected: Ubuntu 24.04 LTS (cloud-init user: ubuntu)
[INFO] Downloading image from: https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
[OK] Image downloaded successfully
[INFO] Image virtual size: 2GB
[STEP] Detecting Proxmox storage...
[OK] Using storage: local-lvm
[OK] VM ID: 9000
[OK] Template name: ubuntu-24
[STEP] VM Configuration
[OK] CPU cores: 4
[OK] RAM: 4096MB
[OK] Disk size: 100GB
[INFO] Injecting packages into cloud image (this may take several minutes)...
[OK] Packages installed
[OK] Timezone configured
[INFO] Creating VM 9000...
[OK] VM created
[INFO] Importing disk to local-lvm...
[OK] Disk imported
[INFO] Configuring VM hardware...
[OK] Hardware configured
[OK] DNS configured
[INFO] Converting VM to template...
[OK] Template created
[OK] Ansible packages will be included
[OK] Tags added: ubuntu, 24.04, 2025-01-09
[STEP] Post-creation tasks
[OK] Downloaded image removed

============================================
         TEMPLATE CREATED SUCCESSFULLY
============================================
Template ID:      9000
Template Name:    ubuntu-24
Distribution:     Ubuntu 24.04 LTS
Cloud-init User:  ubuntu
Storage:          local-lvm
Configuration:    4 cores, 4096MB RAM, 100GB disk
Network:          DHCP
Ansible:          ENABLED (Python 3 + python3-apt)
Log file:         template-creation-20250109-120000.log
============================================
```

---

## Cloning & Deployment

### Clone in Web UI
1. **Proxmox Web UI** → Datacenter → Virtual Machines
2. Right-click template → **Clone**
3. Set new VM ID (e.g., 101)
4. Set hostname
5. Click **Clone**
6. Start VM

### Clone via CLI
```bash
# Full clone (independent copy)
qm clone 9000 101 --name web-server --full

# Linked clone (faster, depends on template)
qm clone 9000 101 --name web-server
```

### First Boot Configuration

**Access VM**:
```bash
# Via console or SSH (if SSH key injected)
ssh ubuntu@<vm-ip>

# Verify cloud-init completed
cloud-init status

# Check logs
cloud-init logs
```

**With Ansible (if enabled)**:
```bash
# Directly run playbook
ansible-playbook -i hosts.yml site.yml

# Verify Ansible connectivity
ansible all -m ping
```

**Without Ansible (if disabled)**:
```bash
# Manual provisioning
ssh ubuntu@<vm-ip>
sudo apt update && sudo apt upgrade -y
sudo apt install <packages>
```

---

## Troubleshooting Examples

### VM won't boot
```bash
# Check template config
qm config 9000

# Check cloudinit config
qm cloudinit dump 9000

# Check serial console
qm vncproxy 9000
```

### SSH key not working
```bash
# Verify key in template
qm config 9000 | grep sshkey

# Re-inject if needed
qm set 9000 --sshkey /root/.ssh/id_rsa.pub
```

### Ansible not available (answered NO during template creation)
```bash
# SSH into VM and install manually
ssh ubuntu@<vm-ip>

# For Debian/Ubuntu
sudo apt install python3 python3-apt

# For RHEL/Fedora
sudo dnf install python3 python3-dnf

# Verify
ansible --version
```

### Network not configured
```bash
# Check IP config
qm config 9000 | grep ipconfig

# Test network manually
ping -c 1 192.168.1.1
ip addr show
```

### Disk space issue
```bash
# Check disk usage
df -h
du -sh /var/lib/vz

# Increase template disk
qm resize 9000 scsi0 150G
```

---

## Performance Benchmarks

### Template Creation Time
```
Debian 12 (Minimal, NO Ansible):      ~5-8 minutes
Ubuntu 24.04 (Standard, YES Ansible): ~8-12 minutes
Rocky 9 (Standard, YES Ansible):      ~10-15 minutes
```

### Cloning Speed
```
Full clone (100GB):      ~30-60 seconds
Linked clone (100GB):    <1 second
```

### First VM Boot
```
Standard template:       ~30-60 seconds (cloud-init)
After customization:     5-10 seconds (cached)
Ansible playbook exec:   ~1-5 minutes (depends on playbook)
```

---

## Best Practices

1. **Naming convention**: `{distro}-{version}-{purpose}`
   - Example: `debian-12-webserver`, `ubuntu-24-database`, `rocky-9-worker`

2. **Template ID ranges**: Organize by distro
   - 9000-9099: Debian
   - 9100-9199: Ubuntu
   - 9200-9299: Rocky/AlmaLinux
   - 9300-9399: Fedora

3. **Ansible decision**:
   - Answer **YES** if using Ansible for provisioning/management
   - Answer **NO** if purely manual or containerized workloads
   - Default (yes) is recommended for most use cases

4. **Keep templates clean**:
   - Don't install application-specific software
   - Let Ansible/cloud-init handle customization
   - Focus on base OS + essentials

5. **Version tracking**:
   - Use tags: `qm set 9000 --tags ubuntu,24.04,ansible,prod`
   - Document in template description

6. **Backup templates**:
   ```bash
   vzdump 9000 --storage local --compress gzip --dumpdir /backup
   ```

7. **Regular updates**:
   - Recreate templates monthly
   - Keep OS & packages current
   - Test before production use

---

## See Also
- [Proxmox Cloud-Init Documentation](https://pve.proxmox.com/wiki/Cloud-Init_Support)
- [Proxmox VE Administration Guide](https://pve.proxmox.com/pve-docs/)
- [cloud-init Official Docs](https://cloud-init.io/)
- [Ansible Documentation](https://docs.ansible.com/)
