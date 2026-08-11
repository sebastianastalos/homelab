# ARCHITECTURE.md

How this homelab is put together and **why** – the decisions, the constraints
that forced them, and the things that were tried and reversed. It describes what
exists today, not a plan.

Concrete values (IP addresses, the real domain, port numbers, credential
locations) are deliberately not repeated here. They live in the gitignored
**HOMELAB.md**, in [caddy/config/Caddyfile](caddy/config/Caddyfile) for
anything reverse-proxied, and in each app's compose file.

---

## The shape of the system

One machine. A UGREEN DXP4800 Pro with an Intel i3-1315U and 16GB of DDR5,
running TrueNAS Scale with UGOS removed. Roughly forty Docker services, each
deployed as a **TrueNAS Custom App** wrapping a compose file from this repo.

Three storage pools, each with a distinct job:

| Pool | Hardware | Holds |
|---|---|---|
| `storage` | 4TB + 8TB IronWolf ZFS mirror | `mediadata` – the media library and all downloads, plus the TrueNAS system dataset |
| `app` | Samsung 980 Pro NVMe, single disk | `ix-apps` (Docker runtime) and one config dataset per service |
| `boot-pool` | Samsung 970 Pro | TrueNAS itself |

The repo root **is** `/mnt/app`, so each service's directory in git is the same
directory the container mounts its config from. There is no build or copy step
between the repo and the running system.

### Why Custom Apps with the include method

TrueNAS Scale offers a catalogue of one-click apps. This repo does not use it.
Every service is a Custom App whose entire configuration is:

```yaml
include:
  - /mnt/app/<app>/docker-compose.yml
```

That one indirection is what makes the rest of the setup possible. TrueNAS still
owns container lifecycle, so the Apps UI, its health reporting and its restart
handling all keep working – but the actual definition is a plain compose file in
git, editable by any tool, reviewable in a PR, and updatable by Renovate. The
catalogue's own apps hide their configuration behind a form, which neither
version-controls nor diffs.

The alternatives were considered and rejected: running `docker compose` directly
under a systemd unit means TrueNAS no longer knows the containers exist and an
OS upgrade can disrupt the daemon underneath them; managing stacks in Portainer
gains a nicer API but moves lifecycle out of TrueNAS entirely.

**Consequence to be aware of:** because TrueNAS wraps each compose file in its
own project namespace (`ix-<app>`), containers from different apps are on
different Docker networks and cannot resolve each other by service name. This is
why cross-service references use the host's LAN address rather than a container
name – see [Ingress](#ingress-caddy-and-tls).

---

## Storage and the hardlink constraint

**`storage/mediadata` is a single ZFS dataset.** Inside it, `media/` and `data/`
are plain directories:

```
mediadata/
  media/{movies,tvshows,anime}
  data/torrents/{complete,incomplete}/{tv,movies,anime}
  data/usenet/{complete,incomplete}/{tv,movies,anime}
```

This is the most important structural decision in the repo, and the easiest to
break by "tidying up". Hardlinks cannot cross a ZFS dataset boundary. Keeping
downloads and the library in one dataset means Sonarr and Radarr import by
creating a hardlink: instant, and consuming no additional space, while the
torrent stays seedable. Split `media/` and `data/` into two datasets – the
obvious-looking improvement, since it would allow separate snapshot policies –
and every import silently becomes a full copy. Disk use roughly doubles and
imports take as long as the file takes to write.

Every app that touches media mounts the same two paths, so the mappings between
them are identity: `/media` and `/data`. Bazarr shares Sonarr and Radarr's
`/media`, which is why no path mapping is needed between them.

Verify a hardlink survived an import by comparing inode numbers – matching first
column means one file, two names:

```bash
ls -li /mnt/storage/mediadata/data/torrents/complete/<cat>/<file> \
       /mnt/storage/mediadata/media/<type>/<title>/<file>
```

### Why the pools are split this way

Media lives on the mirror because it is bulk data that must survive a disk
failure and does not need speed. App state lives on the single NVMe because
container startup, database writes and the Docker overlay are latency-sensitive,
and because that state is *rebuildable*: the compose files are in git and
anything irreplaceable is on the mirror. A single-disk pool is an accepted risk
for data that can be reconstructed, not a mistake.

Each service gets **its own dataset** under `app/`, rather than directories in
one dataset, purely for snapshot granularity – so a single service can be rolled
back without touching the others.

---

## Egress: the VPN boundary

> **Current state:** the `gluetun` and `qbittorrent` containers are stopped. The
> compose files below still describe the wiring, so starting Gluetun before
> qBittorrent restores it – order matters, since qBittorrent cannot start
> without its network namespace host.

`gluetun` holds a ProtonVPN WireGuard tunnel and is the only container with
`NET_ADMIN` and `/dev/net/tun`. **qBittorrent** routes its entire network stack
through it:

```yaml
network_mode: "container:gluetun"
```

The consequence is structural, not cosmetic: qBittorrent has **no network
namespace of its own**, so it cannot declare `ports:`. Its web UI is published on
the Gluetun container instead, which is why Gluetun's compose file exposes ports
that have nothing to do with Gluetun. If Gluetun stops, qBittorrent stops being
reachable – the intended failure mode, since it also means it cannot leak
traffic outside the tunnel.

**Prowlarr used to be routed this way and no longer is.** Commit `ae5e6e9` moved
it off the Gluetun network and gave it its own `9696`. The rationale was not
recorded in the commit; the practical effect is that indexer traffic now leaves
over the host's normal connection.

SABnzbd deliberately does **not** go through the VPN. Usenet is fetched over
SSL from paying providers; there is no peer exposure to hide, and routing it
through the tunnel would only cap throughput.

Confirm the tunnel is actually carrying traffic:

```bash
sudo docker exec qbittorrent wget -qO- https://ipinfo.io/ip
```

Three usenet providers are configured in SABnzbd as a priority ladder across
three distinct backbones, so that a gap in one provider's retention or article
completion is covered by another. Provider names and credentials are in
HOMELAB.md and SABnzbd's own config, not here.

---

## Ingress: Caddy and TLS

Caddy terminates HTTPS on 80 and 443 and holds a **wildcard certificate**
obtained from Let's Encrypt through a **Porkbun DNS-01 challenge**. The DNS
challenge is the point: a wildcard cert cannot be issued over HTTP-01 at all,
and DNS-01 needs no inbound port open to the internet, which suits a system
whose services are reachable only over the tailnet.

Freeing 80 and 443 for Caddy required moving the **TrueNAS web UI to 81 and
444**. Anything that appears to point at an odd TrueNAS port is correct.

Each service gets a subdomain block in [the Caddyfile](caddy/config/Caddyfile)
reverse-proxying to **the host's LAN address and the service's published port**,
not to a container name. That looks wrong at first glance and is deliberate:
Caddy runs in its own `ix-caddy` project namespace and cannot resolve containers
belonging to other apps (see
[Why Custom Apps](#why-custom-apps-with-the-include-method)). Going out to the
host and back in is the simplest thing that works across all forty services.

Two services need `header_up Host {upstream_hostport}` because they validate the
Host header against their own expected origin and reject Caddy's otherwise.

**Nginx Proxy Manager is still deployed but superseded.** It came first, was
replaced by Caddy for the wildcard-cert workflow, and now serves only as a
secondary HTTP proxy. **Tailscale Serve was also used for this and has been
reset** – it is no longer part of the ingress path, though its state volume
persists so the command still works if needed.

---

## DNS and remote access

**AdGuard Home uses `network_mode: host`.** On a bridge network it would see
every query as coming from the Docker gateway, making per-client filtering and
query logs useless. Host networking gives it real client addresses. The cost is
that its web UI had to move off port 80 to avoid colliding with the reverse
proxy.

AdGuard is the **tailnet-wide** DNS server, set as a global nameserver in the
Tailscale admin console with "Override local DNS" enabled, so filtering applies
to every device on the tailnet rather than only those on the LAN.

**Tailscale provides all remote access; no ports are forwarded from the
internet.** It also acts as a **subnet router**, advertising the home LAN range
so tailnet devices can reach local addresses directly. That has a non-obvious
benefit: Tailscale's split-DNS entry for the local domain can point at AdGuard's
*LAN* address rather than its tailnet address, because subnet routing makes the
LAN reachable from everywhere on the tailnet.

Service DNS is a wildcard A record pointing at the NAS's **Tailscale** address,
so `<service>.<domain>` resolves publicly but only routes for tailnet members.

---

## Hardware transcoding

Jellyfin gets `/dev/dri:/dev/dri` and `group_add: "107"`. GID 107 is the
`render` group **on this host specifically** – confirm with
`getent group render` before assuming it carries to another machine. Without the
group membership the device node is present but unusable, which presents as
software transcoding with no error.

The i3-1315U is 12th-gen Alder Lake, and its Quick Sync block **encodes H.264
and HEVC only**. It can *decode* AV1 but not encode it, so "Allow encoding in
AV1 format" must stay unticked in Jellyfin's transcoding settings; ticking it
produces failed transcodes rather than a graceful fallback.

---

## The media pipeline

Request and automation front ends (Seerr, Autobrr, AIOStreams) feed the
Servarr apps, which hand work to the download clients and import the results
into the library by hardlink.

Path conventions matter more than they look, because they are what makes the
hardlinks land in the same dataset:

| Component | Paths |
|---|---|
| Jellyfin | media at `/data/media/{movies,tvshows,anime}` |
| Sonarr root folders | `/media/tvshows`, `/media/anime` |
| Radarr root folder | `/media/movies` |
| qBittorrent | complete `/data/torrents/complete/<category>`, incomplete `/data/torrents/incomplete` |
| SABnzbd | complete `/data/usenet/complete/<category>`, incomplete `/data/usenet/incomplete` |

Download categories are `tv-sonarr`, `radarr` and `anime-sonarr` in qBittorrent;
`tv`, `movies` and `anime` in SABnzbd. Profilarr manages quality and custom
format definitions across Sonarr and Radarr so they do not drift apart.

---

## Monitoring and observability

Prometheus scrapes itself, node-exporter for host OS metrics, cAdvisor for
per-container resource use, and graphite-exporter. Grafana reads from Prometheus
and from Loki. Promtail discovers containers through the Docker socket
(`docker_sd_configs`) and labels logs by container name, so new services appear
in Grafana without configuration.

Prometheus config is at
[prometheus/config/prometheus.yml](prometheus/config/prometheus.yml) and
hot-reloads without a restart:

```bash
curl -X POST http://<nas-lan-ip>:9090/-/reload
```

Uptime Kuma does availability checks and pushes alerts to a self-hosted **ntfy**
server. Monitors are not configured by hand: **autokuma** reads `kuma.*` labels
off each container's compose file and creates them, which is why service compose
files carry label blocks that look like documentation but are functional.
healthchecks.io sits outside the house as a dead man's switch for the case where
the NAS itself is down and none of the above can report anything.

Scrutiny reads drive S.M.A.R.T. data and runs privileged because it needs raw
block-device access. Dozzle gives a live log view without going through Grafana.
Jellystat holds Jellyfin playback statistics and bundles **its own Postgres**.

### The graphite-exporter dead end

Worth recording so it is not re-attempted. TrueNAS Scale can export metrics in
Graphite format, so graphite-exporter was deployed to bridge them into
Prometheus, with a mapping config stripping the `scale.truenas.` prefix. It
works, and community dashboard **19661 still does not**, because TrueNAS emits
netdata-shaped metric names that do not match that dashboard's queries. Dashboard
1860 (Node Exporter Full) works out of the box from node-exporter alone, and the
TrueNAS-specific panels that were wanted now live in a hand-built dashboard at
[grafana/dashboards/truenas.json](grafana/dashboards/truenas.json).

### Tracearr, and why its stream map needs help

Tracearr monitors Jellyfin sessions. Two things about it are non-obvious:

- It uses **Docker named volumes rather than bind mounts**, because the
  supervised image bundles PostgreSQL and Redis internally and does not tolerate
  bind-mounted data directories. This is the one service that breaks the
  repo-wide bind-mount convention.
- Because it sits behind Caddy it needs `TRUST_PROXY=true`, and for its stream
  map to geolocate anything, **Jellyfin must list the Docker gateway address of
  Tracearr's network under Known Proxies**. Without that, every session records
  Caddy's internal address. Even correctly configured, local streams never
  appear on the map by design, and remote streams over Tailscale show a CGNAT
  address that does not geolocate anywhere real.

---

## How a change reaches the host

```
Renovate opens a PR  ──┐
                       ├──► review + manual merge ──► push to main
you edit a compose ────┘                                   │
                                                           ▼
                                      Deploy workflow (self-hosted runner)
                                                           │
                                         copy compose into /mnt/app/<app>/
                                                           │
                                    truenas-app.py over the WebSocket API
                                       app.update → app.pull_images(redeploy)
```

The runner is a container **on the NAS itself**, connecting outbound to GitHub,
so no inbound port is needed. It has direct filesystem access to `/mnt/app`,
which is what lets the deploy step be a file copy plus an API call rather than a
remote transfer.

Secrets come from **1Password via a service account**, referenced as
`op://Homelab/<item>/<field>`. A scheduled workflow exercises those references
weekly, so a broken service-account token is discovered on a Monday morning
rather than during an outage.

**Renovate automerge is off by design.** It covers both compose image tags and
GitHub Actions versions, and every PR is read before merging – an image bump on
a live media server is not a change worth applying unattended.

### Exclusions, and why each is excluded

`caddy`, `tailscale`, `gluetun`, `immich`, `paperless`, `github-runner`,
`cadvisor` and `jellystat` are skipped by the deploy workflow. The reasons fall
into three groups: services whose restart would sever the connection the deploy
is travelling over (`tailscale`, `github-runner`), services other containers
depend on for their network namespace or ingress (`gluetun`, `caddy`), and
multi-container apps bundling their own database, where an unattended
`pull_images(redeploy: true)` risks restarting an app server against a database
mid-migration (`immich`, `paperless`, `jellystat`).

---

## How agents reach the system

There are two places an agent can run, with materially different capabilities –
the comparison table is in
[AGENTS.md § Two shells](AGENTS.md#two-shells-very-different-powers). The short
version: **code-server is a sandbox** with no `docker`, `zfs` or `midclt` and
password-gated `sudo`, so an agent there can edit this repo but cannot observe
or change the running system. An agent on the host can do all of it.

Claude Code is installed on the host under `/mnt/app/.claude-home/`, with
`~/.claude` and `~/.local` symlinked into it, because `/home` is `noexec` and
sits on a boot environment that a TrueNAS upgrade replaces. Its git identity and
SSH key are repo-local and on the NVMe for the same reason.

That SSH key is a **repository deploy key with write access**, not an account
key, so its blast radius is this repo alone.

---

## Known rough edges and open questions

- **Every `app.update` call was silently failing.**
  [truenas-app.py](scripts/truenas-app.py) passed `custom_compose_config` a
  string, where the API types that parameter as an **object** – the string form
  is a separate parameter, `custom_compose_config_string`. The call was rejected
  on every deploy, and the script printed the error without exiting, so
  `app.pull_images(redeploy: true)` was doing all the real work. Deploys
  succeeded by accident: the stored config is always the same `include:` line, so
  a redeploy picks up the freshly-copied file regardless. Now fixed, and API
  errors exit non-zero.
- **Nothing waits for the jobs it starts.** `app.update`, `app.pull_images` and
  `app.create` all return a job ID immediately. Neither the deploy workflow nor
  [new-app.sh](scripts/new-app.sh) polls it, so a green workflow means the API
  accepted the request – not that the redeploy finished. A pull that fails on a
  bad image tag still reports success. Closing this means polling
  `core.get_jobs` until the job leaves `RUNNING`.
  [truenas-app.py](scripts/truenas-app.py) now does this; `new-app.sh` still
  does not. This was also blamed for the Apps UI showing "stopped" after an
  API-driven deploy – wrongly, see below.
- **An app whose container sits in the wrong compose project is invisible to
  TrueNAS, permanently.** TrueNAS manages each app in the project `ix-<app>`;
  running `docker compose up -d` from inside `/mnt/app/<app>/` instead creates
  the project `<app>`, because Compose takes the name from the directory. The
  container runs fine and serves traffic, but TrueNAS sees an empty `ix-<app>`
  and reports the app `STOPPED` – and Start can never recover it, because the
  container name is already taken:

  ```
  Conflict. The container name "/dozzle" is already in use by container "87b9177e…"
  ```

  It is silent in the worst way: `app.pull_images(redeploy: true)` targets the
  empty project, succeeds, and changes nothing, so **image bumps stop applying
  without failing**. `dozzle` was orphaned this way on 2026-05-22 while the
  deploy workflow was being built, and sat 15 Renovate versions behind
  (`v10.6.0` against `v10.6.15`) until 2026-08-11. The deploy workflow was
  never at fault – it only copies the file and calls the API. Diagnose by
  comparing `docker ps -a --format '{{.Names}}\t{{.Label
  "com.docker.compose.project"}}'` against `app.query`: a bare project name
  where every other app carries `ix-` is the tell. Fix with `docker stop`,
  `docker rm`, `midclt call app.start <app>`, then remove the orphaned
  `<app>_default` network. `truenas-app.py` now guards against a recurrence by
  failing when an app reports zero containers after a redeploy.
- **The NVMe holding `app` occasionally fails to enumerate after a restart,**
  taking every app with it. The pool and data are intact – the drive simply did
  not come back. A **cold shutdown and power-on** fixes it; a warm restart does
  not. Diagnose with `zpool status`, `zpool import`, `lsblk`, `nvme list`.
- **`scripts/sync-repo.sh` is now redundant.** It existed to pull over HTTPS
  because the host had no SSH key; the host has one now and plain `git pull`
  works. Left in place rather than removed as a side effect.
- **`.claude/settings.local.json` is stale** – three dozen single-use command
  approvals from past sessions, including specific GitHub Actions run IDs. Dead
  weight rather than harmful.
- **UGREEN front-panel LEDs depend on a third-party kernel module** rebuilt on
  boot via a TrueNAS init script, with state on the HDD pool. The driver is
  `led-ugreen`, not UGREEN's own, so colour conventions differ from UGOS.
- **Custom app icons are set outside this repo**, by editing
  `metadata.yaml` under TrueNAS's own app config directory. Invalid YAML there
  drops the app from the UI until fixed and middleware is restarted. The exact
  procedure and its quoting trap are in HOMELAB.md.

---

## Service map

Grouped by role. Port assignments are in
[caddy/config/Caddyfile](caddy/config/Caddyfile) and HOMELAB.md rather than
duplicated here.

| Role | Services |
|---|---|
| Media serving | Jellyfin, Jellystat, Tracearr, iSponsorBlockTV |
| Media automation | Sonarr, Radarr, Prowlarr, Bazarr, Profilarr, Autobrr, Seerr, AIOStreams |
| Download clients | qBittorrent (via Gluetun), SABnzbd |
| Networking | Gluetun, Tailscale, AdGuard Home, Caddy, Nginx Proxy Manager |
| Monitoring | Prometheus, Grafana, Loki, Promtail, node-exporter, cAdvisor, graphite-exporter, Scrutiny, Dozzle, Uptime Kuma, autokuma, ntfy |
| Documents and photos | Immich, Paperless-ngx |
| Tooling | code-server, Homepage, github-runner |
