#!/bin/bash
set -e

MODE="${ACTUAL_FLOW_MODE:-scheduled}"
AT="${ACTUAL_FLOW_AT:-06:00}"
cd /app/config

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S %Z')] $*"; }

# After importing, set each category's budget to what it actually spent. Nothing
# is planned - it just marks spending as covered, so the budget screen reads
# settled rather than overspent. Covers last month too, for late arrivals.
cover_spending() {
    if node /usr/local/lib/cover.js; then
        log "budget screen marked as covered"
    else
        log "covering spending FAILED - budget screen may show red" >&2
    fi
}

run_import() {
    log "starting import"
    if actual-flow import; then
        log "import finished"
        cover_spending
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
# schedule is a plain loop instead. ACTUAL_FLOW_AT is a comma-separated list of
# local times; the loop sleeps until whichever comes next, recomputed each pass
# so a DST change corrects itself.
next_delta() {
    now=$(( 10#$(date +%H) * 3600 + 10#$(date +%M) * 60 + 10#$(date +%S) ))
    best=""
    for t in $(echo "$AT" | tr ',' ' '); do
        hh=${t%%:*}
        mm=${t##*:}
        tgt=$(( 10#$hh * 3600 + 10#$mm * 60 ))
        d=$(( tgt - now ))
        if [ "$d" -le 0 ]; then
            d=$(( d + 86400 ))
        fi
        if [ -z "$best" ] || [ "$d" -lt "$best" ]; then
            best=$d
        fi
    done
    echo "$best"
}

while :; do
    delta=$(next_delta)
    log "next import in ${delta}s (schedule: $AT)"
    sleep "$delta"
    run_import
done
