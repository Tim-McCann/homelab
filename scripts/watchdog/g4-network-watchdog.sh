#!/bin/bash
GATEWAY="192.168.1.254"
K3S_CP="192.168.1.30"
LOGFILE="/var/log/network-watchdog.log"
DISCORD_WEBHOOK="https://discord.com/api/webhooks/1522967702547988553/cV90stFYA86JQvQsgVydb6zj8kR4Xa_fHFbIyxauMNZskyTwhw7bUjrM8vhgMkRQLPhC"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> $LOGFILE
}

discord() {
    curl -s -X POST "$DISCORD_WEBHOOK" \
      -H "Content-Type: application/json" \
      -d "{\"content\": \"$1\"}" > /dev/null 2>&1
}

# Check for Hardware Unit Hang in last 60 seconds
HW_HANG=$(dmesg --time-format iso 2>/dev/null | grep "Hardware Unit Hang" | \
  awk -v d="$(date -u -d '60 seconds ago' '+%Y-%m-%dT%H:%M')" '$1 > d' | wc -l)

if [ "$HW_HANG" -gt "0" ]; then
    log "e1000e Hardware Unit Hang detected — rebooting"
    discord "CRITICAL: G4 Hardware Unit Hang detected. Auto-rebooting."
    sleep 10
    reboot
    exit 0
fi

# Check gateway reachability
if ! ping -c 2 -W 3 $GATEWAY > /dev/null 2>&1; then
    log "Gateway unreachable — resetting nic0 only"
    ip link set nic0 down
    sleep 2
    ip link set nic0 up
    sleep 5
    if ping -c 2 -W 3 $GATEWAY > /dev/null 2>&1; then
        log "Recovery successful via nic0 reset"
    else
        log "Recovery failed"
        discord "CRITICAL: G4 gateway unreachable after nic0 reset. Manual intervention required."
    fi
    exit 0
fi

# NEW: Check if k3s VMs are reachable from G4 host
# If gateway is up but VMs unreachable, NIC hang is blocking bridge traffic
if ! ping -c 2 -W 3 $K3S_CP > /dev/null 2>&1; then
    # Check if this is a NIC hang
    RECENT_HANG=$(dmesg --time-format iso 2>/dev/null | grep "Hardware Unit Hang" | \
      awk -v d="$(date -u -d '300 seconds ago' '+%Y-%m-%dT%H:%M')" '$1 > d' | wc -l)
    
    if [ "$RECENT_HANG" -gt "0" ]; then
        log "k3s VMs unreachable and NIC hang detected — rebooting"
        discord "CRITICAL: k3s VMs unreachable due to NIC hang. Auto-rebooting G4."
        sleep 10
        reboot
        exit 0
    fi

    log "k3s VMs unreachable but no NIC hang — resetting nic0"
    ip link set nic0 down
    sleep 2
    ip link set nic0 up
    sleep 10

    if ping -c 2 -W 3 $K3S_CP > /dev/null 2>&1; then
        log "k3s VM connectivity restored via nic0 reset"
    else
        log "k3s VMs still unreachable — rebooting"
        discord "CRITICAL: k3s VMs unreachable after nic0 reset. Auto-rebooting G4."
        sleep 5
        reboot
    fi
fi
