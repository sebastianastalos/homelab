TZ=Europe/London
# 1=Monday .. 7=Sunday, matching date +%u
SYNC_DAY=7
SYNC_AT=06:30
ACTUAL_SERVER_URL=http://192.168.1.131:5006
ACTUAL_ACCOUNT_NAME=Trading212
# Secrets are written straight into .env on this host and never here: the app is
# excluded from the deploy workflow, and that workflow is what renders op://
# references. 1Password holds the master copy.
#
# .env must also contain:
#   TRADING212_API_KEY / TRADING212_API_SECRET  (T212 app: Settings -> API (Beta))
#   ACTUAL_PASSWORD / ACTUAL_SYNC_ID
