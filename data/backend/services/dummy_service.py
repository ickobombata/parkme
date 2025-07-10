import asyncio
import json
import logging
import random
from datetime import datetime
from typing import Dict, Any, Optional, List
from models.device import Device, DeviceStatus, SensorReading, SensorType

logger = logging.getLogger(__name__)

class DummyService:
    """Dummy communication service for testing without hardware"""
    
    def __init__(self):
        self.devices: Dict[str, Device] = {}
        self.device_configs: Dict[str, Dict] = {}
        self.running = False
        
    async def initialize(self, devices: List[Device]):
        """Initialize dummy devices"""
        try:
            for device in devices:
                self.devices[device.id] = device
                # Store device config for simulation parameters
                device_config = device.config if device.config is not None else {}
                self.device_configs[device.id] = device_config
                logger.info(f"Initialized dummy device: {device.id} ({device.name})")
            
            self.running = True
            logger.info(f"Dummy service initialized with {len(devices)} devices")
            
        except Exception as e:
            logger.error(f"Error initializing dummy service: {e}")
            raise
    
    async def send_command(self, device_id: str, command: str, parameters: Dict[str, Any] = None) -> Dict[str, Any]:
        """Send command to dummy device (simulates response)"""
        if device_id not in self.devices:
            return {"success": False, "error": f"Device {device_id} not found"}
        
        device = self.devices[device_id]
        config = self.device_configs.get(device_id, {})
        
        # Simulate response delay
        delay = config.get('response_delay', 0.1)
        await asyncio.sleep(delay)
        
        # Simulate occasional errors if configured
        if config.get('simulate_errors', False) and random.random() < 0.1:
            return {"success": False, "error": "Simulated device error"}
        
        # Generate appropriate response based on command
        response = await self._generate_response(device, command, parameters or {})
        
        logger.info(f"Dummy device {device_id} received command '{command}': {response}")
        return response
    
    async def _generate_response(self, device: Device, command: str, parameters: Dict[str, Any]) -> Dict[str, Any]:
        """Generate realistic response based on command and device capabilities"""
        
        if command == "water_control":
            if "water_control" in device.capabilities:
                duration = parameters.get("duration", 5)
                return {
                    "success": True,
                    "action": "water_control",
                    "duration": duration,
                    "status": "completed",
                    "timestamp": datetime.now().isoformat()
                }
            else:
                return {"success": False, "error": "Water control not supported"}
        
        elif command == "read_sensors":
            readings = []
            if "temperature_reading" in device.capabilities:
                readings.append({
                    "type": "temperature",
                    "value": round(random.uniform(18.0, 28.0), 1),
                    "unit": "°C"
                })
            
            if "humidity_reading" in device.capabilities:
                readings.append({
                    "type": "humidity",
                    "value": round(random.uniform(40.0, 80.0), 1),
                    "unit": "%"
                })
            
            if "soil_moisture_reading" in device.capabilities:
                readings.append({
                    "type": "soil_moisture",
                    "value": round(random.uniform(20.0, 90.0), 1),
                    "unit": "%"
                })
            
            return {
                "success": True,
                "action": "read_sensors",
                "readings": readings,
                "timestamp": datetime.now().isoformat()
            }
        
        elif command == "status":
            return {
                "success": True,
                "action": "status",
                "status": "online",
                "uptime": random.randint(3600, 86400),
                "battery": random.randint(75, 100) if "battery" in device.capabilities else None,
                "timestamp": datetime.now().isoformat()
            }
        
        elif command == "light_control":
            if "light_control" in device.capabilities:
                state = parameters.get("state", "on")
                brightness = parameters.get("brightness", 100)
                return {
                    "success": True,
                    "action": "light_control",
                    "state": state,
                    "brightness": brightness,
                    "timestamp": datetime.now().isoformat()
                }
            else:
                return {"success": False, "error": "Light control not supported"}
        
        else:
            return {"success": False, "error": f"Unknown command: {command}"}
    
    async def get_device_status(self, device_id: str) -> DeviceStatus:
        """Get dummy device status"""
        if device_id not in self.devices:
            return DeviceStatus.OFFLINE
        
        # Simulate device being online
        return DeviceStatus.ONLINE
    
    async def start_sensor_monitoring(self, device_id: str, callback):
        """Start monitoring sensors for dummy device"""
        if device_id not in self.devices:
            logger.error(f"Device {device_id} not found for sensor monitoring")
            return
        
        device = self.devices[device_id]
        
        # Start background task to send periodic sensor readings
        asyncio.create_task(self._sensor_monitoring_loop(device, callback))
        logger.info(f"Started sensor monitoring for dummy device {device_id}")
    
    async def _sensor_monitoring_loop(self, device: Device, callback):
        """Background loop to send periodic sensor readings"""
        while self.running:
            try:
                # Generate sensor readings
                readings = []
                
                if "temperature_reading" in device.capabilities:
                    readings.append(SensorReading(
                        device_id=device.id,
                        sensor_type=SensorType.TEMPERATURE,
                        value=round(random.uniform(18.0, 28.0), 1),
                        unit="°C",
                        timestamp=datetime.now()
                    ))
                
                if "humidity_reading" in device.capabilities:
                    readings.append(SensorReading(
                        device_id=device.id,
                        sensor_type=SensorType.HUMIDITY,
                        value=round(random.uniform(40.0, 80.0), 1),
                        unit="%",
                        timestamp=datetime.now()
                    ))
                
                if "soil_moisture_reading" in device.capabilities:
                    readings.append(SensorReading(
                        device_id=device.id,
                        sensor_type=SensorType.SOIL_MOISTURE,
                        value=round(random.uniform(20.0, 90.0), 1),
                        unit="%",
                        timestamp=datetime.now()
                    ))
                
                # Send readings via callback
                for reading in readings:
                    await callback(reading)
                
                # Wait before next reading
                await asyncio.sleep(30)  # Send readings every 30 seconds
                
            except Exception as e:
                logger.error(f"Error in sensor monitoring loop for {device.id}: {e}")
                await asyncio.sleep(5)  # Wait before retrying
    
    async def close(self):
        """Close dummy service"""
        self.running = False
        logger.info("Dummy service closed") 