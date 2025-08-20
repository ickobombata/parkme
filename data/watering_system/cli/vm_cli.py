import argparse
import requests
import os
import json
import paho.mqtt.client as mqtt

BASE_URL = "http://<VM_PUBLIC_IP>:8000"  # replace with your VM public IP or DNS
CONFIG_FILE = os.path.expanduser("~/.vm_cli_config.json")
MQTT_BROKER = "127.0.0.1"  # or your VM broker IP
MQTT_PORT = 1883

def load_config():
    if os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE, "r") as f:
            return json.load(f)
    return {}

def save_config(config):
    with open(CONFIG_FILE, "w") as f:
        json.dump(config, f)

def get_target():
    config = load_config()
    return config.get("target_device")

def set_target(device_id: str):
    config = load_config()
    config["target_device"] = device_id
    save_config(config)
    print(f"Target device set to: {device_id}")

def run_pump(seconds: int):
    target_device = get_target()
    if not target_device:
        print("No target device set. Use 'vm setTarget <device_id>' first.")
        return
    url = f"{BASE_URL}/pump/{target_device}/run/{seconds}"
    r = requests.post(url)
    print("Response:", r.json())

def bucket_status():
    target_device = get_target()
    if not target_device:
        print("No target device set. Use 'vm setTarget <device_id>' first.")
        return
    url = f"{BASE_URL}/bucket/{target_device}/status"
    r = requests.get(url)
    print("Response:", r.json())

def wifi_status():
    target_device = get_target()
    if not target_device:
        print("No target device set. Use 'vm setTarget <device_id>' first.")
        return
    url = f"{BASE_URL}/wifi/{target_device}/status"
    r = requests.get(url)
    print("Response:", r.json())

def publish_response(device_id, base, request_id, result):
    topic = f"devices/{device_id}/{base}/response/{request_id}"
    payload = {
        "requestId": request_id,
        "result": result
    }
    client = mqtt.Client()
    client.connect(MQTT_BROKER, MQTT_PORT, 60)
    client.publish(topic, json.dumps(payload))
    client.disconnect()
    print(f"Published response to {topic}: {payload}")

def main():
    parser = argparse.ArgumentParser(prog="vm", description="VM CLI to control ESP devices")
    subparsers = parser.add_subparsers(dest="command")

    # setTarget
    parser_target = subparsers.add_parser("setTarget")
    parser_target.add_argument("device_id")

    # pump run
    parser_pump = subparsers.add_parser("pump")
    pump_sub = parser_pump.add_subparsers(dest="pump_command")
    pump_run = pump_sub.add_parser("run")
    pump_run.add_argument("seconds", type=int)

    # bucket status
    parser_bucket = subparsers.add_parser("bucket")
    bucket_sub = parser_bucket.add_subparsers(dest="bucket_command")
    bucket_sub.add_parser("status")

    # wifi status
    parser_wifi = subparsers.add_parser("wifi")
    wifi_sub = parser_wifi.add_subparsers(dest="wifi_command")
    wifi_sub.add_parser("status")

    # response
    parser_response = subparsers.add_parser("response")
    parser_response.add_argument("base", choices=["pump", "bucket", "wifi", "devices"])
    parser_response.add_argument("device_id")
    parser_response.add_argument("request_id")
    parser_response.add_argument("result_json", help="JSON string for result payload")

    args = parser.parse_args()

    if args.command == "setTarget":
        set_target(args.device_id)
    elif args.command == "pump" and args.pump_command == "run":
        run_pump(args.seconds)
    elif args.command == "bucket" and args.bucket_command == "status":
        bucket_status()
    elif args.command == "wifi" and args.wifi_command == "status":
        wifi_status()
    elif args.command == "response":
        try:
            result = json.loads(args.result_json)
        except Exception:
            print("Result must be a valid JSON string.")
            return
        publish_response(args.device_id, args.base, args.request_id, result)
    else:
        parser.print_help()

if __name__ == "__main__":
    main()


# Usage examples for initiating REST requests:
# Set the target device for subsequent commands
# vm setTarget mydevice

# Run the pump for 10 seconds on the target device
# vm pump run 10

# Get the bucket status from the target device
# vm bucket status

# Get the WiFi status from the target device
# vm wifi status

# Usage examples for simulating MQTT responses:
# vm response pump mydevice 123abc '{"status":"ok"}'
# vm response bucket mydevice 456def '{"level":42}'
# vm response wifi mydevice 789ghi '{"signal":-60}'
# vm response devices mediator 101112 '[{"id":"dev1"},{"id":"dev2"}]'