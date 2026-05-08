[![Gitleaks](https://github.com/sebastianastalos/homelab/actions/workflows/gitleaks.yml/badge.svg)](https://github.com/sebastianastalos/homelab/actions/workflows/gitleaks.yml)
[![Secrets](https://github.com/sebastianastalos/homelab/actions/workflows/secrets.yml/badge.svg)](https://github.com/sebastianastalos/homelab/actions/workflows/secrets.yml)
[![Deploy](https://github.com/sebastianastalos/homelab/actions/workflows/deploy.yml/badge.svg)](https://github.com/sebastianastalos/homelab/actions/workflows/deploy.yml)

<div align="center">

# homelab

My homelab runs entirely on a **UGREEN DXP4800 Pro** - UGOS replaced with TrueNAS Scale for full control over storage and services.

Everything is containerised and managed with Docker Compose. Renovate keeps services updated by opening PRs for new image versions, and GitHub Actions runs Gitleaks on every push and PR to catch leaked secrets before they land in the repo.

</div>

| Hardware | OS | Tools | Networking | Misc Automations |
| --- | --- | --- | --- | --- |
| [![UGREEN](https://img.shields.io/badge/-UGREEN_DXP4800_Pro-black?logo=ugreen&logoColor=white)](https://nas.ugreen.com) | [![TrueNAS](https://img.shields.io/badge/-TrueNAS_Scale-black?logo=truenas)](https://www.truenas.com/truenas-scale/) | [![Docker](https://img.shields.io/badge/-Docker-black?logo=docker)](https://www.docker.com/) [![Renovate](https://img.shields.io/badge/-Renovate-black?logo=renovate)](https://docs.renovatebot.com/) [![1Password](https://img.shields.io/badge/-1Password-black?logo=1password)](https://1password.com/) | [![Tailscale](https://img.shields.io/badge/-Tailscale-black?logo=tailscale)](https://tailscale.com/) [![Caddy](https://img.shields.io/badge/-Caddy-black?logo=caddy)](https://caddyserver.com/) | [![GitHub Actions](https://img.shields.io/badge/-GitHub_Actions-black?logo=githubactions)](https://github.com/features/actions) |

## **Security & Networking**

Secrets are stored in 1Password and loaded into GitHub Actions workflows via a Service Account. Tailscale provides secure remote access with no open ports. All services are exposed exclusively over the tailnet, with DNS handled by AdGuard Home. Caddy terminates HTTPS using Let's Encrypt wildcard certificates obtained via Porkbun DNS challenge.

## **Monitoring & Observability**

I use a combination of Grafana, Prometheus, Loki and Promtail to collect and visualise system metrics and logs. This gives full visibility into the infrastructure and helps detect issues proactively.

- **Prometheus** – metrics collection, scraping node-exporter and graphite-exporter
- **Grafana** – dashboarding and visualisation
- **Loki + Promtail** – centralised log aggregation from all Docker containers
- **Node Exporter** – host OS metrics (CPU, memory, disk, network)
- **Graphite Exporter** – bridges TrueNAS netdata metrics into Prometheus
- **Scrutiny** – drive S.M.A.R.T. health monitoring
- **Dozzle** – real-time Docker log viewer

<details>
<summary><strong>Hardware</strong></summary>

| Name    | Device             | CPU            | RAM       | Storage                              |
| ------- | ------------------ | -------------- | --------- | ------------------------------------ |
| truenas | UGREEN DXP4800 Pro | Intel i3-1315U | 16GB DDR5 | 2x Seagate IronWolf 4TB (ZFS mirror) |

Front-panel LEDs restored via [install_ugreen_leds_controller](https://github.com/0x556c79/install_ugreen_leds_controller).

</details>

<details>
<summary><strong>Services</strong></summary>

| Service | Description |
| --- | --- |
| **Jellyfin** | Media server with Intel Quick Sync hardware transcoding |
| **Immich** | Self-hosted photo backup and management |
| **Sonarr** | TV show & anime library management |
| **Radarr** | Movie library management |
| **Prowlarr** | Indexer manager |
| **Profilarr** | Quality profile manager for Sonarr/Radarr |
| **Bazarr** | Subtitle manager for Sonarr/Radarr |
| **qBittorrent** | Torrent client |
| **SABnzbd** | Usenet client |
| **Seerr** | Media request portal |
| **AIOStreams** | Stremio addon aggregator |
| **Tracearr** | Media server monitoring |
| **AdGuard Home** | Network-wide DNS filter |
| **Gluetun** | WireGuard VPN gateway |
| **Tailscale** | Remote access mesh VPN |
| **Homepage** | Services dashboard |
| **code-server** | Web-based VS Code editor |
| **Prometheus** | Metrics storage |
| **Grafana** | Metrics dashboards |
| **Node Exporter** | Host metrics exporter |
| **Loki** | Log aggregation |
| **Promtail** | Log collector for Docker containers |
| **Dozzle** | Real-time Docker log viewer |
| **Scrutiny** | Hard drive S.M.A.R.T. health monitoring |
| **Autobrr** | Torrent automation |
| **Graphite Exporter** | TrueNAS metrics bridge for Prometheus |
| **Nginx Proxy Manager** | Local reverse proxy |
| **Caddy** | HTTPS reverse proxy with Let's Encrypt via Porkbun DNS |
| **iSponsorBlockTV** | SponsorBlock for Apple TV / YouTube TV |
| **Paperless-ngx** | Document management and OCR |
| **GitHub Runner** | Self-hosted GitHub Actions runner |

</details>
