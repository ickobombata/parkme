import paho.mqtt.client as mqtt
import uuid
import json
import threading

class MqttRpcClient:
    def __init__(self, broker="localhost", base_prefix=""):
        self.client = mqtt.Client()
        self.client.on_message = self._on_message
        self.client.connect(broker)
        self.client.loop_start()

        self.pending = {}
        self.base_prefix = base_prefix.rstrip("/")

    def _on_message(self, client, userdata, msg):
        try:
            payload = json.loads(msg.payload.decode())
            req_id = payload.get("requestId")
            if req_id in self.pending:
                self.pending[req_id]["response"] = payload
                self.pending[req_id]["event"].set()
        except Exception as e:
            print("Error in on_message:", e)

    def call(self, device_id, method, params=None, timeout=5):
        """
        Make an RPC call to a device.
        """
        req_id = str(uuid.uuid4())
        event = threading.Event()
        self.pending[req_id] = {"event": event, "response": None}

        response_topic = f"{self.base_prefix}/{device_id}/{method}/response/{req_id}"
        self.client.subscribe(response_topic)

        request_topic = f"{self.base_prefix}/{device_id}/{method}/get"
        payload = {"requestId": req_id, "params": params or {}}
        self.client.publish(request_topic, json.dumps(payload))

        if event.wait(timeout):
            resp = self.pending[req_id]["response"]
            del self.pending[req_id]
            return resp.get("result")
        else:
            del self.pending[req_id]
            raise TimeoutError(f"No response from {device_id} for {method}")

    def __getattr__(self, name):
        """
        Dynamically expose RPC methods as Python functions.
        Example:
            rpc.getBucketLevel("esp32")  -> calls device 'esp32', method 'bucket'
        """
        def method(device_id, params=None, timeout=5):
            return self.call(device_id, name, params=params, timeout=timeout)
        return method
