[![gitleaks](https://github.com/sebastianastalos/homelab/actions/workflows/gitleaks.yml/badge.svg)](https://github.com/sebastianastalos/homelab/actions/workflows/gitleaks.yml)

Docker Compose configurations for my self-hosted homelab running on TrueNAS Scale.

| Hardware                                                                                               | OS                                                                                                                   | Tools                                                                                                                                                                                            | Networking                                                                                           | Misc Automations                                                                                                                     |
| ------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| [![UGREEN](https://img.shields.io/badge/-UGREEN_DXP4800_Pro-black?logo=ugreen&logoColor=white)](https://nas.ugreen.com) | [![TrueNAS](https://img.shields.io/badge/-TrueNAS_Scale-black?logo=truenas)](https://www.truenas.com/truenas-scale/) | [![Docker](https://img.shields.io/badge/-Docker-black?logo=docker)](https://www.docker.com/) [![Renovate](https://img.shields.io/badge/-Renovate-black?logo=renovatebot)](https://docs.renovatebot.com/) | [![Tailscale](https://img.shields.io/badge/-Tailscale-black?logo=tailscale)](https://tailscale.com/) | [![GitHub Actions](https://img.shields.io/badge/-GitHub_Actions-black?logo=githubactions)](https://github.com/features/actions) |

## 📍 To-Do

See [Project Board](https://github.com/users/sebastianastalos/projects/1)

## Hardware

| Name    | Device             | CPU            | RAM       | Storage                              |
| ------- | ------------------ | -------------- | --------- | ------------------------------------ |
| truenas | UGREEN DXP4800 Pro | Intel i3-1315U | 16GB DDR5 | 2x Seagate IronWolf 4TB (ZFS mirror) |

Front-panel LEDs restored via [install_ugreen_leds_controller](https://github.com/0x556c79/install_ugreen_leds_controller).

## Services

| Service           | Description                                             |
| ----------------- | ------------------------------------------------------- |
| **Jellyfin**      | Media server with Intel Quick Sync hardware transcoding |
| **Immich**        | Self-hosted photo backup and management                 |
| **Sonarr**        | TV show & anime library management                      |
| **Radarr**        | Movie library management                                |
| **Prowlarr**      | Indexer manager                                         |
| **Profilarr**     | Quality profile manager for Sonarr/Radarr               |
| **qBittorrent**   | Torrent client                                          |
| **SABnzbd**       | Usenet client                                           |
| **Seerr**         | Media request portal                                    |
| **AIOStreams**    | Stremio addon aggregator                                |
| **Tracearr**      | Media server monitoring                                 |
| **AdGuard Home**  | Network-wide DNS filter                                 |
| **Gluetun**       | WireGuard VPN gateway                                   |
| **Tailscale**     | Remote access mesh VPN                                  |
| **Homepage**      | Services dashboard                                      |
| **code-server**   | Web-based VS Code editor                                |
| **Prometheus**    | Metrics storage                                         |
| **Grafana**       | Metrics dashboards                                      |
| **Node Exporter** | Host metrics exporter                                   |
