import argparse
import requests
import os
import json

BASE_URL = "http://<VM_PUBLIC_IP>:8000"  # replace with your VM public IP or DNS
CONFIG_FILE = os.path.expanduser("~/.vm_cli_config.json")

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

    args = parser.parse_args()

    if args.command == "setTarget":
        set_target(args.device_id)
    elif args.command == "pump" and args.pump_command == "run":
        run_pump(args.seconds)
    elif args.command == "bucket" and args.bucket_command == "status":
        bucket_status()
    elif args.command == "wifi" and args.wifi_command == "status":
        wifi_status()
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
