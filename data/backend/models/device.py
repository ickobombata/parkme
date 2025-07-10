from pydantic import BaseModel
from datetime import datetime
from typing import List, Optional, Dict, Any
from enum import Enum

class DeviceType(str, Enum):
    PUMP = "pump"
    SENSOR = "sensor"
    CONTROLLER = "controller"
    LIGHT = "light"
    FAN = "fan"

class DeviceStatus(str, Enum):
    ONLINE = "online"
    OFFLINE = "offline"
    ERROR = "error"
    MAINTENANCE = "maintenance"

class SensorType(str, Enum):
    TEMPERATURE = "temperature"
    HUMIDITY = "humidity"
    SOIL_MOISTURE = "soil_moisture"
    LIGHT_LEVEL = "light_level"
    WATER_LEVEL = "water_level"
    PH = "ph"

class SensorReading(BaseModel):
    sensor_type: SensorType
    value: float
    unit: str
    timestamp: datetime
    device_id: str

class Device(BaseModel):
    id: str
    name: str
    device_type: DeviceType
    status: DeviceStatus
    ip_address: Optional[str] = None
    last_seen: Optional[datetime] = None
    location: Optional[str] = None
    description: Optional[str] = None
    firmware_version: Optional[str] = None
    battery_level: Optional[int] = None
    is_active: bool = True
    
    # Device-specific configuration
    config: Dict[str, Any] = {}
    
    # Latest sensor readings (if device has sensors)
    latest_readings: List[SensorReading] = []
    
    # Device capabilities
    capabilities: List[str] = []
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }

class DeviceCommand(BaseModel):
    device_id: str
    command: str
    parameters: Dict[str, Any] = {}
    timestamp: datetime = datetime.now()
    
class DeviceResponse(BaseModel):
    device_id: str
    command: str
    success: bool
    message: str
    data: Optional[Dict[str, Any]] = None
    timestamp: datetime = datetime.now()

class DeviceRegistration(BaseModel):
    id: str
    name: str
    device_type: DeviceType
    ip_address: str
    capabilities: List[str]
    config: Dict[str, Any] = {}
    location: Optional[str] = None
    description: Optional[str] = None 