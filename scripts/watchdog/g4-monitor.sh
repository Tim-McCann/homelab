#!/bin/bash
# G4 Monitor — runs on NUC5
# Monitors G4 reachability and attempts SSH recovery

G4_IP="192.168.1.10"
DISCORD_WEBHOOK="https://discord.com/api/webhooks/1522967702547988553/cV90stFYA86JQvQsgVydb6zj8kR4Xa_fHFbIyxauMNZskyTwhw7bUjrM8vhgMkRQLPhC"
FAIL_COUNT_FILE="/tmp/g4-monitor-fails"
LOGFILE="/var/log/g4-monitor.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> $LOGFILE
}

discord() {
    curl -s -X POST "$DISCORD_WEBHOOK" \
      -H "Content-Type: application/json" \
      -d "{\"content\": \"$1\"}"
}

# G4 reachable — reset counter
if ping -c 2 -W 3 $G4_IP > /dev/null 2>&1; then
    rm -f $FAIL_COUNT_FILE
    exit 0
fi

FAILS=$(cat $FAIL_COUNT_FILE 2>/dev/null || echo 0)
FAILS=$((FAILS + 1))
echo $FAILS > $FAIL_COUNT_FILE
log "G4 unreachable — failure count: $FAILS"

if [ $FAILS -eq 1 ]; then
    discord "WARNING: G4 (192.168.1.10) unreachable. Monitoring..."
    exit 0
fi

if [ $FAILS -eq 2 ]; then
    log "Attempting SSH recovery on G4"
    discord "WARNING: G4 still unreachable. Attempting SSH recovery..."
    ssh -i /root/.ssh/homelab_ed25519 -o ConnectTimeout=10 -o StrictHostKeyChecking=no root@$G4_IP \
      "ip link set nic0 down && sleep 2 && ip link set nic0 up && sleep 2 && ifdown vmbr0; ifup vmbr0" 2>/dev/null
    exit 0
fi

if [ $FAILS -ge 3 ]; then
    log "G4 unreachable for 6+ minutes — SSH recovery failed"
    discord "CRITICAL: G4 unreachable 6+ minutes. SSH recovery failed. Manual intervention required. Check physical hardware."
    echo 0 > $FAIL_COUNT_FILE
fi
