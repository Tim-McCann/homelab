#!/bin/bash
G4_IP="192.168.1.10"
K3S_CP="192.168.1.30"
K3S_W1="192.168.1.31"
K3S_W2="192.168.1.32"
DISCORD_WEBHOOK="https://discord.com/api/webhooks/1522967702547988553/cV90stFYA86JQvQsgVydb6zj8kR4Xa_fHFbIyxauMNZskyTwhw7bUjrM8vhgMkRQLPhC"
FAIL_COUNT_FILE="/tmp/g4-monitor-fails"
RECOVERY_FLAG="/tmp/g4-recovering"
VM_RESTART_FLAG="/tmp/g4-vm-restarted"
LOGFILE="/var/log/g4-monitor.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> $LOGFILE
}

discord() {
    curl -s -X POST "$DISCORD_WEBHOOK" \
      -H "Content-Type: application/json" \
      -d "{\"content\": \"$1\"}" > /dev/null 2>&1
}

# G4 host is reachable
if ping -c 2 -W 3 $G4_IP > /dev/null 2>&1; then

    # Check if k3s control plane is reachable
    if ! ping -c 2 -W 3 $K3S_CP > /dev/null 2>&1; then

        # Only restart VMs if we haven't done so in the last 30 minutes
        if [ -f "$VM_RESTART_FLAG" ]; then
            RESTART_AGE=$(( $(date +%s) - $(stat -c %Y $VM_RESTART_FLAG) ))
            if [ $RESTART_AGE -lt 1800 ]; then
                log "k3s VMs still unreachable but VM restart attempted $(( RESTART_AGE / 60 )) min ago — waiting"
                exit 0
            fi
        fi

        log "G4 up but k3s-cp-01 unreachable — restarting VMs and clearing CNI IPAM"
        discord "WARNING: G4 up but k3s VMs unreachable. Restarting VMs and clearing CNI IPAM."
        touch "$VM_RESTART_FLAG"

        # Stop k3s agents first to clean up CNI state
        ssh -i /root/.ssh/homelab_ed25519 -o ConnectTimeout=10 \
          -o StrictHostKeyChecking=no ubuntu@$K3S_W1 \
          'sudo systemctl stop k3s-agent && sudo find /var/lib/cni/networks/cbr0/ -type f -delete && sudo ip link delete cbr0 2>/dev/null; true' 2>/dev/null

        ssh -i /root/.ssh/homelab_ed25519 -o ConnectTimeout=10 \
          -o StrictHostKeyChecking=no ubuntu@$K3S_W2 \
          'sudo systemctl stop k3s-agent && sudo find /var/lib/cni/networks/cbr0/ -type f -delete && sudo ip link delete cbr0 2>/dev/null; true' 2>/dev/null

        # Restart VMs
        ssh -i /root/.ssh/homelab_ed25519 -o ConnectTimeout=10 \
          -o StrictHostKeyChecking=no root@$G4_IP \
          'for vm in 300 301 302; do qm stop $vm 2>/dev/null; done; sleep 5; for vm in 300 301 302; do qm start $vm; done' 2>/dev/null

        log "VM restart and CNI cleanup sent — waiting 30 min before retry"
        discord "INFO: VM restart and CNI IPAM cleanup triggered. Monitoring recovery."
        exit 0
    fi

    # G4 and k3s both reachable — clear VM restart flag
    rm -f "$VM_RESTART_FLAG"

    # Check if recovering from outage
    if [ -f "$RECOVERY_FLAG" ]; then
        log "G4 fully recovered — triggering ArgoCD refresh"
        sleep 180
        ssh -i /root/.ssh/homelab_ed25519 -o StrictHostKeyChecking=no ubuntu@$K3S_CP \
          'kubectl annotate application app-of-apps -n argocd argocd.argoproj.io/refresh=hard --overwrite 2>/dev/null' 2>/dev/null
        log "ArgoCD refresh triggered"
        discord "INFO: G4 fully recovered. ArgoCD refresh triggered."
        rm -f "$RECOVERY_FLAG"
    fi

    rm -f $FAIL_COUNT_FILE
    exit 0
fi

# G4 unreachable
FAILS=$(cat $FAIL_COUNT_FILE 2>/dev/null || echo 0)
FAILS=$((FAILS + 1))
echo $FAILS > $FAIL_COUNT_FILE
touch "$RECOVERY_FLAG"
log "G4 unreachable — failure count: $FAILS"

if [ $FAILS -eq 1 ]; then
    discord "WARNING: G4 (192.168.1.10) unreachable. Monitoring..."
    exit 0
fi

if [ $FAILS -eq 2 ]; then
    log "Attempting SSH recovery on G4"
    discord "WARNING: G4 still unreachable. Attempting SSH recovery..."
    ssh -i /root/.ssh/homelab_ed25519 -o ConnectTimeout=10 \
      -o StrictHostKeyChecking=no root@$G4_IP \
      "ip link set nic0 down && sleep 2 && ip link set nic0 up" 2>/dev/null
    exit 0
fi

if [ $FAILS -ge 3 ]; then
    log "G4 unreachable 6+ minutes — manual intervention required"
    discord "CRITICAL: G4 unreachable 6+ minutes. SSH recovery failed. Manual intervention required."
    echo 0 > $FAIL_COUNT_FILE
fi
