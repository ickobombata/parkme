import asyncio
from fastapi import FastAPI
import paho.mqtt.client as mqtt

# ---------------- CONFIG ----------------
MQTT_BROKER = "raspberrypi"  # later replace with your VM's broker FQDN/IP
MQTT_PORT = 1883             # default, change if needed
MQTT_KEEPALIVE = 60

# ---------------- FASTAPI APP ----------------
app = FastAPI(title="IoT Control API")

# MQTT client (global singleton)
mqtt_client = mqtt.Client()

@app.on_event("startup")
async def startup_event():
    """Connect to MQTT broker when FastAPI starts"""
    def on_connect(client, userdata, flags, rc):
        if rc == 0:
            print("✅ Connected to MQTT broker")
        else:
            print(f"❌ Failed to connect to MQTT broker, rc={rc}")

    mqtt_client.on_connect = on_connect
    mqtt_client.connect_async(MQTT_BROKER, MQTT_PORT, MQTT_KEEPALIVE)
    mqtt_client.loop_start()


@app.on_event("shutdown")
async def shutdown_event():
    """Gracefully close MQTT connection"""
    mqtt_client.loop_stop()
    mqtt_client.disconnect()
    print("🛑 Disconnected from MQTT broker")


# ---------------- ROUTES ----------------
@app.get("/")
def root():
    return {"status": "ok", "message": "IoT API is running"}


@app.post("/pump/{device_id}/run/{seconds}")
def run_pump(device_id: str, seconds: int):
    """
    Tell a specific ESP device to run its pump for N seconds.
    Publishes to: <device_id>/pump/run
    """
    topic = f"{device_id}/pump/run"
    payload = str(seconds)
    mqtt_client.publish(topic, payload)
    return {"published": True, "topic": topic, "payload": payload}


@app.get("/bucket/{device_id}/status")
def request_bucket_status(device_id: str):
    """
    Request water level status from ESP.
    Publishes to: <device_id>/bucket/get
    """
    topic = f"{device_id}/bucket/get"
    mqtt_client.publish(topic, "")
    return {"published": True, "topic": topic}


@app.get("/wifi/{device_id}/status")
def request_wifi_status(device_id: str):
    """
    Request WiFi RSSI from ESP.
    Publishes to: <device_id}/wifi/get
    """
    topic = f"{device_id}/wifi/get"
    mqtt_client.publish(topic, "")
    return {"published": True, "topic": topic}
