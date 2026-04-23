#!/usr/bin/env bash
# Restores custom icons on TrueNAS Custom Apps by injecting an "icon" key
# into each app's metadata.yaml. Run with sudo from the TrueNAS host shell.

set -euo pipefail

# Map: <truenas-app-name> <dashboard-icons-slug>
# Icon catalog: https://github.com/homarr-labs/dashboard-icons/tree/main/png
declare -A ICONS=(
  [adguard]=adguard-home
  [aiostreams]=stremio
  [bazarr]=bazarr
  [code-server]=code-server
  [gluetun]=gluetun
  [grafana]=grafana
  [homepage]=homepage
  [immich]=immich
  [jellyfin]=jellyfin
  [node-exporter]=prometheus
  [profilarr]=profilarr
  [prometheus]=prometheus
  [prowlarr]=prowlarr
  [qbittorrent]=qbittorrent
  [radarr]=radarr
  [sabnzbd]=sabnzbd
  [seerr]=jellyseerr
  [sonarr]=sonarr
  [tailscale]=tailscale
  [tracearr]=tautulli
)

BASE_URL="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png"
CONFIGS_DIR="/mnt/.ix-apps/app_configs"

for app in "${!ICONS[@]}"; do
  meta="$CONFIGS_DIR/$app/metadata.yaml"
  slug="${ICONS[$app]}"
  url="$BASE_URL/$slug.png"

  if [[ ! -f "$meta" ]]; then
    echo "SKIP  $app — $meta not found"
    continue
  fi

  if grep -q '^  "icon":' "$meta"; then
    # Already has an icon key — overwrite its value in place
    sed -i "s|^  \"icon\": \".*\"|  \"icon\": \"$url\"|" "$meta"
    echo "UPDATE $app → $slug"
  else
    # Insert icon key after the train line
    sed -i "/^  \"train\": \"stable\"/a\\  \"icon\": \"$url\"" "$meta"
    echo "ADD   $app → $slug"
  fi
done

echo
echo "Restarting middlewared to pick up changes..."
systemctl restart middlewared
echo "Done. Refresh the TrueNAS Apps UI."
