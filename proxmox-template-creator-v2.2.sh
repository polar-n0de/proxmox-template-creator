
##polar-n0de work##

#!/bin/bash
set -e

echo "=============================================="
echo "  Proxmox Cloud-Init Template Creator v2.2"
echo "=============================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging
LOG_FILE="template-creation-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${GREEN}[STEP]${NC} $1"; }

# Function to check if a package is installed
pkg_installed() {
    dpkg -s "$1" &>/dev/null
}

# Cleanup function for rollback
cleanup_on_error() {
    log_error "An error occurred. Rolling back..."
    if [ -n "$VM_ID" ] && qm status "$VM_ID" &>/dev/null; then
        log_info "Removing VM $VM_ID..."
        qm destroy "$VM_ID" --purge || true
    fi
    exit 1
}

trap cleanup_on_error ERR

#==============================================================================
# PHASE 1: PREREQUISITES
#==============================================================================
log_step "Checking prerequisites..."

if ! pkg_installed libguestfs-tools; then
    log_info "Installing libguestfs-tools..."
    apt update
    apt install -y libguestfs-tools
else
    log_ok "libguestfs-tools is already installed"
fi

#==============================================================================
# PHASE 2: DISTRIBUTION SELECTION
#==============================================================================
echo ""
log_step "Select Linux Distribution"
echo "----------------------------------------"
echo "0) Debian 12 (Bookworm)"
echo "1) Debian 13 (Trixie)"
echo "2) Ubuntu 22.04 LTS (Jammy)"
echo "3) Ubuntu 24.04 LTS (Noble)"
echo "4) Ubuntu 26.04 LTS (Resolute)"
echo "5) Rocky Linux 9"
echo "6) Rocky Linux 10"
echo "7) AlmaLinux 8"
echo "8) AlmaLinux 9"
echo "9) Fedora 44"
echo "10) OpenSUSE Leap 15.6"
echo "----------------------------------------"

while true; do
    read -rp "Select distribution [0-10]: " DISTRO_CHOICE
    case "$DISTRO_CHOICE" in
        0)  DISTRO="debian"; VERSION="12"; DISTRO_NAME="Debian 12"; PKG_MGR="apt"; CLOUD_USER="debian"
            IMAGE_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"; break ;;

        1)  DISTRO="debian"; VERSION="13"; DISTRO_NAME="Debian 13"; PKG_MGR="apt"; CLOUD_USER="debian"
            IMAGE_URL="https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"; break ;;

        2)  DISTRO="ubuntu"; VERSION="22.04"; DISTRO_NAME="Ubuntu 22.04 LTS"; PKG_MGR="apt"; CLOUD_USER="ubuntu"
            IMAGE_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64-disk-kvm.img"; break ;;

        3)  DISTRO="ubuntu"; VERSION="24.04"; DISTRO_NAME="Ubuntu 24.04 LTS"; PKG_MGR="apt"; CLOUD_USER="ubuntu"
            IMAGE_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"; break ;;

        4)  DISTRO="ubuntu"; VERSION="26.04"; DISTRO_NAME="Ubuntu 26.04 LTS"; PKG_MGR="apt"; CLOUD_USER="ubuntu"
            IMAGE_URL="https://cloud-images.ubuntu.com/resolute/current/resolute-server-cloudimg-amd64.img"; break ;;

        5)  DISTRO="rocky"; VERSION="9"; DISTRO_NAME="Rocky Linux 9"; PKG_MGR="dnf"; CLOUD_USER="rocky"
            IMAGE_URL="https://dl.rockylinux.org/pub/rocky/9.8/images/x86_64/Rocky-9-GenericCloud-Base-9.8-20260525.0.x86_64.qcow2"; break ;;

        6)  DISTRO="rocky"; VERSION="10"; DISTRO_NAME="Rocky Linux 10"; PKG_MGR="dnf"; CLOUD_USER="rocky"
            IMAGE_URL="https://dl.rockylinux.org/pub/rocky/10.2/images/x86_64/Rocky-10-GenericCloud-Base-10.2-20260525.0.x86_64.qcow2"; break ;;

        7)  DISTRO="alma"; VERSION="8"; DISTRO_NAME="AlmaLinux 8"; PKG_MGR="dnf"; CLOUD_USER="almalinux"
            IMAGE_URL="https://repo.almalinux.org/almalinux/8/cloud/x86_64/images/AlmaLinux-8-GenericCloud-latest.x86_64.qcow2"; break ;;

        8)  DISTRO="alma"; VERSION="9"; DISTRO_NAME="AlmaLinux 9"; PKG_MGR="dnf"; CLOUD_USER="almalinux"
            IMAGE_URL="https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"; break ;;

        9)  DISTRO="fedora"; VERSION="44"; DISTRO_NAME="Fedora 44"; PKG_MGR="dnf"; CLOUD_USER="fedora"
            IMAGE_URL="https://download.fedoraproject.org/pub/fedora/linux/releases/44/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-44-1.7.x86_64.qcow2"; break ;;

        10) DISTRO="opensuse"; VERSION="15.6"; DISTRO_NAME="OpenSUSE Leap 15.6"; PKG_MGR="zypper"; CLOUD_USER="root"
            IMAGE_URL="https://download.opensuse.org/repositories/Cloud:/Images:/Leap_15.6/images/openSUSE-Leap-15.6.x86_64-NoCloud.qcow2"; break ;;

        *) log_warn "Invalid selection. Please choose 0-10" ;;
    esac
done

log_ok "Selected: $DISTRO_NAME (cloud-init user: $CLOUD_USER)"

#==============================================================================
# PHASE 3: IMAGE HANDLING
#==============================================================================
echo ""
log_step "Cloud Image Source"
echo "----------------------------------------"
echo "1) Use local image file"
echo "2) Download official cloud image"
echo "----------------------------------------"

while true; do
    read -rp "Select option [2]: " IMAGE_SOURCE
    IMAGE_SOURCE=${IMAGE_SOURCE:-2}
    case "$IMAGE_SOURCE" in
        1) 
            read -rp "Enter path to cloud image: " IMAGE_PATH
            if [ ! -f "$IMAGE_PATH" ]; then
                log_error "File not found: $IMAGE_PATH"
                exit 1
            fi
            log_ok "Found image: $IMAGE_PATH"
            break ;;
        2) 
            IMAGE_FILENAME=$(basename "$IMAGE_URL")
            IMAGE_PATH="/tmp/${IMAGE_FILENAME}"
            log_info "Downloading image from: $IMAGE_URL"
            log_info "This may take a few minutes..."
            if wget -q --show-progress -O "$IMAGE_PATH" "$IMAGE_URL"; then
                log_ok "Image downloaded successfully"
            else
                log_error "Failed to download image"
                exit 1
            fi
            break ;;
        *) log_warn "Invalid selection." ;;
    esac
done

# Get image actual size
IMAGE_SIZE_BYTES=$(qemu-img info "$IMAGE_PATH" | grep "virtual size" | sed -E 's/.*\(([0-9]+) bytes\).*/\1/')
IMAGE_SIZE_GB=$((IMAGE_SIZE_BYTES / 1024 / 1024 / 1024))
log_info "Image virtual size: ${IMAGE_SIZE_GB}GB"

#==============================================================================
# PHASE 4: STORAGE DETECTION
#==============================================================================
echo ""
log_step "Detecting Proxmox storage..."

# Get available storage with type
mapfile -t STORAGE_LIST < <(pvesm status | awk 'NR>1 {print $1":"$2":"$3":"$4}')

if [ ${#STORAGE_LIST[@]} -eq 0 ]; then
    log_error "No storage found in Proxmox"
    exit 1
fi

echo "Available storage:"
for i in "${!STORAGE_LIST[@]}"; do
    IFS=':' read -r name type status avail <<< "${STORAGE_LIST[$i]}"
    echo "$((i+1))) $name (Type: $type, Available: $avail)"
done

if [ ${#STORAGE_LIST[@]} -eq 1 ]; then
    STORAGE_INDEX=0
    IFS=':' read -r STORAGE_NAME STORAGE_TYPE _ _ <<< "${STORAGE_LIST[0]}"
    log_ok "Using storage: $STORAGE_NAME"
else
    while true; do
        read -rp "Select storage [1-${#STORAGE_LIST[@]}]: " STORAGE_CHOICE
        if [[ "$STORAGE_CHOICE" =~ ^[0-9]+$ ]] && [ "$STORAGE_CHOICE" -ge 1 ] && [ "$STORAGE_CHOICE" -le ${#STORAGE_LIST[@]} ]; then
            STORAGE_INDEX=$((STORAGE_CHOICE - 1))
            IFS=':' read -r STORAGE_NAME STORAGE_TYPE _ _ <<< "${STORAGE_LIST[$STORAGE_INDEX]}"
            log_ok "Selected storage: $STORAGE_NAME"
            break
        else
            log_warn "Invalid selection"
        fi
    done
fi

#==============================================================================
# PHASE 5: VM CONFIGURATION
#==============================================================================
echo ""
log_step "VM Configuration"

# VM ID
while true; do
    read -rp "Enter VM/Template ID: " VM_ID
    if ! [[ "$VM_ID" =~ ^[0-9]+$ ]]; then
        log_warn "VM ID must be a number"
        continue
    fi
    if qm status "$VM_ID" &>/dev/null; then
        log_warn "VM ID $VM_ID already exists"
        continue
    fi
    break
done
log_ok "VM ID: $VM_ID"

# VM Name
DEFAULT_NAME="${DISTRO}-${VERSION}-template"
read -rp "Enter template name [${DEFAULT_NAME}]: " VM_NAME
VM_NAME=${VM_NAME:-$DEFAULT_NAME}
log_ok "Template name: $VM_NAME"

# CPU Cores
read -rp "CPU cores [2]: " CPU_CORES
CPU_CORES=${CPU_CORES:-2}
log_ok "CPU cores: $CPU_CORES"

# CPU Type
echo "CPU Types:"
echo "  host     = Best performance, no live migration between different CPUs"
echo "  kvm64    = Compatible, allows migration, lower performance"
echo "  x86-64-v2-AES = Modern baseline with AES support"
read -rp "CPU type [host]: " CPU_TYPE
CPU_TYPE=${CPU_TYPE:-host}
log_ok "CPU type: $CPU_TYPE"

# RAM
read -rp "RAM in MB [2048]: " RAM_MB
RAM_MB=${RAM_MB:-2048}
log_ok "RAM: ${RAM_MB}MB"

# Disk Size
MIN_DISK=$((IMAGE_SIZE_GB + 10))
read -rp "Disk size in GB (minimum ${MIN_DISK}) [50]: " DISK_SIZE
DISK_SIZE=${DISK_SIZE:-50}
if (( DISK_SIZE < MIN_DISK )); then
    log_warn "Disk size too small. Using minimum: ${MIN_DISK}GB"
    DISK_SIZE=$MIN_DISK
fi
log_ok "Disk size: ${DISK_SIZE}GB"

# Network Configuration
echo ""
log_info "Network Configuration"
read -rp "Network bridge [vmbr0]: " NET_BRIDGE
NET_BRIDGE=${NET_BRIDGE:-vmbr0}
log_ok "Network bridge: $NET_BRIDGE"

# IP Configuration
echo ""
echo "IP Configuration options:"
echo "  1) DHCP (automatic IP assignment)"
echo "  2) Static IP (manual configuration)"
read -rp "Select IP configuration [1]: " IP_CONFIG
IP_CONFIG=${IP_CONFIG:-1}

if [ "$IP_CONFIG" = "2" ]; then
    # Static IP configuration
    read -rp "Enter static IP address (e.g., 192.168.1.100): " STATIC_IP
    while [[ ! "$STATIC_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; do
        log_warn "Invalid IP address format"
        read -rp "Enter static IP address (e.g., 192.168.1.100): " STATIC_IP
    done
    
    read -rp "Enter CIDR netmask (e.g., 24 for /24): " CIDR
    while [[ ! "$CIDR" =~ ^[0-9]+$ ]] || [ "$CIDR" -lt 1 ] || [ "$CIDR" -gt 32 ]; do
        log_warn "Invalid CIDR (must be 1-32)"
        read -rp "Enter CIDR netmask (e.g., 24): " CIDR
    done
    
    read -rp "Enter gateway IP (e.g., 192.168.1.1): " GATEWAY
    while [[ ! "$GATEWAY" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; do
        log_warn "Invalid gateway format"
        read -rp "Enter gateway IP: " GATEWAY
    done
    
    # DNS Configuration
    read -rp "Enter primary DNS server (e.g., 8.8.8.8) [1.1.1.1]: " DNS1
    DNS1=${DNS1:-1.1.1.1}
    while [[ ! "$DNS1" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; do
        log_warn "Invalid DNS format"
        read -rp "Enter primary DNS server: " DNS1
    done
    
    read -rp "Enter secondary DNS server (optional, press Enter to skip) [8.8.8.8]: " DNS2
    DNS2=${DNS2:-8.8.8.8}
    if [ -n "$DNS2" ] && [[ ! "$DNS2" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_warn "Invalid DNS format, skipping secondary DNS"
        DNS2=""
    fi
    
    # Search domain (optional)
    read -rp "Enter DNS search domain (optional, press Enter to skip): " SEARCH_DOMAIN
    
    IP_CONFIG_STRING="ip=${STATIC_IP}/${CIDR},gw=${GATEWAY}"
    
    log_ok "Static IP: ${STATIC_IP}/${CIDR}"
    log_ok "Gateway: ${GATEWAY}"
    log_ok "DNS: ${DNS1}${DNS2:+, $DNS2}"
    [ -n "$SEARCH_DOMAIN" ] && log_ok "Search domain: ${SEARCH_DOMAIN}"
else
    # DHCP configuration
    IP_CONFIG_STRING="ip=dhcp"
    
    # Still allow custom DNS even with DHCP
    read -rp "Override DNS servers? (y/n) [n]: " OVERRIDE_DNS
    OVERRIDE_DNS=${OVERRIDE_DNS:-n}
    
    if [[ "$OVERRIDE_DNS" =~ ^[Yy]$ ]]; then
        read -rp "Enter primary DNS server [1.1.1.1]: " DNS1
        DNS1=${DNS1:-1.1.1.1}
        
        read -rp "Enter secondary DNS server (optional) [8.8.8.8]: " DNS2
        DNS2=${DNS2:-8.8.8.8}
        
        read -rp "Enter DNS search domain (optional): " SEARCH_DOMAIN
        
        log_ok "DNS override: ${DNS1}${DNS2:+, $DNS2}"
        [ -n "$SEARCH_DOMAIN" ] && log_ok "Search domain: ${SEARCH_DOMAIN}"
    else
        log_ok "Using DHCP for IP and DNS"
        DNS1=""
        DNS2=""
        SEARCH_DOMAIN=""
    fi
fi

# Additional NICs
echo ""
read -rp "Add additional network interfaces? (y/n) [n]: " ADD_NICS
ADD_NICS=${ADD_NICS:-n}
ADDITIONAL_NICS=()
if [[ "$ADD_NICS" =~ ^[Yy]$ ]]; then
    read -rp "How many additional NICs? " NIC_COUNT
    for ((i=1; i<=NIC_COUNT; i++)); do
        read -rp "Bridge for NIC $i [vmbr${i}]: " NIC_BRIDGE
        NIC_BRIDGE=${NIC_BRIDGE:-vmbr${i}}
        ADDITIONAL_NICS+=("$NIC_BRIDGE")
        log_ok "Additional NIC $i: $NIC_BRIDGE"
    done
fi

#==============================================================================
# PHASE 6: SOFTWARE CONFIGURATION
#==============================================================================
echo ""
log_step "Software Configuration"

# Package Profile
echo "Package profiles:"
echo "  1) Minimal (qemu-guest-agent, cloud-init, openssh only)"
echo "  2) Standard (comprehensive tools for monitoring, security, backup)"
echo "  3) Custom (specify your own packages)"
read -rp "Select profile [2]: " PKG_PROFILE
PKG_PROFILE=${PKG_PROFILE:-2}

# Build package list based on distro and profile
case "$PKG_PROFILE" in
    1) # Minimal
        if [ "$PKG_MGR" = "apt" ]; then
            PACKAGES="qemu-guest-agent,cloud-init,openssh-server"
        elif [ "$PKG_MGR" = "zypper" ]; then
            PACKAGES="qemu-guest-agent,cloud-init,openssh"
        else
            PACKAGES="qemu-guest-agent,cloud-init,openssh-server"
        fi
        ;;
    2) # Standard
        if [ "$PKG_MGR" = "apt" ]; then
            PACKAGES="qemu-guest-agent,fail2ban,preload,rkhunter,lynis,cockpit,restic,rsync,nmap,net-tools,btop,iftop,ncdu,network-manager,iptraf-ng,tree,sysstat,auditd,ufw,tcpdump,jq,lsof,htop,curl,vim,iproute2,bash-completion,ca-certificates,nfs-common,open-iscsi,openssl,smartmontools,mdadm,cron,openssh-server"
        elif [ "$PKG_MGR" = "zypper" ]; then
            PACKAGES="qemu-guest-agent,fail2ban,rkhunter,lynis,cockpit,restic,rsync,nmap,net-tools,btop,iftop,ncdu,NetworkManager,iptraf-ng,tree,sysstat,audit,firewalld,tcpdump,jq,lsof,htop,curl,vim,iproute,bash-completion,ca-certificates,nfs,open-iscsi,openssl,smartmontools,mdadm,cronie,openssh"
        else
            # RHEL-based systems
            PACKAGES="qemu-guest-agent,fail2ban,rkhunter,lynis,cockpit,restic,rsync,nmap,net-tools,btop,iftop,ncdu,NetworkManager,iptraf-ng,tree,sysstat,audit,firewalld,tcpdump,jq,lsof,htop,curl,vim,iproute,bash-completion,ca-certificates,nfs-utils,iscsi-initiator-utils,openssl,smartmontools,mdadm,cronie,openssh-server"
        fi
        ;;
    3) # Custom
        read -rp "Enter comma-separated package list: " PACKAGES
        ;;
esac

# Ansible Ready
read -rp "Include Ansible-ready packages? (y/n) [y]: " ANSIBLE_READY
ANSIBLE_READY=${ANSIBLE_READY:-y}
if [[ "$ANSIBLE_READY" =~ ^[Yy]$ ]]; then
    if [ "$PKG_MGR" = "apt" ]; then
        PACKAGES="$PACKAGES,python3,python3-apt,sudo"
    elif [ "$PKG_MGR" = "zypper" ]; then
        PACKAGES="$PACKAGES,python3,python3-zypper,sudo"
    else
        PACKAGES="$PACKAGES,python3,python3-dnf,sudo"
    fi
    log_ok "Ansible packages will be included"
fi

# SSH Key injection
read -rp "Inject SSH public key into template? (y/n) [n]: " INJECT_SSH
INJECT_SSH=${INJECT_SSH:-n}
SSH_KEY=""
if [[ "$INJECT_SSH" =~ ^[Yy]$ ]]; then
    read -rp "Enter SSH public key or path to key file: " SSH_KEY_INPUT
    if [ -f "$SSH_KEY_INPUT" ]; then
        SSH_KEY=$(cat "$SSH_KEY_INPUT")
    else
        SSH_KEY="$SSH_KEY_INPUT"
    fi
    log_ok "SSH key will be injected"
fi

# Timezone
read -rp "Set timezone [UTC]: " TIMEZONE
TIMEZONE=${TIMEZONE:-UTC}
log_ok "Timezone: $TIMEZONE"

# Serial console
read -rp "Enable serial console? (y/n) [y]: " SERIAL_CONSOLE
SERIAL_CONSOLE=${SERIAL_CONSOLE:-y}

#==============================================================================
# PHASE 7: SUMMARY & CONFIRMATION
#==============================================================================
echo ""
echo "=============================================="
echo "           CONFIGURATION SUMMARY"
echo "=============================================="
echo "Distribution:     $DISTRO_NAME"
echo "Cloud-init user:  $CLOUD_USER"
echo "Image:            $IMAGE_PATH"
echo "Storage:          $STORAGE_NAME"
echo "VM ID:            $VM_ID"
echo "VM Name:          $VM_NAME"
echo "CPU:              $CPU_CORES cores ($CPU_TYPE)"
echo "RAM:              ${RAM_MB}MB"
echo "Disk:             ${DISK_SIZE}GB"
echo "Network:          $NET_BRIDGE"
if [ "$IP_CONFIG" = "2" ]; then
    echo "IP Config:        Static - ${STATIC_IP}/${CIDR}"
    echo "Gateway:          $GATEWAY"
    echo "DNS:              ${DNS1}${DNS2:+, $DNS2}"
    [ -n "$SEARCH_DOMAIN" ] && echo "Search Domain:    $SEARCH_DOMAIN"
else
    echo "IP Config:        DHCP"
    if [ -n "$DNS1" ]; then
        echo "DNS Override:     ${DNS1}${DNS2:+, $DNS2}"
        [ -n "$SEARCH_DOMAIN" ] && echo "Search Domain:    $SEARCH_DOMAIN"
    fi
fi
if [ ${#ADDITIONAL_NICS[@]} -gt 0 ]; then
    echo "Additional NICs:  ${ADDITIONAL_NICS[*]}"
fi
echo "Package Profile:  $PKG_PROFILE"
echo "Ansible Ready:    $ANSIBLE_READY"
echo "SSH Key Inject:   $INJECT_SSH"
echo "Timezone:         $TIMEZONE"
echo "Serial Console:   $SERIAL_CONSOLE"
echo "=============================================="
echo ""

while true; do
    read -rp "Proceed with template creation? (y/n) [y]: " CONFIRM
    CONFIRM=${CONFIRM:-y}
    case "$CONFIRM" in
        [Yy]*) break ;;
        [Nn]*) log_info "Aborted by user"; exit 0 ;;
        *) log_warn "Please answer y or n" ;;
    esac
done

#==============================================================================
# PHASE 7.5: PREFLIGHT CHECKS
#==============================================================================
echo ""
log_step "Running preflight checks..."

# Check VM ID (fail early)
while qm status "$VM_ID" &>/dev/null; do
    log_warn "VM ID $VM_ID already exists"
    read -rp "Enter different VM ID: " VM_ID
    if ! [[ "$VM_ID" =~ ^[0-9]+$ ]]; then
        log_warn "VM ID must be a number"
        continue
    fi
done
log_ok "VM ID: $VM_ID (available)"

# Check CPU availability
TOTAL_CPUS=$(nproc)
if (( CPU_CORES > TOTAL_CPUS )); then
    log_error "Requested CPU cores ($CPU_CORES) exceeds total available ($TOTAL_CPUS)"
    exit 1
fi
log_ok "CPU: $TOTAL_CPUS cores available, requesting $CPU_CORES"

# Check RAM availability
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_RAM_MB=$((TOTAL_RAM_KB / 1024))
FREE_RAM_KB=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
FREE_RAM_MB=$((FREE_RAM_KB / 1024))
REQUIRED_RAM=$((RAM_MB + 512))

if (( REQUIRED_RAM > FREE_RAM_MB )); then
    log_error "Insufficient RAM: need ${REQUIRED_RAM}MB, only ${FREE_RAM_MB}MB free"
    exit 1
fi
log_ok "RAM: ${TOTAL_RAM_MB}MB total, ${FREE_RAM_MB}MB free, requesting ${RAM_MB}MB"

# Check disk space
REQUIRED_DISK=$((IMAGE_SIZE_GB + DISK_SIZE + 5))
STORAGE_AVAIL=$(pvesm status | grep "$STORAGE_NAME" | awk '{print $4}')

if (( REQUIRED_DISK > STORAGE_AVAIL )); then
    log_error "Insufficient disk space: need ${REQUIRED_DISK}GB, only ${STORAGE_AVAIL}GB available in $STORAGE_NAME"
    exit 1
fi
log_ok "Disk: ${STORAGE_AVAIL}GB available in $STORAGE_NAME, requesting ${REQUIRED_DISK}GB"

echo ""
log_ok "All preflight checks passed. Ready to proceed."
echo ""

#==============================================================================
# PHASE 8: EXECUTION
#==============================================================================
echo ""
log_step "Starting template creation..."

# Customize image
log_info "Injecting packages into cloud image (this may take several minutes)..."
virt-customize -a "$IMAGE_PATH" --install "$PACKAGES"
log_ok "Packages installed"

# Set timezone
log_info "Setting timezone to $TIMEZONE..."
virt-customize -a "$IMAGE_PATH" --timezone "$TIMEZONE"
log_ok "Timezone configured"

# Create VM
log_info "Creating VM $VM_ID..."
qm create "$VM_ID" \
    --name "$VM_NAME" \
    --memory "$RAM_MB" \
    --cores "$CPU_CORES" \
    --cpu "$CPU_TYPE" \
    --net0 "virtio,bridge=$NET_BRIDGE"

# Add additional NICs
if [ ${#ADDITIONAL_NICS[@]} -gt 0 ]; then
    for i in "${!ADDITIONAL_NICS[@]}"; do
        nic_num=$((i + 1))
        log_info "Adding network interface net${nic_num} on ${ADDITIONAL_NICS[$i]}..."
        qm set "$VM_ID" --net${nic_num} "virtio,bridge=${ADDITIONAL_NICS[$i]}"
    done
fi

log_ok "VM created"

# Import disk
log_info "Importing disk to $STORAGE_NAME..."
qm importdisk "$VM_ID" "$IMAGE_PATH" "$STORAGE_NAME"
log_ok "Disk imported"

# Configure hardware
log_info "Configuring VM hardware..."
qm set "$VM_ID" --scsihw virtio-scsi-pci --scsi0 "${STORAGE_NAME}:vm-${VM_ID}-disk-0"
qm set "$VM_ID" --ide2 "${STORAGE_NAME}:cloudinit"
qm set "$VM_ID" --boot c --bootdisk scsi0

if [[ "$SERIAL_CONSOLE" =~ ^[Yy]$ ]]; then
    qm set "$VM_ID" --serial0 socket --vga serial0
fi

# Configure IP
qm set "$VM_ID" --ipconfig0 "$IP_CONFIG_STRING"

# Configure DNS if specified
if [ -n "$DNS1" ]; then
    if [ -n "$DNS2" ]; then
        qm set "$VM_ID" --nameserver "${DNS1} ${DNS2}"
    else
        qm set "$VM_ID" --nameserver "$DNS1"
    fi
    log_ok "DNS configured"
fi

# Configure search domain if specified
if [ -n "$SEARCH_DOMAIN" ]; then
    qm set "$VM_ID" --searchdomain "$SEARCH_DOMAIN"
    log_ok "Search domain configured"
fi

log_ok "Hardware configured"

# Configure cloud-init
if [ -n "$SSH_KEY" ]; then
    log_info "Injecting SSH key..."
    qm set "$VM_ID" --sshkey <(echo "$SSH_KEY")
    log_ok "SSH key configured"
fi

# Set cloud-init user
qm set "$VM_ID" --ciuser "$CLOUD_USER"

# Resize disk
log_info "Resizing disk to ${DISK_SIZE}GB..."
qm resize "$VM_ID" scsi0 "${DISK_SIZE}G"
log_ok "Disk resized"

# Convert to template
log_info "Converting VM to template..."
qm template "$VM_ID"
log_ok "Template created"

#==============================================================================
# PHASE 9: POST-CREATION
#==============================================================================
echo ""
log_step "Post-creation tasks"

# Add tags
read -rp "Add tags to template (distro, version, date)? (y/n) [y]: " ADD_TAGS
ADD_TAGS=${ADD_TAGS:-y}
if [[ "$ADD_TAGS" =~ ^[Yy]$ ]]; then
    CREATION_DATE=$(date +%Y-%m-%d)
    qm set "$VM_ID" --tags "${DISTRO},${VERSION},${CREATION_DATE}"
    log_ok "Tags added: ${DISTRO}, ${VERSION}, ${CREATION_DATE}"
fi

# Keep image
if [ "$IMAGE_SOURCE" = "1" ]; then
    # User provided image - ask if they want to keep it
    read -rp "Keep original cloud image? (y/n) [n]: " KEEP_IMAGE
    KEEP_IMAGE=${KEEP_IMAGE:-n}
    if [[ "$KEEP_IMAGE" =~ ^[Yy]$ ]]; then
        log_ok "Keeping image: $IMAGE_PATH"
    else
        log_info "Removing image: $IMAGE_PATH"
        rm -f "$IMAGE_PATH"
        log_ok "Image removed"
    fi
else
    # Downloaded image - always clean up
    log_info "Removing downloaded image: $IMAGE_PATH"
    rm -f "$IMAGE_PATH"
    log_ok "Downloaded image removed"
fi

# Final summary
echo ""
echo "=============================================="
echo "         TEMPLATE CREATED SUCCESSFULLY"
echo "=============================================="
echo "Template ID:      $VM_ID"
echo "Template Name:    $VM_NAME"
echo "Distribution:     $DISTRO_NAME"
echo "Cloud-init User:  $CLOUD_USER"
echo "Storage:          $STORAGE_NAME"
echo "Configuration:    ${CPU_CORES} cores, ${RAM_MB}MB RAM, ${DISK_SIZE}GB disk"
if [ "$IP_CONFIG" = "2" ]; then
    echo "Network:          Static IP ${STATIC_IP}/${CIDR}, GW: ${GATEWAY}"
else
    echo "Network:          DHCP"
fi
echo "Log file:         $LOG_FILE"
echo "=============================================="
echo ""
log_ok "You can now clone this template to create new VMs.Ideally, create a full clone, not a linked one"
echo ""