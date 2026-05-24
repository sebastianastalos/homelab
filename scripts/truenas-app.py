#!/usr/bin/env python3
import asyncio
import json
import ssl
import sys
import os
import websockets

API_KEY = os.environ["TRUENAS_API_KEY"]
HOST = os.environ.get("TRUENAS_HOST", "192.168.1.131")
ACTION = sys.argv[1]  # start or stop
APP = sys.argv[2]

async def run():
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE

    uri = f"wss://{HOST}:444/api/current"
    async with websockets.connect(uri, ssl=ctx) as ws:
        print(f"Key length: {len(API_KEY)}, starts with: {API_KEY[:8]}")
        await ws.send(json.dumps({"id": 1, "jsonrpc": "2.0", "method": "auth.login_with_api_key", "params": [API_KEY]}))
        raw = await ws.recv()
        print(f"Auth response: {raw}")
        resp = json.loads(raw)
        if not resp.get("result"):
            print(f"Auth failed: {resp}")
            sys.exit(1)

        await ws.send(json.dumps({"id": 2, "jsonrpc": "2.0", "method": f"app.{ACTION}", "params": [APP]}))
        resp = json.loads(await ws.recv())
        print(f"app.{ACTION}({APP}): {resp.get('result', resp.get('error'))}")

asyncio.run(run())
