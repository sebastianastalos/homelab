#!/bin/bash
set -e

cd /mnt/app

if [ "$EUID" -eq 0 ]; then
    echo "Do not run this script with sudo. Run as truenas_admin directly."
    exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
    STASHED=1
    git stash
else
    STASHED=0
fi

git pull https://github.com/sebastianastalos/homelab.git main --rebase

if [ "$STASHED" -eq 1 ]; then
    git stash pop
fi

echo "Repo synced."
