#!/usr/bin/env python3
import asyncio
import json
import sys
import os
import websockets

API_KEY = os.environ["TRUENAS_API_KEY"]
HOST = os.environ.get("TRUENAS_HOST", "192.168.1.131")
ACTION = sys.argv[1]  # start or stop
APP = sys.argv[2]

async def run():
    uri = f"ws://{HOST}/api/current"
    async with websockets.connect(uri) as ws:
        await ws.send(json.dumps({"id": 1, "jsonrpc": "2.0", "method": "auth.login_with_api_key", "params": [API_KEY]}))
        resp = json.loads(await ws.recv())
        if not resp.get("result"):
            print(f"Auth failed: {resp}")
            sys.exit(1)

        await ws.send(json.dumps({"id": 2, "jsonrpc": "2.0", "method": f"app.{ACTION}", "params": [APP]}))
        resp = json.loads(await ws.recv())
        print(f"app.{ACTION}({APP}): {resp.get('result', resp.get('error'))}")

asyncio.run(run())
