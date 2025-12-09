#!/bin/bash
set -e

echo "=== Cloud-init Template Creation Script ==="

# Function to check if a package is installed
pkg_installed() {
    dpkg -s "$1" &>/dev/null
}

# 1. Ensure libguestfs-tools is installed
echo "[STEP] Checking for libguestfs-tools..."
if ! pkg_installed libguestfs-tools; then
    echo "[INFO] Installing libguestfs-tools..."
    apt update
    apt install -y libguestfs-tools
else
    echo "[OK] libguestfs-tools is already installed."
fi

# 2. Ask for image path
read -rp "[INPUT] Enter path to your cloud image: " IMAGE_PATH
if [ ! -f "$IMAGE_PATH" ]; then
    echo "[ERROR] File not found: $IMAGE_PATH"
    exit 1
fi
echo "[OK] Found image: $IMAGE_PATH"

# 3. Ask for VM/template ID
read -rp "[INPUT] Enter VM/template ID number: " VM_ID
if ! [[ "$VM_ID" =~ ^[0-9]+$ ]]; then
    echo "[ERROR] VM/template ID must be a number."
    exit 1
fi
echo "[OK] VM/template ID set to $VM_ID"

# 4. Ask for disk size (min 10 GB, default 50 GB)
read -rp "[INPUT] Enter disk size for the template in GB (minimum 10) [default: 50]: " DISK_SIZE
DISK_SIZE=${DISK_SIZE:-50}
if (( DISK_SIZE < 10 )); then
    echo "[WARN] Disk size too small. Using minimum size of 10G."
    DISK_SIZE=10
fi
DISK_SIZE="${DISK_SIZE}G"
echo "[OK] Disk size set to $DISK_SIZE"

# 5. Ask about Ansible readiness
while true; do
    read -rp "[INPUT] Include Ansible-ready packages (openssh-server, python3, etc.)? (y/n) [default: y]: " ANSIBLE_READY
    ANSIBLE_READY=${ANSIBLE_READY:-y}
    case "$ANSIBLE_READY" in
        [Yy]*) break ;;
        [Nn]*) break ;;
        *) echo "[WARN] Please answer y or n." ;;
    esac
done
echo "[OK] Ansible-ready packages: $ANSIBLE_READY"

# 6. Build package list
BASE_PACKAGES="fail2ban,preload,rkhunter,lynis,cockpit,restic,rsync,nmap,net-tools,btop,iftop,rear,ncdu,pydf,nnn,network-manager,iptraf,tree,sssd,sysstat,auditd,ufw,tcpdump,jq,lsof,htop,curl,vim,iproute2,bash-completion,ca-certificates,nfs-common,open-iscsi,openssl,smartmontools,mdadm,cron,ssh"

if [[ "$ANSIBLE_READY" =~ ^[Yy]$ ]]; then
    BASE_PACKAGES="$BASE_PACKAGES,openssh-server,python3,python3-apt,sudo"
fi

echo "[STEP] Injecting packages into the image..."
virt-customize -a "$IMAGE_PATH" --install "$BASE_PACKAGES"
echo "[OK] Packages installed inside the image."

# 7. Create VM
echo "[STEP] Creating VM $VM_ID..."
qm create "$VM_ID" --name "debian-template-$VM_ID" --memory 1024 --net0 virtio,bridge=vmbr0
echo "[OK] VM $VM_ID created."

# 8. Import disk
echo "[STEP] Importing disk..."
qm importdisk "$VM_ID" "$IMAGE_PATH" local-lvm
echo "[OK] Disk imported."

# 9. Set hardware configuration
echo "[STEP] Configuring VM hardware..."
qm set "$VM_ID" --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-"$VM_ID"-disk-0
qm set "$VM_ID" --ide2 local-lvm:cloudinit
qm set "$VM_ID" --boot c --bootdisk scsi0
qm set "$VM_ID" --serial0 socket --vga serial0
qm set "$VM_ID" --ipconfig0 ip=dhcp
echo "[OK] Hardware configured."

# 10. Get actual size of the imported disk and resize if needed
CURRENT_SIZE_BYTES=$(qemu-img info "$IMAGE_PATH" | grep "virtual size" | sed -E 's/.*\(([0-9]+) bytes\).*/\1/')
REQ_SIZE_NUM=${DISK_SIZE%G}
REQ_SIZE_BYTES=$(( REQ_SIZE_NUM * 1024 * 1024 * 1024 ))

if (( REQ_SIZE_BYTES > CURRENT_SIZE_BYTES )); then
    echo "[STEP] Resizing disk to $DISK_SIZE..."
    qm resize "$VM_ID" scsi0 "$DISK_SIZE"
    echo "[OK] Disk resized."
else
    echo "[OK] Skipping resize (requested size <= current size)."
fi

# 11. Convert VM to template
echo "[STEP] Converting VM to template..."
qm template "$VM_ID"
echo "[OK] VM $VM_ID is now a template."

# 12. Ask whether to keep the original image
while true; do
    read -rp "[INPUT] Keep the original cloud image for future use? (y/n) [default: n]: " KEEP_IMAGE
    KEEP_IMAGE=${KEEP_IMAGE:-n}
    case "$KEEP_IMAGE" in
        [Yy]*) 
            echo "[OK] Keeping $IMAGE_PATH for future use."
            break ;;
        [Nn]*) 
            echo "[INFO] Removing $IMAGE_PATH..."
            rm -f "$IMAGE_PATH"
            break ;;
        *) echo "[WARN] Please answer y or n." ;;
    esac
done

echo "=== DONE: Template $VM_ID created with disk size $DISK_SIZE ==="
