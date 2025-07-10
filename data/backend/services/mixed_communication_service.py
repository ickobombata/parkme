import asyncio
import json
import logging
from typing import Dict, Callable, Optional, Any, List
from datetime import datetime
from services.config_service import config
from services.mqtt_service import MQTTService
from services.serial_service import SerialService
from services.dummy_service import DummyService

logger = logging.getLogger(__name__)

class MixedCommunicationService:
    """
    Communication service that supports both MQTT and Serial devices
    Each device can be configured for either communication method
    """
    
    def __init__(self):
        self.mqtt_service: Optional[MQTTService] = None
        self.serial_connections: Dict[str, SerialService] = {}
        self.dummy_service: Optional[DummyService] = None
        self.device_configs: Dict[str, Dict[str, Any]] = {}
        self.message_callbacks: Dict[str, Callable] = {}
        self.device_callbacks: Dict[str, Callable] = {}
        self.connected_devices: Dict[str, str] = {}  # device_id -> communication_type
        
    async def initialize(self):
        """Initialize communication services based on device configurations"""
        try:
            # Load device configurations
            device_configs = config.get('devices', [])
            
            # Separate devices by communication type
            mqtt_devices = []
            serial_devices = []
            dummy_devices = []
            
            for device_config in device_configs:
                device_id = device_config.get('id')
                comm_type = device_config.get('communication', 'mqtt')
                
                if not device_id:
                    logger.warning("Device configuration missing ID, skipping")
                    continue
                    
                self.device_configs[device_id] = device_config
                
                if comm_type == 'mqtt':
                    mqtt_devices.append(device_config)
                elif comm_type == 'serial':
                    serial_devices.append(device_config)
                elif comm_type == 'dummy':
                    dummy_devices.append(device_config)
                else:
                    logger.warning(f"Unknown communication type '{comm_type}' for device {device_id}")
            
            # Initialize MQTT service if needed
            if mqtt_devices:
                await self._initialize_mqtt_service(mqtt_devices)
            
            # Initialize Serial services if needed
            if serial_devices:
                await self._initialize_serial_services(serial_devices)
                
            # Initialize Dummy service if needed
            if dummy_devices:
                await self._initialize_dummy_service(dummy_devices)
                
            logger.info(f"Mixed communication service initialized with {len(mqtt_devices)} MQTT, {len(serial_devices)} serial, and {len(dummy_devices)} dummy devices")
            
        except Exception as e:
            logger.error(f"Error initializing mixed communication service: {e}")
            raise
    
    async def _initialize_mqtt_service(self, mqtt_devices: List[Dict[str, Any]]):
        """Initialize MQTT service for WiFi devices"""
        try:
            mqtt_config = config.get_mqtt_config()
            self.mqtt_service = MQTTService(
                broker_host=mqtt_config.get('broker_host', 'localhost'),
                broker_port=mqtt_config.get('broker_port', 1883)
            )
            
            # Set up message routing for MQTT
            self.mqtt_service.register_message_callback("devices/+/status", self._handle_mqtt_message)
            self.mqtt_service.register_message_callback("devices/+/sensors", self._handle_mqtt_message)
            self.mqtt_service.register_message_callback("devices/+/response", self._handle_mqtt_message)
            self.mqtt_service.register_message_callback("devices/+/heartbeat", self._handle_mqtt_message)
            self.mqtt_service.register_message_callback("system/discovery", self._handle_mqtt_message)
            
            await self.mqtt_service.connect()
            
            # Mark MQTT devices as connected
            for device in mqtt_devices:
                device_id = device.get('id')
                if device_id:
                    self.connected_devices[device_id] = 'mqtt'
                    logger.info(f"MQTT device registered: {device_id}")
                    
        except Exception as e:
            logger.error(f"Error initializing MQTT service: {e}")
            raise
    
    async def _initialize_serial_services(self, serial_devices: List[Dict[str, Any]]):
        """Initialize Serial services for USB-connected devices"""
        try:
            for device_config in serial_devices:
                device_id = device_config.get('id')
                device_name = device_config.get('name', device_id or 'unknown')
                
                if not device_id:
                    logger.warning("Serial device configuration missing ID, skipping")
                    continue
                
                # Create custom serial service for this device
                serial_service = SerialService()
                
                # Override serial config for this specific device
                config_data = device_config.get('config', {})
                if config_data:
                    serial_service.serial_config = config_data
                
                # Set up message routing for this serial device
                serial_service.register_message_callback(f"devices/{device_id}/status", self._handle_serial_message)
                serial_service.register_message_callback(f"devices/{device_id}/sensors", self._handle_serial_message)
                serial_service.register_message_callback(f"devices/{device_id}/response", self._handle_serial_message)
                serial_service.register_message_callback(f"devices/{device_id}/heartbeat", self._handle_serial_message)
                
                try:
                    await serial_service.connect()
                    self.serial_connections[device_id] = serial_service
                    self.connected_devices[device_id] = 'serial'
                    logger.info(f"Serial device connected: {device_name} on {config_data.get('port', 'unknown')}")
                    
                except Exception as e:
                    logger.error(f"Failed to connect to serial device {device_name}: {e}")
                    continue
                    
        except Exception as e:
            logger.error(f"Error initializing serial services: {e}")
            raise
    
    async def _initialize_dummy_service(self, dummy_devices: List[Dict[str, Any]]):
        """Initialize Dummy service for testing without hardware"""
        try:
            from models.device import Device, DeviceType, DeviceStatus
            
            # Create device objects for dummy service
            devices = []
            for device_config in dummy_devices:
                device_id = device_config.get('id')
                device_name = device_config.get('name', device_id or 'unknown')
                
                if not device_id:
                    logger.warning("Dummy device configuration missing ID, skipping")
                    continue
                
                # Create device object
                device = Device(
                    id=device_id,
                    name=device_name,
                    device_type=DeviceType.CONTROLLER,
                    status=DeviceStatus.ONLINE,
                    location=device_config.get('location', 'Test Environment'),
                    description=device_config.get('description', 'Dummy device'),
                    capabilities=device_config.get('capabilities', []),
                    config=device_config.get('config', {}),
                    is_active=True
                )
                devices.append(device)
                
                # Mark dummy device as connected
                self.connected_devices[device_id] = 'dummy'
                logger.info(f"Dummy device registered: {device_name}")
            
            # Initialize dummy service
            self.dummy_service = DummyService()
            await self.dummy_service.initialize(devices)
            
        except Exception as e:
            logger.error(f"Error initializing dummy service: {e}")
            raise
    
    async def _handle_mqtt_message(self, data: Dict[str, Any]):
        """Handle MQTT message and route to appropriate callback"""
        try:
            # Extract topic from message context if available
            topic = data.get('_topic', '')
            
            # Route to registered callbacks
            if topic in self.message_callbacks:
                await self.message_callbacks[topic](data)
            
            # Route to device callbacks
            topic_parts = topic.split('/')
            if len(topic_parts) >= 2:
                device_id = topic_parts[1]
                if device_id in self.device_callbacks:
                    await self.device_callbacks[device_id](topic, data)
                    
        except Exception as e:
            logger.error(f"Error handling MQTT message: {e}")
    
    async def _handle_serial_message(self, data: Dict[str, Any]):
        """Handle Serial message and route to appropriate callback"""
        try:
            device_id = data.get('device_id', 'unknown')
            message_type = data.get('type', 'unknown')
            
            # Create topic-like structure for consistency
            topic = f"devices/{device_id}/{message_type}"
            
            # Route to registered callbacks
            generic_topic = f"devices/+/{message_type}"
            if generic_topic in self.message_callbacks:
                await self.message_callbacks[generic_topic](data)
            
            # Route to device callbacks
            if device_id in self.device_callbacks:
                await self.device_callbacks[device_id](topic, data)
                
        except Exception as e:
            logger.error(f"Error handling serial message: {e}")
    
    async def disconnect(self):
        """Disconnect all communication services"""
        try:
            # Disconnect MQTT service
            if self.mqtt_service:
                await self.mqtt_service.disconnect()
                
            # Disconnect all serial services
            for device_id, serial_service in self.serial_connections.items():
                await serial_service.disconnect()
                
            # Disconnect dummy service
            if self.dummy_service:
                await self.dummy_service.close()
                
            logger.info("Mixed communication service disconnected")
            
        except Exception as e:
            logger.error(f"Error disconnecting mixed communication service: {e}")
    
    async def send_device_command(self, device_id: str, command: str, parameters: Optional[Dict[str, Any]] = None) -> bool:
        """Send command to device using appropriate communication method"""
        if parameters is None:
            parameters = {}
        
        try:
            communication_type = self.connected_devices.get(device_id)
            
            if communication_type == 'dummy':
                if self.dummy_service:
                    response = await self.dummy_service.send_command(device_id, command, parameters)
                    return response.get('success', False)
                else:
                    logger.error(f"Dummy service not initialized for device {device_id}")
                    return False
            
            elif communication_type == 'mqtt':
                if self.mqtt_service:
                    return await self.mqtt_service.send_device_command(device_id, command, parameters)
                else:
                    logger.error(f"MQTT service not available for device {device_id}")
                    return False
                    
            elif communication_type == 'serial':
                if device_id in self.serial_connections:
                    return await self.serial_connections[device_id].send_device_command(device_id, command, parameters)
                else:
                    logger.error(f"Serial connection not available for device {device_id}")
                    return False
                    
            else:
                logger.error(f"Unknown communication type for device {device_id}")
                return False
                
        except Exception as e:
            logger.error(f"Error sending command to device {device_id}: {e}")
            return False
    
    def register_message_callback(self, topic: str, callback: Callable):
        """Register callback for message topic"""
        self.message_callbacks[topic] = callback
        logger.info(f"Registered callback for topic: {topic}")
    
    def register_device_callback(self, device_id: str, callback: Callable):
        """Register callback for specific device"""
        self.device_callbacks[device_id] = callback
        logger.info(f"Registered callback for device: {device_id}")
    
    async def request_device_status(self, device_id: str) -> bool:
        """Request status from specific device"""
        return await self.send_device_command(device_id, "get_status")
    
    async def broadcast_discovery(self):
        """Broadcast discovery message to all connected devices"""
        try:
            success_count = 0
            
            # Send discovery via MQTT
            if self.mqtt_service:
                if await self.mqtt_service.broadcast_discovery():
                    success_count += 1
            
            # Send discovery via Serial to each connected device
            for device_id, serial_service in self.serial_connections.items():
                if await serial_service.broadcast_discovery():
                    success_count += 1
            
            logger.info(f"Discovery broadcast sent to {success_count} communication channels")
            return success_count > 0
            
        except Exception as e:
            logger.error(f"Error broadcasting discovery: {e}")
            return False
    
    async def publish(self, topic: str, payload: Dict[str, Any], qos: int = 0) -> bool:
        """Publish message to appropriate communication channel"""
        try:
            # Extract device ID from topic
            topic_parts = topic.split('/')
            if len(topic_parts) >= 2:
                device_id = topic_parts[1]
                communication_type = self.connected_devices.get(device_id)
                
                if communication_type == 'mqtt' and self.mqtt_service:
                    return await self.mqtt_service.publish(topic, payload, qos)
                elif communication_type == 'serial' and device_id in self.serial_connections:
                    return await self.serial_connections[device_id].publish(topic, payload, qos)
            
            logger.warning(f"Could not route message to topic: {topic}")
            return False
            
        except Exception as e:
            logger.error(f"Error publishing message: {e}")
            return False
    
    def get_device_configs(self) -> Dict[str, Dict[str, Any]]:
        """Get all device configurations"""
        return self.device_configs
    
    def get_connected_devices(self) -> Dict[str, str]:
        """Get all connected devices and their communication types"""
        return self.connected_devices
    
    def is_device_connected(self, device_id: str) -> bool:
        """Check if device is connected"""
        return device_id in self.connected_devices
    
    def get_device_communication_type(self, device_id: str) -> Optional[str]:
        """Get communication type for specific device"""
        return self.connected_devices.get(device_id)
    
    def is_connected(self) -> bool:
        """Check if any communication channel is connected"""
        mqtt_connected = self.mqtt_service and self.mqtt_service.connected if self.mqtt_service else False
        serial_connected = any(
            service.is_connected() for service in self.serial_connections.values()
        )
        dummy_connected = self.dummy_service and self.dummy_service.running if self.dummy_service else False
        return mqtt_connected or serial_connected or dummy_connected 