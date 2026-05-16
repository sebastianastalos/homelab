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
echo "TZ=Europe/London" > "$APPDIR/.env.example"

echo "Created docker-compose.yml, .env, .env.example in $APPDIR"
echo "Done. Fill in $APPDIR/docker-compose.yml and deploy via TrueNAS UI."
echo "Note: run 'sudo chown -R 950:950 $APPDIR/<subdir>' for any config subdirectories after creating them."
