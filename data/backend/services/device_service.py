import asyncio
import json
import logging
from datetime import datetime, timedelta
from typing import List, Optional, Dict, Any
from models.device import Device, DeviceStatus, SensorReading, DeviceType, SensorType
from models.log import LogEntry, LogLevel
from services.database_service import DatabaseService
from services.mqtt_service import MQTTService
from services.serial_service import SerialService
from services.mixed_communication_service import MixedCommunicationService
from typing import Union

logger = logging.getLogger(__name__)

class DeviceService:
    def __init__(self, db_service: DatabaseService, communication_service: Union[MQTTService, SerialService, MixedCommunicationService]):
        self.db_service = db_service
        self.communication_service = communication_service
        self.device_heartbeat_tasks = {}
        self.default_devices = []
        
    async def initialize(self):
        """Initialize device service"""
        try:
            # Register communication callbacks
            self.communication_service.register_message_callback(
                "devices/+/status", self._handle_device_status
            )
            self.communication_service.register_message_callback(
                "devices/+/sensors", self._handle_sensor_data
            )
            self.communication_service.register_message_callback(
                "devices/+/response", self._handle_device_response
            )
            self.communication_service.register_message_callback(
                "system/discovery", self._handle_discovery_response
            )
            
            # Initialize default devices
            await self._initialize_default_devices()
            
            # Start device monitoring
            asyncio.create_task(self._monitor_devices())
            
            # Check device status immediately on startup
            asyncio.create_task(self._initial_device_status_check())
            
            logger.info("Device service initialized successfully")
            
        except Exception as e:
            logger.error(f"Error initializing device service: {e}")
            raise
    
    async def _initialize_default_devices(self):
        """Initialize devices from configuration"""
        # Get device configurations from communication service
        device_configs = []
        
        if isinstance(self.communication_service, MixedCommunicationService):
            device_configs = list(self.communication_service.get_device_configs().values())
        else:
            # Fallback for older single-mode services
            device_configs = [
                {
                    'id': 'arduino_pump',
                    'name': 'Arduino Water Pump',
                    'device_type': 'pump',
                    'location': 'Balcony',
                    'description': 'Main watering pump for balcony plants',
                    'capabilities': ['water_control', 'status_reporting'],
                    'config': {
                        'max_water_duration': 60,
                        'default_water_duration': 5
                    }
                },
                {
                    'id': 'arduino_sensors',
                    'name': 'Arduino Sensor Array',
                    'device_type': 'sensor',
                    'location': 'Balcony',
                    'description': 'Temperature, humidity, and soil moisture sensors',
                    'capabilities': ['temperature_reading', 'humidity_reading', 'soil_moisture_reading'],
                    'config': {
                        'reading_interval': 30
                    }
                }
            ]
        
        # Convert configurations to Device objects
        for device_config in device_configs:
            device = Device(
                id=device_config.get('id', 'unknown'),
                name=device_config.get('name', 'Unknown Device'),
                device_type=DeviceType(device_config.get('device_type', 'sensor')),
                status=DeviceStatus.OFFLINE,
                location=device_config.get('location', 'Unknown'),
                description=device_config.get('description', ''),
                capabilities=device_config.get('capabilities', []),
                config=device_config.get('config', {})
            )
            
            # Add device to database
            await self.db_service.add_device(device)
            self.default_devices.append(device)
        
        logger.info(f"Initialized {len(device_configs)} devices from configuration")
    
    async def get_all_devices(self) -> List[Device]:
        """Get all devices from database"""
        return await self.db_service.get_all_devices()
    
    async def get_device(self, device_id: str) -> Optional[Device]:
        """Get specific device by ID"""
        return await self.db_service.get_device(device_id)
    
    async def register_device(self, device: Device):
        """Register a new device"""
        await self.db_service.add_device(device)
        
        # Log device registration
        await self.db_service.add_log(LogEntry(
            level=LogLevel.INFO,
            message=f"Device registered: {device.name}",
            device_id=device.id,
            component="device_service",
            timestamp=datetime.now()
        ))
        
        logger.info(f"Device registered: {device.id}")
    
    async def send_command(self, device_id: str, command: str, parameters: Optional[Dict[str, Any]] = None) -> bool:
        """Send command to device via MQTT"""
        if parameters is None:
            parameters = {}
            
        try:
            # Send command via communication service
            success = await self.communication_service.send_device_command(device_id, command, parameters)
            
            if success:
                # Log command
                await self.db_service.add_log(LogEntry(
                    level=LogLevel.INFO,
                    message=f"Command sent: {command}",
                    device_id=device_id,
                    component="device_service",
                    details={"command": command, "parameters": parameters},
                    timestamp=datetime.now()
                ))
                
                logger.info(f"Command sent to {device_id}: {command}")
                return True
            else:
                logger.error(f"Failed to send command to {device_id}: {command}")
                return False
                
        except Exception as e:
            logger.error(f"Error sending command to {device_id}: {e}")
            return False
    
    async def get_latest_sensor_readings(self, device_id: str) -> List[SensorReading]:
        """Get latest sensor readings for a device"""
        return await self.db_service.get_latest_sensor_readings(device_id)
    
    async def get_sensor_history(self, device_id: str, hours: int = 24) -> List[SensorReading]:
        """Get sensor readings history"""
        return await self.db_service.get_sensor_history(device_id, hours)
    
    async def get_system_config(self) -> Dict[str, Any]:
        """Get system configuration"""
        config = await self.db_service.get_all_config()
        
        # Add default configuration if not present
        default_config = {
            "watering_schedule": "daily",
            "watering_time": "06:00",
            "default_water_duration": "5",
            "max_water_duration": "60",
            "temperature_threshold": "25",
            "humidity_threshold": "60",
            "soil_moisture_threshold": "30"
        }
        
        for key, value in default_config.items():
            if key not in config:
                config[key] = value
                await self.db_service.set_config(key, value)
        
        return config
    
    async def update_system_config(self, config: Dict[str, Any]):
        """Update system configuration"""
        for key, value in config.items():
            await self.db_service.set_config(key, str(value))
        
        # Log configuration update
        await self.db_service.add_log(LogEntry(
            level=LogLevel.INFO,
            message="System configuration updated",
            component="device_service",
            details=config,
            timestamp=datetime.now()
        ))
    
    async def _handle_device_status(self, data: Dict[str, Any]):
        """Handle device status updates via MQTT"""
        try:
            device_id = data.get("device_id")
            status = data.get("status")
            
            if device_id and status:
                # Update device status in database
                await self.db_service.update_device_status(device_id, DeviceStatus(status))
                
                # Log status update
                await self.db_service.add_log(LogEntry(
                    level=LogLevel.INFO,
                    message=f"Device status updated: {status}",
                    device_id=device_id,
                    component="device_service",
                    timestamp=datetime.now()
                ))
                
                logger.info(f"Device {device_id} status updated: {status}")
                
        except Exception as e:
            logger.error(f"Error handling device status: {e}")
    
    async def _handle_sensor_data(self, data: Dict[str, Any]):
        """Handle sensor data via MQTT"""
        try:
            device_id = data.get("device_id")
            readings = data.get("readings", [])
            
            if device_id and readings:
                for reading_data in readings:
                    reading = SensorReading(
                        device_id=device_id,
                        sensor_type=SensorType(reading_data["sensor_type"]),
                        value=reading_data["value"],
                        unit=reading_data["unit"],
                        timestamp=datetime.fromisoformat(reading_data["timestamp"])
                    )
                    
                    # Store reading in database
                    await self.db_service.add_sensor_reading(reading)
                
                logger.info(f"Processed {len(readings)} sensor readings from {device_id}")
                
        except Exception as e:
            logger.error(f"Error handling sensor data: {e}")
    
    async def _handle_device_response(self, data: Dict[str, Any]):
        """Handle device command responses via MQTT"""
        try:
            device_id = data.get("device_id")
            command = data.get("command")
            success = data.get("success", False)
            message = data.get("message", "")
            
            if device_id and command:
                # Log response
                await self.db_service.add_log(LogEntry(
                    level=LogLevel.INFO if success else LogLevel.ERROR,
                    message=f"Device response: {command} - {message}",
                    device_id=device_id,
                    component="device_service",
                    details=data,
                    timestamp=datetime.now()
                ))
                
                logger.info(f"Device {device_id} response: {command} - {success}")
                
        except Exception as e:
            logger.error(f"Error handling device response: {e}")
    
    async def _handle_discovery_response(self, data: Dict[str, Any]):
        """Handle device discovery responses"""
        try:
            device_info = data.get("device_info")
            if device_info:
                device = Device(
                    id=device_info["id"],
                    name=device_info["name"],
                    device_type=DeviceType(device_info["device_type"]),
                    status=DeviceStatus.ONLINE,
                    ip_address=device_info.get("ip_address"),
                    capabilities=device_info.get("capabilities", []),
                    config=device_info.get("config", {}),
                    last_seen=datetime.now()
                )
                
                await self.register_device(device)
                logger.info(f"Device discovered and registered: {device.id}")
                
        except Exception as e:
            logger.error(f"Error handling discovery response: {e}")
    
    async def _monitor_devices(self):
        """Monitor device health and connectivity"""
        while True:
            try:
                devices = await self.get_all_devices()
                
                for device in devices:
                    # Get current device status from communication service
                    current_status = await self._get_device_status(device.id)
                    
                    # Update device status if it has changed
                    if current_status != device.status:
                        await self.db_service.update_device_status(device.id, current_status)
                        
                        # Log status change
                        await self.db_service.add_log(LogEntry(
                            level=LogLevel.INFO if current_status == DeviceStatus.ONLINE else LogLevel.WARNING,
                            message=f"Device status changed: {device.status.value} -> {current_status.value}",
                            device_id=device.id,
                            component="device_service",
                            timestamp=datetime.now()
                        ))
                        
                        logger.info(f"Device {device.id} status updated: {current_status.value}")
                    
                    # Also check heartbeat-based offline detection for MQTT/Serial devices
                    if device.last_seen and current_status == DeviceStatus.ONLINE:
                        time_since_last_seen = datetime.now() - device.last_seen
                        if time_since_last_seen > timedelta(minutes=5):
                            await self.db_service.update_device_status(device.id, DeviceStatus.OFFLINE)
                            
                            # Log device offline
                            await self.db_service.add_log(LogEntry(
                                level=LogLevel.WARNING,
                                message=f"Device went offline (no heartbeat)",
                                device_id=device.id,
                                component="device_service",
                                timestamp=datetime.now()
                            ))
                
                # Wait before next check
                await asyncio.sleep(60)  # Check every minute
                
            except Exception as e:
                logger.error(f"Error in device monitoring: {e}")
                await asyncio.sleep(60)
    
    async def _get_device_status(self, device_id: str) -> DeviceStatus:
        """Get current device status from communication service"""
        try:
            # Check if device is connected via communication service
            if isinstance(self.communication_service, MixedCommunicationService):
                if self.communication_service.is_device_connected(device_id):
                    comm_type = self.communication_service.get_device_communication_type(device_id)
                    
                    if comm_type == 'dummy':
                        # For dummy devices, get status from dummy service
                        if self.communication_service.dummy_service:
                            return await self.communication_service.dummy_service.get_device_status(device_id)
                    elif comm_type in ['mqtt', 'serial']:
                        # For MQTT/Serial devices, we'll rely on heartbeat mechanism
                        return DeviceStatus.ONLINE
                        
            return DeviceStatus.OFFLINE
            
        except Exception as e:
            logger.error(f"Error getting device status for {device_id}: {e}")
            return DeviceStatus.OFFLINE
    
    async def _initial_device_status_check(self):
        """Check device status immediately on startup"""
        try:
            # Wait a moment for services to fully initialize
            await asyncio.sleep(2)
            
            devices = await self.get_all_devices()
            
            for device in devices:
                # Get current device status from communication service
                current_status = await self._get_device_status(device.id)
                
                # Update device status if it has changed
                if current_status != device.status:
                    await self.db_service.update_device_status(device.id, current_status)
                    
                    # Log status change
                    await self.db_service.add_log(LogEntry(
                        level=LogLevel.INFO,
                        message=f"Initial device status: {current_status.value}",
                        device_id=device.id,
                        component="device_service",
                        timestamp=datetime.now()
                    ))
                    
                    logger.info(f"Device {device.id} initial status: {current_status.value}")
                    
        except Exception as e:
            logger.error(f"Error in initial device status check: {e}")
    
    async def discover_devices(self):
        """Broadcast device discovery message"""
        try:
            await self.communication_service.broadcast_discovery()
            logger.info("Device discovery broadcast sent")
        except Exception as e:
            logger.error(f"Error broadcasting device discovery: {e}")
    
    async def start_scheduled_watering(self):
        """Start scheduled watering task"""
        asyncio.create_task(self._scheduled_watering_task())
    
    async def _scheduled_watering_task(self):
        """Scheduled watering task"""
        while True:
            try:
                config = await self.get_system_config()
                watering_time = config.get("watering_time", "06:00")
                
                # Parse watering time
                hour, minute = map(int, watering_time.split(':'))
                
                # Check if it's time to water
                now = datetime.now()
                if now.hour == hour and now.minute == minute:
                    duration = int(config.get("default_water_duration", 5))
                    
                    # Send watering command
                    success = await self.send_command(
                        "arduino_pump", 
                        "water_start", 
                        {"duration": duration}
                    )
                    
                    if success:
                        await self.db_service.add_log(LogEntry(
                            level=LogLevel.INFO,
                            message=f"Scheduled watering started ({duration}s)",
                            device_id="arduino_pump",
                            component="device_service",
                            timestamp=datetime.now()
                        ))
                
                # Wait until next minute
                await asyncio.sleep(60)
                
            except Exception as e:
                logger.error(f"Error in scheduled watering: {e}")
                await asyncio.sleep(60) 