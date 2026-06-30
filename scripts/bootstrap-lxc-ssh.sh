#!/bin/bash
#
# bootstrap-lxc-ssh.sh
#
# One-time bootstrap script to install and enable SSH server on LXC containers.
#
# USAGE:
#   Run this script ONCE on the Proxmox host to bootstrap SSH access.
#   After this script completes, Ansible can manage containers via SSH.
#
#   ssh root@proxmox-host
#   ./bootstrap-lxc-ssh.sh
#
# WHAT IT DOES:
#   - Installs openssh-server on each container (using `pct exec`)
#   - Enables and starts the SSH service
#   - Waits for SSH to be reachable on each container
#
# WHY THIS IS NEEDED:
#   This is a classic chicken-and-egg problem:
#   - Ansible needs SSH to configure containers
#   - But SSH isn't installed on fresh LXC containers by default
#   - We can't run Ansible plays without SSH
#
#   Solution: Use `pct exec <vmid> <command>` to execute commands directly
#   on the container from the Proxmox host, bypassing the need for SSH
#   to be present initially.
#
#   Once SSH is installed and running, Ansible takes over for all other
#   configuration (DNS, routing, packages, etc.).
#

set -e

# List of container VMIDs to bootstrap
VMIDS=(100 101 102 103)

# Container IPs for SSH reachability check
# Map of VMID to IP for verification
declare -A CONTAINER_IPS=(
    [100]="192.168.1.21"  # pihole
    [101]="192.168.1.22"  # tailscale
    [102]="192.168.1.23"  # uptime-kuma
    [103]="192.168.1.24"  # pbs
)

echo "=================================="
echo "LXC SSH Bootstrap Script"
echo "=================================="
echo ""

for VMID in "${VMIDS[@]}"; do
    echo "[VMID $VMID] Starting bootstrap..."

    # Check if container is running
    if ! pct status "$VMID" | grep -q "running"; then
        echo "[VMID $VMID] ERROR: Container is not running. Start it first with: pct start $VMID"
        exit 1
    fi

    # Update package cache
    echo "[VMID $VMID] Updating package cache..."
    pct exec "$VMID" -- apt-get update -qq 2>/dev/null || true

    # Install openssh-server
    echo "[VMID $VMID] Installing openssh-server..."
    pct exec "$VMID" -- apt-get install -y openssh-server openssh-client 2>/dev/null || {
        echo "[VMID $VMID] WARNING: apt-get install failed, trying with error tolerance..."
        pct exec "$VMID" -- apt-get install -y -o Dpkg::Pre-Install-Pkgs=/dev/null openssh-server openssh-client
    }

    # Enable SSH service to start on boot
    echo "[VMID $VMID] Enabling SSH service..."
    pct exec "$VMID" -- systemctl enable ssh

    # Start SSH service
    echo "[VMID $VMID] Starting SSH service..."
    pct exec "$VMID" -- systemctl start ssh

    # Verify SSH service is running
    if pct exec "$VMID" -- systemctl is-active --quiet ssh; then
        echo "[VMID $VMID] ✓ SSH service is running"
    else
        echo "[VMID $VMID] ERROR: SSH service failed to start"
        exit 1
    fi

    echo "[VMID $VMID] Bootstrap complete"
    echo ""
done

echo "=================================="
echo "SSH Reachability Check"
echo "=================================="
echo ""

# Wait for SSH to be reachable on each container
for VMID in "${VMIDS[@]}"; do
    CONTAINER_IP="${CONTAINER_IPS[$VMID]}"
    echo "[VMID $VMID] Waiting for SSH on $CONTAINER_IP:22..."

    for attempt in {1..30}; do
        if timeout 2 bash -c "echo >/dev/tcp/$CONTAINER_IP/22" 2>/dev/null; then
            echo "[VMID $VMID] ✓ SSH is reachable at $CONTAINER_IP"
            break
        fi

        if [ $attempt -eq 30 ]; then
            echo "[VMID $VMID] ERROR: SSH not reachable after 30 attempts (timeout: ~60 seconds)"
            exit 1
        fi

        sleep 2
    done
done

echo ""
echo "=================================="
echo "✓ SSH Bootstrap Complete!"
echo "=================================="
echo ""
echo "Next steps:"
echo "  1. Add SSH public key to root@container for password-less access:"
echo "     ssh-copy-id -i ~/.ssh/id_rsa.pub root@192.168.1.21  # repeat for all containers"
echo ""
echo "  2. Verify Ansible can reach containers:"
echo "     ansible edge_lxc -i inventory/hosts.yml -m ping"
echo ""
echo "  3. Run the Ansible baseline playbook:"
echo "     ansible-playbook -i inventory/hosts.yml playbooks/lxc-baseline.yml"
echo ""
