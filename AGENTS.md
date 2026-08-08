# AGENTS.md

Instructions for AI coding agents working in this repository. The human
overview lives in [README.md](README.md); this file is the agent entry point.

**Read this file, then load only the docs your task needs** – the
[doc map](#doc-map) at the bottom says which is which. In particular,
[ARCHITECTURE.md](ARCHITECTURE.md) holds the design decisions and the TrueNAS,
ZFS and Gluetun specifics that will otherwise cost you an afternoon; read the
section your task touches before touching it.

Environment specifics – IP addresses, the real domain, port assignments,
credential locations, host quirks – live in **HOMELAB.md**, which is gitignored
and not in this repo. If you have it in context, prefer it for concrete values.

---

## What this project is – and what it is not

The configuration for a **single-node home server**: a UGREEN DXP4800 Pro
running TrueNAS Scale, hosting around forty Docker services deployed as TrueNAS
Custom Apps. Media serving, photo backup, an automated media pipeline, a
monitoring stack, and a reverse proxy reachable only over Tailscale.

| | |
|---|---|
| **It is** | A live system in daily use – a real media library on real disks, live VPN and API credentials, a household depending on it. The compose files are the source of truth; the running containers are not a fixture you can freely recreate. |
| **It is not** | An application codebase. There is no build, no test suite, no local development environment, and no staging. It is also not a portable compose repo – paths are absolute and specific to this host, and deployment goes through TrueNAS rather than `docker compose up`. |

---

## Running it – there is no local anything

**You cannot run this stack anywhere but the machine itself.** There is no dev
environment to reproduce it in, and no staging to try a change against. A change
is either correct or it is broken in production.

### Two shells, very different powers

This is the single most important thing to establish before you start work,
because half of what you might try to run is unavailable in one of them.

| | code-server container | TrueNAS host |
|---|---|---|
| Reached via | the code-server web UI | SSH, or the TrueNAS UI shell |
| User | `abc` (uid 950, maps to `truenas_admin`) | `truenas_admin` |
| `/mnt/app` | bind-mounted, read-write | native |
| `docker` | **absent** | yes, via `sudo` |
| `zfs` / `zpool` | **absent** | yes |
| `midclt` | **absent** | yes, via `sudo` |
| `sudo` | prompts for a password | passwordless |
| git push | works (key is under `/mnt/app`) | works |

**Check which one you are in before planning any command sequence:**

```bash
hostname; ls /.dockerenv 2>/dev/null && echo "in container"; which docker zfs midclt
```

If you are in the container and the task needs Docker, ZFS or the TrueNAS API,
say so and hand the commands over rather than guessing at their output. Do not
report a container-side check as if it reflected the host.

### Inspecting the running system (host only)

```bash
sudo docker ps --format '{{.Names}}\t{{.Status}}'
sudo docker logs <container> --tail 100
sudo docker inspect <container>
zfs list -r app storage
zpool status
sudo midclt call app.query '[["name","=","<app>"]]'
```

### Deploying a change

The normal path is **git, not the UI**:

1. Edit `<app>/docker-compose.yml`.
2. Commit and push to `main`.
3. The [Deploy workflow](.github/workflows/deploy.yml) fires on any changed
   `**/docker-compose.yml`, copies it into `/mnt/app/<app>/`, and calls
   `app.update` then `app.pull_images(redeploy: true)` through the TrueNAS
   WebSocket API via [truenas-app.py](scripts/truenas-app.py).

**Several apps are excluded from that workflow** and must be redeployed by hand
from the TrueNAS Apps UI: `caddy`, `tailscale`, `gluetun`, `immich`,
`paperless`, `github-runner`, `cadvisor`, `jellystat`. Pushing a compose change
for one of those looks successful and does nothing. The exclusion list lives in
[deploy.yml](.github/workflows/deploy.yml) – check it before promising a deploy.

Creating a **new** app no longer needs the Apps UI.
[scripts/new-app.sh](scripts/new-app.sh) is a two-pass script: run it once to
create the dataset and scaffold `docker-compose.yml`, `.env` and `.env.example`;
fill in the compose file; run it again to register the app via
`midclt call app.create`. It skips apps that already exist, so re-running is
safe.

### Six things that will catch you out

1. **`/home` is `noexec` and lives on `boot-pool`.** Binaries there will not
   execute, and a TrueNAS upgrade replaces the whole boot environment. Anything
   that must persist belongs on a pool under `/mnt/`.
2. **After an API-driven redeploy, the TrueNAS Apps UI may show the app as
   "stopped" while the container runs fine.** Trust `sudo docker ps`, not the
   UI. To reconcile: `sudo docker stop`/`rm` the container, then
   `sudo midclt call app.start <app>`.
3. **`qbittorrent` has no network namespace of its own.** It uses
   `network_mode: "container:gluetun"`, so its port is published on the Gluetun
   container and adding a `ports:` block to it will fail to start. Prowlarr used
   to work this way and no longer does – it publishes `9696` directly.
4. **code-server pins ZFS datasets in its mount namespace.** `zfs destroy`
   under `/mnt/app` can fail "busy" with nothing visible in `mount` or `lsof`.
   The authoritative check is `sudo grep -l "<path>" /proc/*/mounts`; the
   TrueNAS UI's "processes using dataset" warning gives false positives.
5. **The Validate workflow synthesises `.env` from `.env.example`.** Any
   `${VAR}` you reference in a compose file must also exist in that app's
   `.env.example`, or [validate.yml](.github/workflows/validate.yml) fails on
   the PR – even though the real `.env` on the host has it.
6. **Renovate automerge is deliberately off.** Every dependency PR is reviewed
   and merged by hand. Do not enable automerge to "unblock" anything.

---

## Hard rules

- **Never commit a `.env`.** They hold live VPN, API and database credentials
  and are gitignored. `.env.example` is the redacted template and is committed.
  Check keys are set by testing for presence, never by printing values.
- **Environment variables go in `env_file: .env`,** not inline `environment:`
  blocks. The exception is `PUID`/`PGID` defaulting, which some files set
  inline with `${PUID:-950}`.
- **LinuxServer.io containers use `PUID=950 PGID=950`.** Seerr uses uid 1000.
  Getting this wrong produces permission errors that look like path problems.
- **Do not split `storage/mediadata` into separate datasets.** `media/` and
  `data/` are plain directories inside one dataset so that hardlinks work
  between downloads and the library. Splitting them silently doubles disk use
  and breaks instant imports – see
  [ARCHITECTURE.md § Storage](ARCHITECTURE.md#storage-and-the-hardlink-constraint).
- **Do not remove `group_add: "107"` or `/dev/dri` from Jellyfin.** That is the
  `render` group on this host and it is what makes hardware transcoding work.
  The GID is host-specific; verify with `getent group render` before assuming
  it transfers.
- **Do not add write calls or new privileges to reach a diagnosis.** Reading
  container state, logs and ZFS properties is enough for almost everything.
- **Runtime state directories are gitignored on purpose.** Every `*/config/`,
  `*/data/`, database and log path is excluded. Do not add them, and do not
  edit files inside them expecting the change to be tracked.
- **The TrueNAS UI is on ports 81 and 444,** not 80 and 443 – those were freed
  for Caddy. Do not "fix" a health check that points at 81.
- **If you change a device, dataset or container to test something, revert it
  and say so.** Never leave an experiment running.

---

## Checks that run in CI

There is no test suite. Four workflows stand in for one, and all of them are
cheap to reason about:

| Workflow | Trigger | What it catches |
|---|---|---|
| [gitleaks.yml](.github/workflows/gitleaks.yml) | every push and PR | committed secrets, full history |
| [lint.yml](.github/workflows/lint.yml) | every push and PR | YAML syntax, `relaxed` ruleset, 200-char lines |
| [validate.yml](.github/workflows/validate.yml) | PRs touching compose or `.env.example` | `docker compose config` across every app |
| [secrets.yml](.github/workflows/secrets.yml) | Mondays 09:00 | 1Password service-account access still works |

Before calling a compose change done, run the same validation locally:

```bash
docker compose -f <app>/docker-compose.yml config --quiet
```

---

## Writing for this repo

- **British English.** "organisation", "colour", "prioritise".
- **Conventional Commits**, with the type table in [CLAUDE.md](CLAUDE.md).
  `ops` is the right type for most changes here – infrastructure, deployment,
  monitoring – with `build` for image version bumps.
- **Comments in compose files and dotfiles are short or absent.** No block
  banners, no paragraph explanations. If a line needs justifying, the reason
  belongs in [ARCHITECTURE.md](ARCHITECTURE.md), not beside it.
- **Match the surrounding compose style**: absolute host paths, pinned image
  tags, `restart: unless-stopped`, `container_name` matching the directory.
- **Never invent a port, path or GID.** Read the compose file or HOMELAB.md.
  A plausible-looking wrong port is worse than admitting you did not check.

---

## Doc map

| Document | Read it when |
|---|---|
| [CLAUDE.md](CLAUDE.md) | You are Claude Code – commits, tool use, and how to work here. Loads automatically. |
| [ARCHITECTURE.md](ARCHITECTURE.md) | You are touching a subsystem and need the service map, the design decisions and their reasoning, or the TrueNAS / ZFS / Gluetun specifics. Describes what exists, not a plan. |
| [README.md](README.md) | You want the short human overview of what runs here. |
| HOMELAB.md | You need concrete values – IPs, ports, the real domain, credential locations, host caveats. Gitignored, not in this repo. |
| `<app>/.env.example` | You need to know what configuration an app takes. |

## Keeping the docs in sync

The docs describe what exists, so a change that makes them stale is not done
yet. When behaviour, commands or design decisions change, update the file that
records them – and for [README.md](README.md), [ARCHITECTURE.md](ARCHITECTURE.md)
and this file, **ask first**, listing the specific edits you would make, rather
than editing silently.

Two things in particular go stale quietly: the deploy workflow's exclusion list,
and the port assignments. Both are copied into prose in more than one place.
