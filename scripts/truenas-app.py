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

async def run():
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE

    compose_path = f"/mnt/app/{APP}/docker-compose.yml"
    with open(compose_path) as f:
        compose_content = f.read()

    uri = f"wss://{HOST}:444/api/current"
    async with websockets.connect(uri, ssl=ctx) as ws:
        await ws.send(json.dumps({"id": 1, "jsonrpc": "2.0", "method": "auth.login_with_api_key", "params": [API_KEY]}))
        resp = json.loads(await ws.recv())
        if not resp.get("result"):
            print(f"Auth failed: {resp}")
            sys.exit(1)

        payload = {
            "custom_compose_config": f"include:\n  - {compose_path}",
        }
        await ws.send(json.dumps({"id": 2, "jsonrpc": "2.0", "method": "app.update", "params": [APP, payload]}))
        resp = json.loads(await ws.recv())
        print(f"app.update({APP}): {resp.get('result', resp.get('error'))}")

        await asyncio.sleep(5)

        await ws.send(json.dumps({"id": 3, "jsonrpc": "2.0", "method": "app.redeploy", "params": [APP]}))
        resp = json.loads(await ws.recv())
        print(f"app.redeploy({APP}): {resp.get('result', resp.get('error'))}")

asyncio.run(run())
