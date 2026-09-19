#!/bin/bash
set -e

MODE="${ACTUAL_FLOW_MODE:-scheduled}"
CRON="${ACTUAL_FLOW_CRON:-0 6 * * *}"
cd /app/config

if [ "$MODE" = "interactive" ]; then
    exec actual-flow
fi

if [ ! -f config.json ]; then
    echo "config.json missing - run the interactive setup first" >&2
    exit 1
fi

if [ "$MODE" = "once" ]; then
    exec actual-flow import
fi

if [ "$ACTUAL_FLOW_RUN_ON_STARTUP" = "true" ]; then
    actual-flow import || echo "startup import failed - retrying on schedule" >&2
fi

# crontabs live in /tmp so the container can run as 950 rather than root.
mkdir -p /tmp/crontabs
echo "$CRON cd /app/config && actual-flow import >> /proc/1/fd/1 2>&1" > /tmp/crontabs/root
exec crond -f -l 2 -c /tmp/crontabs
