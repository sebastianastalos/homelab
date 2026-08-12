#!/bin/bash
# Create and deploy a new TrueNAS custom app, end to end.
#
#   scripts/new-app.sh <app>     pass 1: create dataset app/<app>, scaffold files
#   $EDITOR <app>/docker-compose.yml
#   scripts/new-app.sh <app>     pass 2: validate, register, set icon, verify
#
# Every step is idempotent - re-running after a failure picks up where it left
# off. Run as truenas_admin, NOT with sudo; sudo is used per-command inside.
set -euo pipefail

ICON_BASE="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png"
POLL_SECONDS=3
POLL_LIMIT=200      # x POLL_SECONDS = 10 min for a create/pull job
CONTAINER_WAIT=40   # x POLL_SECONDS = 2 min for a container to appear

usage() {
    cat <<'EOF'
usage: new-app.sh <appname> [--icon <url> | --no-icon]

  <appname>     lowercase letters, digits and dashes. Names the ZFS dataset
                (app/<appname>), the directory (/mnt/app/<appname>) and the
                TrueNAS app itself.
  --icon <url>  Apps UI icon. Defaults to <dashboard-icons>/png/<appname>.png
                and is skipped silently if that 404s.
  --no-icon     leave the icon alone.

Pass 1 creates the dataset, fixes ownership, and writes a commented
docker-compose.yml template plus .env and .env.example. It then stops.

Pass 2 runs once the compose file has an uncommented "services:" key:
  - docker compose config  (syntax)
  - warns on floating image tags (Renovate cannot track :latest)
  - refuses to continue if a published host port is already taken
  - midclt app.create, then waits for the job to actually finish
  - sets the Apps UI icon and restarts middlewared to load it
  - confirms the app has a running container
EOF
}

APP=""
ICON=""
NO_ICON=0

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        --icon)    ICON="${2:?--icon needs a URL}"; shift 2 ;;
        --no-icon) NO_ICON=1; shift ;;
        -*)        echo "unknown option: $1" >&2; usage >&2; exit 1 ;;
        *)         [ -z "$APP" ] || { echo "only one app name" >&2; exit 1; }
                   APP="$1"; shift ;;
    esac
done

info() { echo "==> $*"; }
warn() { echo "warning: $*" >&2; }
die()  { echo "error: $*" >&2; exit 1; }

[ -n "$APP" ] || { usage >&2; exit 1; }
[ "$EUID" -ne 0 ] || die "do not run with sudo - run as truenas_admin"
[[ "$APP" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "app name must be lowercase letters, digits and dashes"

DATASET="app/$APP"
APPDIR="/mnt/app/$APP"
COMPOSE="$APPDIR/docker-compose.yml"
[ -z "$ICON" ] && ICON="$ICON_BASE/$APP.png"

# --- helpers ----------------------------------------------------------------

compose_json() { sudo docker compose -f "$COMPOSE" config --format json; }

# Host-side published ports. Uses compose's own normalisation so that both
# "3004:3000" and bare 3003:3000 parse the same way.
compose_ports() {
    compose_json | python3 -c '
import json, sys
for svc in (json.load(sys.stdin).get("services") or {}).values():
    for p in (svc.get("ports") or []):
        pub = p.get("published")
        if pub:
            print(str(pub).split("-")[0])
'
}

compose_floating_tags() {
    compose_json | python3 -c '
import json, sys
FLOATING = {"latest", "stable", "main", "master", "edge", "nightly", "dev",
            "release", "supervised", "insiders"}
for svc in (json.load(sys.stdin).get("services") or {}).values():
    img = svc.get("image")
    if not img:
        continue
    name, _, tag = img.rsplit("@", 1)[0].rpartition(":")
    if not name or "/" in tag:
        print(img + " (no tag)")
    elif tag in FLOATING or not any(c.isdigit() for c in tag):
        print(img)
'
}

port_in_use() {
    sudo ss -tlnH 2>/dev/null | awk '{print $4}' | sed 's/.*://' | grep -qx "$1"
}

app_json() { sudo midclt call app.query "[[\"id\",\"=\",\"$APP\"]]"; }

app_registered() {
    app_json | python3 -c 'import json,sys; sys.exit(0 if json.load(sys.stdin) else 1)'
}

wait_for_job() {
    local job="$1" label="$2" i out state
    for ((i = 0; i < POLL_LIMIT; i++)); do
        out=$(sudo midclt call core.get_jobs "[[\"id\",\"=\",$job]]" | python3 -c '
import json, sys
j = json.load(sys.stdin)
print("MISSING" if not j else
      j[0]["state"] + " " + str(j[0].get("error") or "").replace("\n", " ")[:200])
')
        state=${out%% *}
        case "$state" in
            RUNNING|WAITING) sleep "$POLL_SECONDS" ;;
            SUCCESS)         info "$label: job $job SUCCESS"; return 0 ;;
            *)               die "$label: job $job -> $out" ;;
        esac
    done
    die "$label: job $job still running after $((POLL_LIMIT * POLL_SECONDS))s"
}

wait_for_containers() {
    local i state n out
    for ((i = 0; i < CONTAINER_WAIT; i++)); do
        out=$(app_json | python3 -c '
import json, sys
a = json.load(sys.stdin)
print("MISSING 0" if not a else
      a[0]["state"] + " " + str(a[0]["active_workloads"]["containers"]))
')
        state=${out%% *}; n=${out##* }
        if [ "$n" -gt 0 ]; then
            info "$APP is up: state=$state containers=$n"
            return 0
        fi
        sleep "$POLL_SECONDS"
    done
    warn "$APP registered but no container after $((CONTAINER_WAIT * POLL_SECONDS))s"
    warn "check: sudo docker ps -a | grep $APP"
    warn "       sudo tail -20 /var/log/app_lifecycle.log"
    return 1
}

# Icons live in TWO places and app.query serves the aggregate, not the per-app
# file - editing only the per-app one looks like it worked and changes nothing:
#   /mnt/.ix-apps/metadata.yaml                        aggregate, "<app>": at
#                                                      column 0, 4-space indent
#   /mnt/.ix-apps/app_configs/<app>/metadata.yaml      per-app, 2-space indent
# A bad edit to the aggregate drops EVERY app out of the Apps UI, so each file
# is backed up, edited by line insertion (never re-dumped, which would reformat
# the whole file), then verified: YAML parses, the key set is unchanged, the
# icon landed, and no other app's entry moved. Any failure restores the backup.
set_icon() {
    if ! curl -fsI --max-time 15 "$ICON" >/dev/null 2>&1; then
        warn "no icon at $ICON - skipping (use --icon <url> to set one)"
        return 0
    fi
    local status=0
    sudo env APP="$APP" ICON="$ICON" python3 - <<'PY' || status=$?
import os, shutil, sys, yaml

APP, ICON = os.environ["APP"], os.environ["ICON"]
AGG = "/mnt/.ix-apps/metadata.yaml"
PER = "/mnt/.ix-apps/app_configs/%s/metadata.yaml" % APP


def insert(path, aggregate):
    lines = open(path).readlines()
    before = yaml.safe_load(open(path))
    if aggregate:
        start = next((i for i, l in enumerate(lines)
                      if l.rstrip("\n") == '"%s":' % APP), None)
        if start is None:
            return "no %r block in %s" % (APP, path), False
        end = next((i for i in range(start + 1, len(lines))
                    if lines[i][:1] not in (" ", "\t", "\n")), len(lines))
        pad = "    "
    else:
        start, end, pad = 0, len(lines), "  "

    if any(l.startswith(pad + '"icon":') for l in lines[start:end]):
        return None, False
    anchor = next((i for i in range(start, end)
                   if lines[i].rstrip("\n") == pad + '"train": "stable"'), None)
    if anchor is None:
        return "no %r anchor in %s" % (pad + '"train": "stable"', path), False

    shutil.copy2(path, path + ".bak")
    lines.insert(anchor + 1, pad + '"icon": "%s"\n' % ICON)
    open(path, "w").writelines(lines)
    try:
        after = yaml.safe_load(open(path))
        assert set(after) == set(before), "top-level keys changed"
        node = after[APP]["metadata"] if aggregate else after["metadata"]
        assert node.get("icon") == ICON, "icon did not land"
        if aggregate:
            for k in before:
                if k != APP:
                    assert after[k] == before[k], "collateral change in %r" % k
    except Exception as exc:
        shutil.move(path + ".bak", path)
        return "verification failed on %s (%s) - restored backup" % (path, exc), False
    os.remove(path + ".bak")
    return None, True


changed = False
for path, aggregate in ((PER, False), (AGG, True)):
    if not os.path.exists(path):
        print("skipping missing %s" % path)
        continue
    err, did = insert(path, aggregate)
    if err:
        sys.exit("error: " + err)
    print("icon %s in %s" % ("added" if did else "already set", path))
    changed = changed or did

sys.exit(0 if changed else 3)
PY
    if [ "$status" -eq 3 ]; then
        info "icon already set - no middlewared restart needed"
        return 0
    elif [ "$status" -ne 0 ]; then
        warn "icon not set - app itself is unaffected"
        return 0
    fi
    info "restarting middlewared so the Apps UI reloads the icon"
    sudo systemctl restart middlewared
    local i
    for ((i = 0; i < 20; i++)); do
        sudo midclt call core.ping >/dev/null 2>&1 && return 0
        sleep "$POLL_SECONDS"
    done
    warn "middlewared has not come back after 60s"
}

# --- pass 1: dataset and scaffolding ----------------------------------------

if zfs list "$DATASET" >/dev/null 2>&1; then
    info "dataset $DATASET exists"
else
    sudo zfs create "$DATASET"
    info "created dataset $DATASET"
fi

sudo chown truenas_admin:truenas_admin "$APPDIR"
sudo chmod 755 "$APPDIR"

[ -e "$APPDIR/.env" ] || : > "$APPDIR/.env"
[ -s "$APPDIR/.env.example" ] || printf 'TZ=Europe/London\n' > "$APPDIR/.env.example"

if [ ! -e "$COMPOSE" ] || [ ! -s "$COMPOSE" ]; then
    sed "s/APPNAME/$APP/g" > "$COMPOSE" <<'EOF'
# Uncomment and fill in, then re-run: scripts/new-app.sh APPNAME
#
# Pin an exact version - Renovate cannot track :latest or other floating tags.
# LinuxServer.io images take PUID/PGID; others may not. Check the image docs.
# For the real reverse-proxy domain and port assignments see HOMELAB.md.
#
# services:
#   APPNAME:
#     image: registry/image:1.2.3
#     container_name: APPNAME
#     env_file: .env
#     environment:
#       - PUID=950
#       - PGID=950
#     volumes:
#       - /mnt/app/APPNAME/config:/config
#     ports:
#       - "8000:8000"
#     labels:
#       kuma.APPNAME.http.name: "APPNAME"
#       kuma.APPNAME.http.url: "https://APPNAME.example.com"
#     restart: unless-stopped
EOF
    info "wrote template $COMPOSE"
fi

if ! grep -qE '^services:' "$COMPOSE"; then
    cat <<EOF

Pass 1 done. Next:
  1. edit $COMPOSE (uncomment the template)
  2. add any \${VAR} you reference to $APPDIR/.env and .env.example
  3. re-run: scripts/new-app.sh $APP
EOF
    exit 0
fi

# --- pass 2: validate, register, verify -------------------------------------

info "validating $COMPOSE"
sudo docker compose -f "$COMPOSE" config --quiet || die "compose file is invalid"

FLOATING=$(compose_floating_tags || true)
if [ -n "$FLOATING" ]; then
    warn "floating image tags - Renovate will not track these:"
    echo "$FLOATING" | sed 's/^/    /' >&2
fi

if app_registered; then
    # Port checks are skipped here on purpose: this app's own container is
    # holding its ports, so re-checking would always report a false clash.
    info "app $APP already registered with TrueNAS"
else
    for p in $(compose_ports); do
        if port_in_use "$p"; then
            die "host port $p is already bound - pick another"
        fi
        CLASH=$(cd /mnt/app && git grep -lE "^[[:space:]]*-[[:space:]]*\"?$p:" -- '*/docker-compose.yml' \
                | grep -v "^$APP/" || true)
        if [ -n "$CLASH" ]; then
            die "host port $p is already claimed in: $(echo "$CLASH" | tr '\n' ' ')"
        fi
        info "port $p is free"
    done

    PAYLOAD=$(python3 -c 'import json, sys; print(json.dumps({
        "app_name": sys.argv[1],
        "custom_app": True,
        "custom_compose_config_string": "include:\n  - %s/docker-compose.yml" % sys.argv[2],
    }))' "$APP" "$APPDIR")
    info "creating app $APP"
    wait_for_job "$(sudo midclt call app.create "$PAYLOAD")" "app.create($APP)"
fi

[ "$NO_ICON" -eq 1 ] || set_icon

wait_for_containers || true

cat <<EOF

Done. Remaining manual steps, if they apply:
  - config subdirs need the container's user:  sudo chown -R 950:950 $APPDIR/<subdir>
  - reverse proxy: add a block to caddy/config/Caddyfile, then reload Caddy by
    hand (caddy is excluded from the deploy workflow)
  - commit $APP/docker-compose.yml and $APP/.env.example (never .env)
EOF
