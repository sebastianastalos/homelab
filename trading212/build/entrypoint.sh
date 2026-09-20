#!/bin/bash
set -e

DAY="${SYNC_DAY:-7}"      # 1=Monday .. 7=Sunday, as date +%u
AT="${SYNC_AT:-06:30}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S %Z')] $*"; }

run_sync() {
    log "starting sync"
    if node /usr/local/lib/sync.js; then
        log "sync finished"
    else
        log "sync FAILED - will retry on the next run" >&2
    fi
}

if [ "$SYNC_MODE" = "once" ]; then
    run_sync
    exit 0
fi

log "scheduled for day $DAY at $AT (1=Mon .. 7=Sun)"
while :; do
    if [ "$(date +%u)" = "$DAY" ] && [ "$(date +%H:%M)" = "$AT" ]; then
        run_sync
        sleep 61
    fi
    sleep 30
done
