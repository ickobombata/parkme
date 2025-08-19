import subprocess
import sys
import os
import json

# Adjust this path to your actual mosquitto installation path
MOSQUITTO_PATH = r"C:\Program Files\mosquitto"
MOSQUITTO_PUB = os.path.join(MOSQUITTO_PATH, "mosquitto_pub.exe")
MOSQUITTO_SUB = os.path.join(MOSQUITTO_PATH, "mosquitto_sub.exe")
MOSQUITTO_EXE = os.path.join(MOSQUITTO_PATH, "mosquitto.exe")

# Path to your broker configuration file
MOSQUITTO_CONF = os.path.join(MOSQUITTO_PATH, "mosquitto.conf")

# Path to store current target ESP ID
TARGET_FILE = "mqtt_target.json"

# MQTT broker details (must match config file)
BROKER_HOST = "raspberrypi"
BROKER_PORT = "1883"

# Topics (relative, we will prepend ESP ID)
TOPICS = {
    "pump_run": "pump/run",
    "pump_get": "pump/get",
    "bucket_get": "bucket/get",
    "wifi_get": "wifi/get",
    "bucket_level": "bucket/level",
    "pump_status": "pump/status",
    "pump_error": "pump/error",
    "wifi_signal": "wifi/signal"
}


def load_target():
    """Load the currently set ESP ID from file."""
    if not os.path.exists(TARGET_FILE):
        return None
    with open(TARGET_FILE, "r") as f:
        data = json.load(f)
        return data.get("esp_id")


def save_target(esp_id):
    """Save the current ESP ID to file."""
    with open(TARGET_FILE, "w") as f:
        json.dump({"esp_id": esp_id}, f)


def require_target():
    """Ensure a target ESP is set, otherwise exit."""
    esp_id = load_target()
    if not esp_id:
        print("❌ No target ESP set. Use: python mqtt_cli.py set_target <esp_id>")
        sys.exit(1)
    return esp_id


def publish(topic, message):
    """Publish a message to a topic (auto-prepend ESP ID)."""
    esp_id = require_target()
    full_topic = f"{esp_id}/{topic}"
    cmd = [
        MOSQUITTO_PUB,
        "-h", BROKER_HOST,
        "-p", BROKER_PORT,
        "-t", full_topic,
        "-m", str(message),
	"-u", "ickobombata",
	"-P", "maceradi1"
    ]
    print(f"Publishing: topic={full_topic}, message={message}")
    subprocess.run(cmd)


def listen():
    """Subscribe to all topics of the current ESP ID."""
    esp_id = require_target()
    full_topic = f"{esp_id}/#"
    cmd = [
        MOSQUITTO_SUB,
        "-h", BROKER_HOST,
        "-p", BROKER_PORT,
        "-t", full_topic,
	"-u", "ickobombata",
	"-P", "maceradi1"
    ]
    print(f"Listening to topics under: {full_topic}")
    subprocess.run(cmd)


def start_broker():
    """Start the Mosquitto broker with config file."""
    if not os.path.exists(MOSQUITTO_CONF):
        print(f"Error: mosquitto.conf not found at {MOSQUITTO_CONF}")
        sys.exit(1)

    cmd = [
        MOSQUITTO_EXE,
        "-c", MOSQUITTO_CONF
    ]
    print(f"Starting Mosquitto broker with config: {MOSQUITTO_CONF}")
    subprocess.run(cmd)


def main():
    if len(sys.argv) < 2:
        print("Usage:")
        print("  python mqtt_cli.py start_broker")
        print("  python mqtt_cli.py set_target <esp_id>")
        print("  python mqtt_cli.py run_pump <seconds>")
        print("  python mqtt_cli.py get_pump")
        print("  python mqtt_cli.py get_bucket")
        print("  python mqtt_cli.py get_wifi")
        print("  python mqtt_cli.py listen")
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == "start_broker":
        start_broker()

    elif cmd == "set_target":
        if len(sys.argv) != 3:
            print("Usage: python mqtt_cli.py set_target <esp_id>")
            sys.exit(1)
        esp_id = sys.argv[2]
        save_target(esp_id)
        print(f"✅ Target ESP set to: {esp_id}")

    elif cmd == "run_pump":
        if len(sys.argv) != 3:
            print("Usage: python mqtt_cli.py run_pump <seconds>")
            sys.exit(1)
        seconds = sys.argv[2]
        publish(TOPICS["pump_run"], seconds)

    elif cmd == "get_pump":
        publish(TOPICS["pump_get"], "")

    elif cmd == "get_bucket":
        publish(TOPICS["bucket_get"], "")

    elif cmd == "get_wifi":
        publish(TOPICS["wifi_get"], "")

    elif cmd == "listen":
        listen()

    else:
        print(f"Unknown command: {cmd}")
        sys.exit(1)


if __name__ == "__main__":
    main()
