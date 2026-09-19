TZ=Europe/London
ACTUAL_FLOW_MODE=scheduled
ACTUAL_FLOW_CRON=0 6 * * *
ACTUAL_FLOW_RUN_ON_STARTUP=false
# Actual is reached over the LAN without TLS, but never disable verification.
NODE_TLS_REJECT_UNAUTHORIZED=1
# The Lunch Flow API key and the Actual password are not set here - the
# interactive setup writes them to data/config.json, which is gitignored.
