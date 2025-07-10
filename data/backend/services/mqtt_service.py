import asyncio
import json
import logging
from typing import Dict, Callable, Optional, Any
from datetime import datetime
import paho.mqtt.client as mqtt
from paho.mqtt.client import Client as MQTTClient

logger = logging.getLogger(__name__)

class MQTTService:
    def __init__(self, broker_host: str = "localhost", broker_port: int = 1883):
        self.broker_host = broker_host
        self.broker_port = broker_port
        self.client: Optional[MQTTClient] = None
        self.connected = False
        self.message_callbacks: Dict[str, Callable] = {}
        self.device_callbacks: Dict[str, Callable] = {}
        
    async def connect(self):
        """Connect to MQTT broker"""
        try:
            self.client = mqtt.Client()
            self.client.on_connect = self._on_connect
            self.client.on_disconnect = self._on_disconnect
            self.client.on_message = self._on_message
            
            # Connect to broker
            self.client.connect(self.broker_host, self.broker_port, 60)
            self.client.loop_start()
            
            # Wait for connection
            await asyncio.sleep(1)
            
            if self.connected:
                logger.info(f"Connected to MQTT broker at {self.broker_host}:{self.broker_port}")
                
                # Subscribe to device topics
                await self._subscribe_to_device_topics()
            else:
                logger.error("Failed to connect to MQTT broker")
                
        except Exception as e:
            logger.error(f"Error connecting to MQTT broker: {e}")
            raise
    
    async def disconnect(self):
        """Disconnect from MQTT broker"""
        if self.client:
            self.client.loop_stop()
            self.client.disconnect()
            self.connected = False
            logger.info("Disconnected from MQTT broker")
    
    def _on_connect(self, client, userdata, flags, rc):
        """Callback for MQTT connection"""
        if rc == 0:
            self.connected = True
            logger.info("MQTT connection established")
        else:
            self.connected = False
            logger.error(f"MQTT connection failed with code {rc}")
    
    def _on_disconnect(self, client, userdata, rc):
        """Callback for MQTT disconnection"""
        self.connected = False
        logger.info("MQTT connection lost")
    
    def _on_message(self, client, userdata, msg):
        """Callback for MQTT message"""
        try:
            topic = msg.topic
            payload = msg.payload.decode('utf-8')
            
            logger.debug(f"Received MQTT message: {topic} - {payload}")
            
            # Parse JSON payload
            try:
                data = json.loads(payload)
            except json.JSONDecodeError:
                logger.warning(f"Invalid JSON in MQTT message: {payload}")
                return
            
            # Handle message based on topic
            if topic in self.message_callbacks:
                asyncio.create_task(self.message_callbacks[topic](data))
            
            # Handle device-specific messages
            topic_parts = topic.split('/')
            if len(topic_parts) >= 2:
                device_id = topic_parts[1]
                if device_id in self.device_callbacks:
                    asyncio.create_task(self.device_callbacks[device_id](topic, data))
            
        except Exception as e:
            logger.error(f"Error processing MQTT message: {e}")
    
    async def _subscribe_to_device_topics(self):
        """Subscribe to device communication topics"""
        topics = [
            "devices/+/status",
            "devices/+/sensors",
            "devices/+/response",
            "devices/+/heartbeat",
            "system/discovery"
        ]
        
        for topic in topics:
            self.client.subscribe(topic)
            logger.info(f"Subscribed to MQTT topic: {topic}")
    
    async def publish(self, topic: str, payload: Dict[str, Any], qos: int = 0):
        """Publish message to MQTT topic"""
        if not self.connected:
            logger.error("Cannot publish - not connected to MQTT broker")
            return False
        
        try:
            json_payload = json.dumps(payload, default=str)
            self.client.publish(topic, json_payload, qos=qos)
            logger.debug(f"Published to {topic}: {json_payload}")
            return True
        except Exception as e:
            logger.error(f"Error publishing to MQTT: {e}")
            return False
    
    async def send_device_command(self, device_id: str, command: str, parameters: Dict[str, Any] = None):
        """Send command to specific device"""
        if parameters is None:
            parameters = {}
        
        topic = f"devices/{device_id}/commands"
        payload = {
            "command": command,
            "parameters": parameters,
            "timestamp": datetime.now().isoformat()
        }
        
        return await self.publish(topic, payload)
    
    def register_message_callback(self, topic: str, callback: Callable):
        """Register callback for specific topic"""
        self.message_callbacks[topic] = callback
        logger.info(f"Registered callback for topic: {topic}")
    
    def register_device_callback(self, device_id: str, callback: Callable):
        """Register callback for specific device"""
        self.device_callbacks[device_id] = callback
        logger.info(f"Registered callback for device: {device_id}")
    
    async def request_device_status(self, device_id: str):
        """Request status from specific device"""
        return await self.send_device_command(device_id, "get_status")
    
    async def broadcast_discovery(self):
        """Broadcast discovery message to find devices"""
        payload = {
            "type": "discovery",
            "timestamp": datetime.now().isoformat(),
            "server": "home-iot-server"
        }
        
        return await self.publish("system/discovery", payload) 