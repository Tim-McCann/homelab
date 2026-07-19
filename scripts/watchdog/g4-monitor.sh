#!/bin/bash
G4_IP="192.168.1.10"
K3S_CP="192.168.1.30"
DISCORD_WEBHOOK="https://discord.com/api/webhooks/1522967702547988553/cV90stFYA86JQvQsgVydb6zj8kR4Xa_fHFbIyxauMNZskyTwhw7bUjrM8vhgMkRQLPhC"
FAIL_COUNT_FILE="/tmp/g4-monitor-fails"
RECOVERY_FLAG="/tmp/g4-recovering"
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

    # Check if k3s control plane is also reachable
    if ! ping -c 2 -W 3 $K3S_CP > /dev/null 2>&1; then
        log "G4 up but k3s-cp-01 unreachable — restarting VMs"
        discord "WARNING: G4 up but k3s VMs unreachable. Restarting VMs via SSH."
        ssh -i /root/.ssh/homelab_ed25519 -o ConnectTimeout=10 \
          -o StrictHostKeyChecking=no root@$G4_IP \
          'for vm in 300 301 302; do qm stop $vm 2>/dev/null; done; sleep 5; for vm in 300 301 302; do qm start $vm; done' 2>/dev/null
        log "VM restart command sent"
        sleep 90
        if ping -c 2 -W 3 $K3S_CP > /dev/null 2>&1; then
            log "k3s VMs recovered after restart"
            discord "INFO: k3s VMs recovered after restart."
        else
            discord "CRITICAL: k3s VMs still unreachable after restart. Manual intervention required."
        fi
        exit 0
    fi

    # G4 and k3s both reachable — check if recovering
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
