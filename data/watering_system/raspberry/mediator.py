#!/usr/bin/env python3
import os
import json
import time
import uuid
import threading
import signal
from typing import Any, Dict, Optional

import paho.mqtt.client as mqtt

# =========================
# Config via ENV VARS
# =========================
LOCAL_BROKER_HOST = os.getenv("LOCAL_BROKER_HOST", "raspberrypi")
LOCAL_BROKER_PORT = int(os.getenv("LOCAL_BROKER_PORT", "1883"))
LOCAL_BROKER_USER = os.getenv("LOCAL_BROKER_USER", "")
LOCAL_BROKER_PASS = os.getenv("LOCAL_BROKER_PASS", "")

VM_BROKER_HOST = os.getenv("VM_BROKER_HOST", "vm-broker-host")
VM_BROKER_PORT = int(os.getenv("VM_BROKER_PORT", "1883"))
VM_BROKER_USER = os.getenv("VM_BROKER_USER", "")
VM_BROKER_PASS = os.getenv("VM_BROKER_PASS", "")

# When VM publishes commands it uses the "devices/..." namespace.
# Set this to "devices" to match topics like: devices/<id>/bucket/get
VM_BASE_PREFIX = os.getenv("VM_BASE_PREFIX", "devices")

# Where to persist the device registry (mount /data as a volume)
REGISTRY_PATH = os.getenv("REGISTRY_PATH", "/data/devices.json")

# Seconds to wait for ESP responses over local RPC
RPC_TIMEOUT = float(os.getenv("RPC_TIMEOUT", "8"))
RPC_MAX_RETRIES = float(os.getenv("RPC_TIMEOUT", "3"))    # how many times to retry on timeout

# =========================
# Simple logger
# =========================
def log(*args):
    print("[mediator]", *args, flush=True)

# =========================
# Device Registry (persisted)
# =========================
_device_registry: Dict[str, Dict[str, Any]] = {}

def _ensure_registry_dir():
    os.makedirs(os.path.dirname(REGISTRY_PATH), exist_ok=True)

def load_registry():
    global _device_registry
    _ensure_registry_dir()
    try:
        with open(REGISTRY_PATH, "r", encoding="utf-8") as f:
            _device_registry = json.load(f)
            if not isinstance(_device_registry, dict):
                _device_registry = {}
        log(f"Loaded device registry with {len(_device_registry)} entries.")
    except FileNotFoundError:
        _device_registry = {}
        log("No existing registry found; starting fresh.")
    except Exception as e:
        _device_registry = {}
        log("Failed to load registry:", e)

def save_registry():
    _ensure_registry_dir()
    tmp_path = REGISTRY_PATH + ".tmp"
    try:
        with open(tmp_path, "w", encoding="utf-8") as f:
            json.dump(_device_registry, f, indent=2, ensure_ascii=False)
        os.replace(tmp_path, REGISTRY_PATH)
        log(f"Saved device registry ({len(_device_registry)} devices).")
    except Exception as e:
        log("Failed to save registry:", e)

# =========================
# RPC Wrapper (local broker)
# =========================
class MqttRpcClient:
    """
    Lightweight RPC over MQTT with requestId and retry support.

    - Publish request to:   <device_id>/<method_topic>
      Examples:
        deviceA/pump/run     with payload {"requestId":"...", "params":{"duration":10}}
        deviceA/bucket/get   with payload {"requestId":"..."}
    - Wait on response at:  <device_id>/<base>/response/<requestId>
      where <base> is the first segment of method_topic (e.g., "pump", "bucket")
    """
    def __init__(self,
                 host: str,
                 port: int = 1883,
                 username: str = "",
                 password: str = ""):
        self.client = mqtt.Client(client_id=f"rpc_{uuid.uuid4().hex[:8]}")
        if username or password:
            self.client.username_pw_set(username, password)
        self.client.on_message = self._on_message
        self.client.on_connect = self._on_connect
        self.client.on_disconnect = self._on_disconnect

        self.pending: Dict[str, Dict[str, Any]] = {}
        self._lock = threading.Lock()

        self.client.connect(host, port, keepalive=60)
        self.client.loop_start()
        log(f"RPC connected to local broker {host}:{port}")

    def _on_connect(self, client, userdata, flags, rc):
        log(f"[rpc] connected, rc={rc}")

    def _on_disconnect(self, client, userdata, rc):
        log(f"[rpc] disconnected, rc={rc}")

    def _on_message(self, client, userdata, msg):
        try:
            payload = json.loads(msg.payload.decode())
        except Exception:
            return
        req_id = payload.get("requestId")
        if not req_id:
            return
        with self._lock:
            entry = self.pending.get(req_id)
            if entry:
                entry["response"] = payload
                entry["event"].set()

    def call(self,
             device_id: str,
             method_topic: str,
             params: Optional[Dict[str, Any]] = None,
             timeout: float = RPC_TIMEOUT) -> Any:
        """
        Generic RPC call with retry.
        method_topic example: "bucket/get", "pump/run", "wifi/get", "pump/get", "config/name"
        """
        last_error = None
        for attempt in range(1, RPC_MAX_RETRIES + 1):
            try:
                base = method_topic.split("/", 1)[0]  # "pump" from "pump/run"
                req_id = uuid.uuid4().hex
                event = threading.Event()
                with self._lock:
                    self.pending[req_id] = {"event": event, "response": None}

                response_topic = f"{device_id}/{base}/response/{req_id}"
                request_topic  = f"{device_id}/{method_topic}"

                # subscribe to response topic for this request only
                self.client.subscribe(response_topic)

                payload = {"requestId": req_id, "params": params or {}}
                self.client.publish(request_topic, json.dumps(payload))
                log(f"[rpc] attempt {attempt}/{RPC_MAX_RETRIES} → {request_topic} {payload}")

                if event.wait(timeout):
                    with self._lock:
                        resp = self.pending.pop(req_id, None)
                    if not resp or not resp.get("response"):
                        raise TimeoutError("Response missing after event set")
                    return resp["response"].get("result")
                else:
                    raise TimeoutError(f"RPC timeout waiting for {response_topic}")

            except TimeoutError as e:
                log(f"[rpc] timeout on attempt {attempt}/{RPC_MAX_RETRIES}")
                last_error = e
                # retry if attempts left
            except Exception as e:
                log(f"[rpc] error: {e}")
                last_error = e
                break  # non-timeout error → no retry

            finally:
                with self._lock:
                    self.pending.pop(req_id, None)

        # If we got here, all retries failed
        raise last_error or TimeoutError(f"RPC failed after {RPC_MAX_RETRIES} retries")

    # Convenience helpers
    def run_pump(self, device_id: str, seconds: int) -> Any:
        return self.call(device_id, "pump/run", {"duration": seconds})

    def get_bucket_level(self, device_id: str) -> Any:
        return self.call(device_id, "bucket/get")

    def get_wifi(self, device_id: str) -> Any:
        return self.call(device_id, "wifi/get")

    def get_pump_state(self, device_id: str) -> Any:
        return self.call(device_id, "pump/get")

    def set_config_name(self, device_id: str, name: str) -> Any:
        return self.call(device_id, "config/name", {"name": name})

# =========================
# Two MQTT clients (local + VM)
# =========================
local_mqtt = None  # type: Optional[mqtt.Client]
vm_mqtt = None     # type: Optional[mqtt.Client]
rpc = None         # type: Optional[MqttRpcClient]

def build_client(client_id: str, host: str, port: int, user: str, pwd: str):
    c = mqtt.Client(client_id=client_id, clean_session=True)
    if user or pwd:
        c.username_pw_set(user, pwd)
    # Robust options
    c.reconnect_delay_set(min_delay=1, max_delay=30)
    c.max_inflight_messages_set(64)
    c.max_queued_messages_set(0)  # unlimited
    c.keepalive = 60
    c.connect(host, port, keepalive=60)
    c.loop_start()
    return c

# ---------------- Local broker message handler ----------------
def on_local_message(client, userdata, msg):
    topic = msg.topic
    payload = msg.payload  # forward as-is for status/announce
    # 1) device announces
    if topic == "devices/announce":
        try:
            data = json.loads(payload.decode())
            dev_id = data.get("id")
            if dev_id:
                _device_registry[dev_id] = data
                save_registry()
                log(f"[local] announce from {dev_id} -> forwarded to VM")
            else:
                log("[local] announce missing id, forwarding anyway")
        except Exception as e:
            log("[local] announce parse error:", e)
        # Forward upstream
        safe_publish_vm("devices/announce", payload)
        return

    # 2) status topics — forward upstream unchanged
    if topic.endswith("/bucket/status") or topic.endswith("/pump/status") or topic.endswith("/wifi/status"):
        log(f"[local] forward status {topic} -> VM")
        safe_publish_vm(topic, payload)
        return

    # 3) RPC responses (JSON) — forward upstream with VM prefix
    # Pattern: <device_id>/<base>/response/<requestId>
    # We wrap it with "devices/" prefix to keep cloud namespace consistent.
    parts = topic.split("/")
    if len(parts) >= 4 and parts[1] in ("bucket", "pump", "wifi", "config") and parts[2] == "response":
        vm_topic = f"{VM_BASE_PREFIX}/{topic}"  # e.g., devices/esp32c3_abcd/pump/response/<reqId>
        log(f"[local] forward RPC response {topic} -> {vm_topic}")
        safe_publish_vm(vm_topic, payload)

# ---------------- VM broker message handler ----------------
def on_vm_message(client, userdata, msg):
    """Receive commands from VM and execute via local RPC, then publish a response back to VM."""
    topic = msg.topic
    try:
        payload = json.loads(msg.payload.decode())
    except Exception:
        log(f"[vm] non-JSON payload on {topic}; ignoring")
        return

    req_id = payload.get("requestId", "")
    params = payload.get("params", {}) or {}
    parts = topic.split("/")

    # --- Handle devices/mediator/devices/get ---
    if topic == f"{VM_BASE_PREFIX}/mediator/devices/get":
        # Respond with all devices in the registry
        resp_topic = f"{VM_BASE_PREFIX}/mediator/devices/response/{req_id}"
        result = list(_device_registry.values())
        resp = {"requestId": req_id, "result": result}
        safe_publish_vm(resp_topic, json.dumps(resp).encode())
        log(f"[vm] Sent device registry to {resp_topic}")
        return

    # Expected command topic format:
    #   devices/<device_id>/<segment>/get
    #   devices/<device_id>/pump/run
    #   devices/<device_id>/config/name
    if len(parts) < 4 or parts[0] != VM_BASE_PREFIX:
        log(f"[vm] Unexpected topic: {topic}")
        return

    device_id = parts[1]
    method_topic = "/".join(parts[2:])  # e.g., "pump/run", "bucket/get"
    base = parts[2]                     # "pump", "bucket", ...

    # Call local RPC
    try:
        result = rpc.call(device_id, method_topic, params=params, timeout=RPC_TIMEOUT)
        resp = {"requestId": req_id, "result": result}
    except Exception as e:
        log(f"[vm] RPC error for {device_id} {method_topic}: {e}")
        resp = {"requestId": req_id, "error": str(e)}

    # Publish response back to VM broker at:
    #   devices/<device_id>/<base>/response/<requestId>
    vm_resp_topic = f"{VM_BASE_PREFIX}/{device_id}/{base}/response/{req_id or 'noid'}"
    safe_publish_vm(vm_resp_topic, json.dumps(resp).encode())

def safe_publish_vm(topic: str, payload: bytes):
    try:
        vm_mqtt.publish(topic, payload)
    except Exception as e:
        log("[vm] publish failed:", e)

# =========================
# Wiring it all together
# =========================
def main():
    global local_mqtt, vm_mqtt, rpc

    load_registry()

    # Local (ESP) broker
    local_mqtt = build_client(
        client_id=f"pi_local_{uuid.uuid4().hex[:6]}",
        host=LOCAL_BROKER_HOST, port=LOCAL_BROKER_PORT,
        user=LOCAL_BROKER_USER, pwd=LOCAL_BROKER_PASS
    )
    local_mqtt.on_message = on_local_message
    # Subscriptions for ESP-originated traffic
    local_mqtt.subscribe("devices/announce")
    local_mqtt.subscribe("+/bucket/status")
    local_mqtt.subscribe("+/pump/status")
    local_mqtt.subscribe("+/wifi/status")
    # Also catch RPC responses to forward upstream (if VM subscribed directly they’d arrive via bridge,
    # but we forward explicitly to enforce consistent VM prefix)
    local_mqtt.subscribe("+/bucket/response/+")
    local_mqtt.subscribe("+/pump/response/+")
    local_mqtt.subscribe("+/wifi/response/+")
    local_mqtt.subscribe("+/config/response/+")

    # VM (cloud) broker
    vm_mqtt = build_client(
        client_id=f"pi_vm_{uuid.uuid4().hex[:6]}",
        host=VM_BROKER_HOST, port=VM_BROKER_PORT,
        user=VM_BROKER_USER, pwd=VM_BROKER_PASS
    )
    vm_mqtt.on_message = on_vm_message
    # Commands coming from the cloud
    vm_mqtt.subscribe(f"{VM_BASE_PREFIX}/+/pump/run")
    vm_mqtt.subscribe(f"{VM_BASE_PREFIX}/+/bucket/get")
    vm_mqtt.subscribe(f"{VM_BASE_PREFIX}/+/wifi/get")
    vm_mqtt.subscribe(f"{VM_BASE_PREFIX}/+/pump/get")
    vm_mqtt.subscribe(f"{VM_BASE_PREFIX}/+/config/name")

    # Local RPC client used to talk to ESPs
    rpc = MqttRpcClient(
        host=LOCAL_BROKER_HOST,
        port=LOCAL_BROKER_PORT,
        username=LOCAL_BROKER_USER,
        password=LOCAL_BROKER_PASS
    )

    # Graceful shutdown to save registry
    def handle_sig(signum, frame):
        log(f"Signal {signum} received, saving registry and exiting.")
        save_registry()
        # keep container alive unless actually asked to stop by Docker
        os._exit(0)
    signal.signal(signal.SIGTERM, handle_sig)
    signal.signal(signal.SIGINT, handle_sig)

    log("Mediator running. Bridging local <-> VM.")
    # Run forever
    while True:
        time.sleep(1)

if __name__ == "__main__":
    main()
