import asyncio
import json
import uuid
from typing import Dict, Any

import paho.mqtt.client as mqtt
from fastapi import FastAPI, HTTPException

# ---------------- CONFIG ----------------
MQTT_BROKER = "127.0.0.1"  # Use local machine IP for MQTT broker
MQTT_PORT = 1883
MQTT_KEEPALIVE = 60
RPC_TIMEOUT = 8

# ---------------- FASTAPI APP ----------------
app = FastAPI(title="IoT Control API")

# ---------------- MQTT RPC CLIENT ----------------
class AsyncMqttRpcClient:
    def __init__(self, broker: str, port: int = 1883, keepalive: int = 60):
        self.client = mqtt.Client()
        self.client.on_message = self._on_message
        self.client.on_connect = self._on_connect
        self.client.connect_async(broker, port, keepalive=keepalive)

        # Futures waiting for responses
        self.pending: Dict[str, asyncio.Future] = {}

        # Run network loop in background thread
        self.client.loop_start()

    def _on_connect(self, client, userdata, flags, rc):
        print(f"✅ Connected to MQTT broker rc={rc}")

    def _on_message(self, client, userdata, msg):
        try:
            payload = json.loads(msg.payload.decode())
            req_id = payload.get("requestId")
        except Exception:
            return

        if req_id and req_id in self.pending:
            fut = self.pending.pop(req_id)
            if not fut.done():
                fut.set_result(payload)

    async def call(self, device_id: str, method: str, params: Dict[str, Any] = None, timeout: int = RPC_TIMEOUT):
        req_id = uuid.uuid4().hex
        fut = asyncio.get_event_loop().create_future()
        self.pending[req_id] = fut

        # Subscribe to this response topic
        base = method.split("/", 1)[0]
        resp_topic = f"devices/{device_id}/{base}/response/{req_id}"
        self.client.subscribe(resp_topic)

        # Publish request
        topic = f"devices/{device_id}/{method}"
        payload = {"requestId": req_id, "params": params or {}}
        self.client.publish(topic, json.dumps(payload))
        print(f"[rpc] → {topic} {payload}")

        try:
            response = await asyncio.wait_for(fut, timeout)
            return response.get("result")
        except asyncio.TimeoutError:
            self.pending.pop(req_id, None)
            raise HTTPException(status_code=504, detail=f"Timeout waiting for {method} on {device_id}")

# ---------------- INITIALIZE CLIENT ----------------
rpc = AsyncMqttRpcClient(MQTT_BROKER, MQTT_PORT, MQTT_KEEPALIVE)

# ---------------- ROUTES ----------------
@app.get("/")
def root():
    return {"status": "ok", "message": "IoT API is running"}

@app.post("/pump/{device_id}/run/{seconds}")
async def run_pump(device_id: str, seconds: int):
    result = await rpc.call(device_id, "pump/run", {"duration": seconds})
    return {"device": device_id, "result": result}

@app.get("/bucket/{device_id}/status")
async def get_bucket_status(device_id: str):
    result = await rpc.call(device_id, "bucket/get")
    return {"device": device_id, "bucket": result}

@app.get("/wifi/{device_id}/status")
async def get_wifi_status(device_id: str):
    result = await rpc.call(device_id, "wifi/get")
    return {"device": device_id, "wifi": result}

@app.get("/devices")
async def get_all_devices():
    result = await rpc.call("mediator", "devices/get")
    return {"devices": result}
