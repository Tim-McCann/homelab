#!/bin/bash
# Network watchdog for NUC5
# Detects WiFi drop and auto-reconnects

GATEWAY="192.168.1.254"
IFACE="wlp2s0"
LOGFILE="/var/log/network-watchdog.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> $LOGFILE
}

if ping -c 2 -W 3 $GATEWAY > /dev/null 2>&1; then
    exit 0
fi

log "Gateway unreachable — attempting WiFi reconnection"

ip link set $IFACE down
sleep 2
ip link set $IFACE up
sleep 2
wpa_supplicant -B -i $IFACE -c /etc/wpa_supplicant/wpa_supplicant.conf
sleep 5
dhclient $IFACE
sleep 3
ip route replace default via $GATEWAY dev $IFACE

if ping -c 2 -W 3 $GATEWAY > /dev/null 2>&1; then
    log "Recovery successful"
    exit 0
fi

log "Recovery failed — sending Discord alert"

curl -s -X POST "https://discord.com/api/webhooks/1522967702547988553/cV90stFYA86JQvQsgVydb6zj8kR4Xa_fHFbIyxauMNZskyTwhw7bUjrM8vhgMkRQLPhC" \
  -H "Content-Type: application/json" \
  -d "{\"content\": \"CRITICAL: NUC5 network recovery failed. Manual intervention required.\"}"
