#run locally
pip install -r requirements.txt
uvicorn vm_api:app --host 0.0.0.0 --port 8000

Example usage
Start the API
python3 -m uvicorn vm_api:app --reload --host 0.0.0.0 --port 8000

Call endpoints
curl -X POST http://localhost:8000/pump/esp32c3_ab12/run/10
curl http://localhost:8000/bucket/esp32c3_ab12/status
curl http://localhost:8000/wifi/esp32c3_ab12/status

These will send MQTT messages to the global broker.
Later, when you add auth (username/password), you just set:

mqtt_client.username_pw_set("user", "pass")

Build and Run
1. Build the image
docker build -t vm_api .

2. Run the container
docker run -d \
  --name vm_api \
  -p 8000:8000 \
  vm_api


This exposes port 8000 on your VM to the public internet.
(You may need to open the port in your firewall / cloud provider security group.)