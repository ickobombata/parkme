import yaml
import os
import logging
from typing import Dict, Any, Optional

logger = logging.getLogger(__name__)

class ConfigService:
    def __init__(self, config_path: str = "config.yaml"):
        self.config_path = config_path
        self.config: Dict[str, Any] = {}
        self.load_config()
    
    def load_config(self):
        """Load configuration from YAML file"""
        try:
            if os.path.exists(self.config_path):
                with open(self.config_path, 'r') as file:
                    self.config = yaml.safe_load(file) or {}
                logger.info(f"Configuration loaded from {self.config_path}")
            else:
                logger.warning(f"Configuration file {self.config_path} not found, using defaults")
                self.config = self._get_default_config()
                self.save_config()
        except Exception as e:
            logger.error(f"Error loading configuration: {e}")
            self.config = self._get_default_config()
    
    def save_config(self):
        """Save current configuration to YAML file"""
        try:
            with open(self.config_path, 'w') as file:
                yaml.dump(self.config, file, default_flow_style=False)
            logger.info(f"Configuration saved to {self.config_path}")
        except Exception as e:
            logger.error(f"Error saving configuration: {e}")
    
    def _get_default_config(self) -> Dict[str, Any]:
        """Get default configuration"""
        return {
            'communication_method': 'serial',
            'mqtt': {
                'broker_host': 'localhost',
                'broker_port': 1883,
                'username': None,
                'password': None
            },
            'serial': {
                'port': '/dev/ttyUSB0',
                'baudrate': 115200,
                'timeout': 5
            },
            'database': {
                'path': 'data/iot_system.db'
            },
            'system': {
                'default_water_duration': 5,
                'max_water_duration': 60,
                'sensor_read_interval': 30,
                'device_heartbeat_interval': 60,
                'log_level': 'INFO'
            }
        }
    
    def get(self, key: str, default: Any = None) -> Any:
        """Get configuration value by key (supports dot notation)"""
        keys = key.split('.')
        value = self.config
        
        for k in keys:
            if isinstance(value, dict) and k in value:
                value = value[k]
            else:
                return default
        
        return value
    
    def set(self, key: str, value: Any):
        """Set configuration value by key (supports dot notation)"""
        keys = key.split('.')
        config = self.config
        
        for k in keys[:-1]:
            if k not in config:
                config[k] = {}
            config = config[k]
        
        config[keys[-1]] = value
    
    def get_communication_method(self) -> str:
        """Get the current communication method"""
        return self.get('communication_method', 'mqtt')
    
    def get_mqtt_config(self) -> Dict[str, Any]:
        """Get MQTT configuration"""
        return self.get('mqtt', {})
    
    def get_serial_config(self) -> Dict[str, Any]:
        """Get serial configuration"""
        return self.get('serial', {})
    
    def get_database_config(self) -> Dict[str, Any]:
        """Get database configuration"""
        return self.get('database', {})
    
    def get_system_config(self) -> Dict[str, Any]:
        """Get system configuration"""
        return self.get('system', {})
    
    def is_mqtt_enabled(self) -> bool:
        """Check if MQTT communication is enabled"""
        return self.get_communication_method().lower() == 'mqtt'
    
    def is_serial_enabled(self) -> bool:
        """Check if serial communication is enabled"""
        return self.get_communication_method().lower() == 'serial'

# Global configuration instance
config = ConfigService() 