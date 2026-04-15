Docker Compose configurations for my self-hosted homelab running on TrueNAS Scale.

| Hardware                                                                              | OS                                                                                                                   | Tools                                                                                        | Networking                                                                                           |
| ------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| [![UGREEN](https://img.shields.io/badge/-UGREEN_DXP4800_Pro-black)](https://nas.ugreen.com) | [![TrueNAS](https://img.shields.io/badge/-TrueNAS_Scale-black?logo=truenas)](https://www.truenas.com/truenas-scale/) | [![Docker](https://img.shields.io/badge/-Docker-black?logo=docker)](https://www.docker.com/) | [![Tailscale](https://img.shields.io/badge/-Tailscale-black?logo=tailscale)](https://tailscale.com/) |

## 📍 To-Do

See [Project Board](https://github.com/users/sebastianastalos/projects/1)

## Hardware

| Name    | Device             | CPU            | RAM       | Storage                              |
| ------- | ------------------ | -------------- | --------- | ------------------------------------ |
| truenas | UGREEN DXP4800 Pro | Intel i3-1315U | 16GB DDR5 | 2x Seagate IronWolf 4TB (ZFS mirror) |

## Services

| Service         | Description                                             |
| --------------- | ------------------------------------------------------- |
| **Jellyfin**    | Media server with Intel Quick Sync hardware transcoding |
| **Sonarr**      | TV show & anime library management                      |
| **Radarr**      | Movie library management                                |
| **Prowlarr**    | Indexer manager (routed through Gluetun VPN)            |
| **qBittorrent** | Torrent client (routed through Gluetun VPN)             |
| **SABnzbd**     | Usenet client (SSL, no VPN needed)                      |
| **Gluetun**     | WireGuard VPN gateway (ProtonVPN)                       |
| **Seerr**       | Media request portal                                    |
| **Homepage**    | Services dashboard                                      |
| **Tailscale**   | Remote access & exit node                               |
| **code-server** | Web-based VS Code editor                                |
