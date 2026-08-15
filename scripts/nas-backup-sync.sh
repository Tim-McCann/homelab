#!/bin/bash
# Run on NUC5 host — syncs PBS backup data to NAS
# Runs every 2 weeks after stopping PBS container
LOGFILE=/var/log/nas-backup-sync.log
DISCORD_WEBHOOK="https://discord.com/api/webhooks/1522967702547988553/cV90stFYA86JQvQsgVydb6zj8kR4Xa_fHFbIyxauMNZskyTwhw7bUjrM8vhgMkRQLPhC"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> $LOGFILE
}

discord() {
    curl -s -X POST "$DISCORD_WEBHOOK" \
      -H "Content-Type: application/json" \
      -d "{\"content\": \"$1\"}" > /dev/null 2>&1
}

log "Starting PBS backup sync to NAS"

# Stop PBS container to safely mount disk
pct stop 103
sleep 5

# Mount PBS disk
mkdir -p /mnt/pbs-data
mount /dev/pve/vm-103-disk-0 /mnt/pbs-data

# Sync to NAS
rsync -av --delete --no-owner --no-group --no-perms --omit-dir-times \
  /mnt/pbs-data/var/lib/pbs-backups/ \
  /mnt/nas-backups/pbs-backups/ >> $LOGFILE 2>&1

RESULT=$?

# Unmount and restart PBS
umount /mnt/pbs-data
pct start 103

if [ $RESULT -eq 0 ]; then
    log "Sync completed successfully"
    discord "INFO: PBS backup sync to NAS completed successfully"
else
    log "Sync FAILED"
    discord "CRITICAL: PBS backup sync to NAS FAILED — check /var/log/nas-backup-sync.log"
fi
