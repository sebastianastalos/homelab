#!/bin/bash
set -e

APP=$1

if [ -z "$APP" ]; then
    echo "Usage: new-app.sh <appname>"
    exit 1
fi

if [ "$EUID" -eq 0 ]; then
    echo "Do not run this script with sudo. Run as truenas_admin directly."
    exit 1
fi

DATASET="app/$APP"
APPDIR="/mnt/app/$APP"

if zfs list "$DATASET" &>/dev/null; then
    echo "Dataset $DATASET already exists, skipping zfs create"
else
    sudo zfs create "$DATASET"
    echo "Created dataset $DATASET"
fi

sudo chown truenas_admin:truenas_admin "$APPDIR"
sudo chmod 755 "$APPDIR"

touch "$APPDIR/docker-compose.yml"
touch "$APPDIR/.env"
[ -f "$APPDIR/.env.example" ] || echo "TZ=Europe/London" > "$APPDIR/.env.example"

echo "Note: run 'sudo chown -R 950:950 $APPDIR/<subdir>' for any config subdirectories after creating them."

if [ ! -s "$APPDIR/docker-compose.yml" ]; then
    echo "Next: fill in $APPDIR/docker-compose.yml, then re-run this script to deploy."
    exit 0
fi

if sudo midclt call app.query "[[\"name\",\"=\",\"$APP\"]]" | grep -q '"name"'; then
    echo "App $APP already exists in TrueNAS. Push a compose change to redeploy it."
    exit 0
fi

PAYLOAD=$(python3 -c 'import json, sys; print(json.dumps({"app_name": sys.argv[1], "custom_app": True, "custom_compose_config_string": "include:\n  - %s/docker-compose.yml" % sys.argv[2]}))' "$APP" "$APPDIR")

echo "Creating custom app $APP..."
sudo midclt call app.create "$PAYLOAD"
echo "Job submitted. Watch progress in the Apps UI, or: sudo midclt call app.query '[[\"name\",\"=\",\"$APP\"]]'"
