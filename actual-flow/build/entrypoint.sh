#!/bin/bash
set -e

MODE="${ACTUAL_FLOW_MODE:-scheduled}"
AT="${ACTUAL_FLOW_AT:-06:00}"
cd /app/config

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S %Z')] $*"; }

run_import() {
    log "starting import"
    if actual-flow import; then
        log "import finished"
    else
        log "import FAILED - will retry on the next run" >&2
    fi
}

if [ "$MODE" = "interactive" ]; then
    exec actual-flow
fi

if [ ! -f config.json ]; then
    echo "config.json missing - run the interactive setup first" >&2
    exit 1
fi

if [ "$MODE" = "once" ]; then
    run_import
    exit 0
fi

if [ "$ACTUAL_FLOW_RUN_ON_STARTUP" = "true" ]; then
    run_import
fi

# busybox crond silently refuses to load a crontab as a non-root daemon, so the
# schedule is a plain loop instead - one import a day at $ACTUAL_FLOW_AT local
# time, recomputed each pass so a DST change corrects itself.
hh=${AT%%:*}
mm=${AT##*:}
while :; do
    now=$(( 10#$(date +%H) * 3600 + 10#$(date +%M) * 60 + 10#$(date +%S) ))
    tgt=$(( 10#$hh * 3600 + 10#$mm * 60 ))
    delta=$(( tgt - now ))
    if [ "$delta" -le 0 ]; then
        delta=$(( delta + 86400 ))
    fi
    log "next import at $AT (in ${delta}s)"
    sleep "$delta"
    run_import
done
