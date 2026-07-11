#!/bin/bash
# Network watchdog for G4
# Detects NIC failures and auto-recovers by resetting vmbr0

GATEWAY="192.168.1.254"
LOGFILE="/var/log/network-watchdog.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> $LOGFILE
}

# Test connectivity
if ping -c 2 -W 3 $GATEWAY > /dev/null 2>&1; then
    exit 0
fi

log "Gateway unreachable — attempting recovery"

# Reset nic0 and bridge
ip link set nic0 down
sleep 2
ip link set nic0 up
sleep 2
ifdown vmbr0 2>/dev/null
ifup vmbr0 2>/dev/null
sleep 5

# Test again
if ping -c 2 -W 3 $GATEWAY > /dev/null 2>&1; then
    log "Recovery successful"
    exit 0
fi

log "Recovery failed — sending Discord alert"

# Send Discord notification
curl -s -X POST "https://discord.com/api/webhooks/1522967702547988553/cV90stFYA86JQvQsgVydb6zj8kR4Xa_fHFbIyxauMNZskyTwhw7bUjrM8vhgMkRQLPhC" \
  -H "Content-Type: application/json" \
  -d "{\"content\": \"CRITICAL: G4 network recovery failed. Manual intervention required. Gateway $GATEWAY unreachable after NIC reset.\"}"
