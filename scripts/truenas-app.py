#!/usr/bin/env python3
import asyncio
import json
import ssl
import sys
import os
import websockets

API_KEY = os.environ["TRUENAS_API_KEY"]
HOST = os.environ.get("TRUENAS_HOST", "192.168.1.131")
APP = sys.argv[1]

POLL_SECONDS = 3
POLL_LIMIT = 400  # 20 minutes; image pulls can be slow

_next_id = 0


def message_id():
    global _next_id
    _next_id += 1
    return _next_id


async def call(ws, method, params):
    await ws.send(json.dumps({"id": message_id(), "jsonrpc": "2.0", "method": method, "params": params}))
    resp = json.loads(await ws.recv())
    if "error" in resp:
        print(f"{method} failed: {resp['error']}")
        sys.exit(1)
    return resp.get("result")


async def wait_for_job(ws, job_id, label):
    for _ in range(POLL_LIMIT):
        jobs = await call(ws, "core.get_jobs", [[["id", "=", job_id]]])
        if not jobs:
            print(f"{label}: job {job_id} not found")
            sys.exit(1)
        state = jobs[0]["state"]
        if state in ("RUNNING", "WAITING"):
            await asyncio.sleep(POLL_SECONDS)
            continue
        if state != "SUCCESS":
            print(f"{label}: job {job_id} ended {state}: {jobs[0].get('error')}")
            sys.exit(1)
        print(f"{label}: job {job_id} {state}")
        return
    print(f"{label}: job {job_id} still running after {POLL_LIMIT * POLL_SECONDS}s")
    sys.exit(1)


async def run():
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE

    compose_path = f"/mnt/app/{APP}/docker-compose.yml"
    with open(compose_path) as f:
        compose_content = f.read()

    uri = f"wss://{HOST}:444/api/current"
    async with websockets.connect(uri, ssl=ctx) as ws:
        await ws.send(json.dumps({"id": message_id(), "jsonrpc": "2.0", "method": "auth.login_with_api_key", "params": [API_KEY]}))
        resp = json.loads(await ws.recv())
        if not resp.get("result"):
            print(f"Auth failed: {resp}")
            sys.exit(1)

        payload = {
            "custom_compose_config_string": f"include:\n  - {compose_path}",
        }
        job = await call(ws, "app.update", [APP, payload])
        await wait_for_job(ws, job, f"app.update({APP})")

        job = await call(ws, "app.pull_images", [APP, {"redeploy": True}])
        await wait_for_job(ws, job, f"app.pull_images({APP})")

        # A redeploy into an empty ix-<app> project succeeds while changing
        # nothing – the symptom of a container orphaned in a bare <app> project
        # by a manual `docker compose up`. Fail loudly instead.
        apps = await call(ws, "app.query", [[["id", "=", APP]]])
        if not apps:
            print(f"guard: {APP} is not a registered app")
            sys.exit(1)
        state = apps[0]["state"]
        containers = apps[0]["active_workloads"]["containers"]
        if containers == 0:
            print(
                f"guard: {APP} reports state={state} with 0 running containers after "
                f"redeploy. Check for a container in the bare '{APP}' compose project "
                f"instead of 'ix-{APP}': docker compose ls -a"
            )
            sys.exit(1)
        print(f"{APP}: state={state}, containers={containers}")

asyncio.run(run())
