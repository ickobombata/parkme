import asyncio
import json
import logging
import serial
import threading
import time
from typing import Dict, Callable, Optional, Any
from datetime import datetime
from services.config_service import config

logger = logging.getLogger(__name__)

class SerialService:
    def __init__(self):
        self.serial_config = config.get_serial_config()
        self.serial_port: Optional[serial.Serial] = None
        self.connected = False
        self.message_callbacks: Dict[str, Callable] = {}
        self.device_callbacks: Dict[str, Callable] = {}
        self.read_thread: Optional[threading.Thread] = None
        self.should_stop = False
        
    async def connect(self):
        """Connect to Arduino via serial"""
        try:
            port = self.serial_config.get('port', '/dev/ttyUSB0')
            baudrate = self.serial_config.get('baudrate', 115200)
            timeout = self.serial_config.get('timeout', 5)
            
            logger.info(f"Attempting to connect to serial port {port} at {baudrate} baud")
            
            self.serial_port = serial.Serial(
                port=port,
                baudrate=baudrate,
                timeout=timeout,
                write_timeout=timeout
            )
            
            # Wait for Arduino to initialize
            await asyncio.sleep(2)
            
            if self.serial_port.is_open:
                self.connected = True
                logger.info(f"Connected to Arduino on {port}")
                
                # Start reading thread
                self.should_stop = False
                self.read_thread = threading.Thread(target=self._read_serial_data, daemon=True)
                self.read_thread.start()
                
                # Send initial ping to check communication
                await self._send_ping()
            else:
                logger.error("Failed to open serial port")
                
        except serial.SerialException as e:
            logger.error(f"Serial connection error: {e}")
            raise
        except Exception as e:
            logger.error(f"Error connecting to Arduino: {e}")
            raise
    
    async def disconnect(self):
        """Disconnect from Arduino"""
        self.should_stop = True
        
        if self.read_thread and self.read_thread.is_alive():
            self.read_thread.join(timeout=5)
        
        if self.serial_port and self.serial_port.is_open:
            self.serial_port.close()
            self.connected = False
            logger.info("Disconnected from Arduino")
    
    def _read_serial_data(self):
        """Read data from serial port in background thread"""
        while not self.should_stop and self.serial_port and self.serial_port.is_open:
            try:
                if self.serial_port.in_waiting > 0:
                    line = self.serial_port.readline().decode('utf-8').strip()
                    if line:
                        logger.debug(f"Received serial data: {line}")
                        asyncio.run_coroutine_threadsafe(
                            self._process_serial_message(line),
                            asyncio.get_event_loop()
                        )
                time.sleep(0.1)  # Small delay to prevent busy waiting
            except Exception as e:
                logger.error(f"Error reading serial data: {e}")
                time.sleep(1)
    
    async def _process_serial_message(self, message: str):
        """Process received serial message"""
        try:
            # Try to parse as JSON
            if message.startswith('{') and message.endswith('}'):
                data = json.loads(message)
                await self._handle_json_message(data)
            else:
                # Handle plain text messages
                await self._handle_text_message(message)
        except json.JSONDecodeError:
            logger.warning(f"Invalid JSON in serial message: {message}")
            await self._handle_text_message(message)
        except Exception as e:
            logger.error(f"Error processing serial message: {e}")
    
    async def _handle_json_message(self, data: Dict[str, Any]):
        """Handle JSON message from Arduino"""
        message_type = data.get('type', 'unknown')
        device_id = data.get('device_id', 'arduino_device')
        
        logger.debug(f"Processing JSON message: {message_type} from {device_id}")
        
        # Route message based on type
        if message_type == 'response':
            await self._handle_device_response(data)
        elif message_type == 'sensor_data':
            await self._handle_sensor_data(data)
        elif message_type == 'status':
            await self._handle_device_status(data)
        elif message_type == 'heartbeat':
            await self._handle_heartbeat(data)
        else:
            # Generic device callback
            if device_id in self.device_callbacks:
                await self.device_callbacks[device_id]('serial', data)
    
    async def _handle_text_message(self, message: str):
        """Handle plain text message from Arduino"""
        logger.info(f"Arduino message: {message}")
        
        # Convert common text messages to structured format
        device_id = 'arduino_device'
        
        if 'watering started' in message.lower():
            data = {
                'type': 'response',
                'device_id': device_id,
                'command': 'water_start',
                'success': True,
                'message': message,
                'timestamp': datetime.now().isoformat()
            }
            await self._handle_device_response(data)
        elif 'watering stopped' in message.lower():
            data = {
                'type': 'response',
                'device_id': device_id,
                'command': 'water_stop',
                'success': True,
                'message': message,
                'timestamp': datetime.now().isoformat()
            }
            await self._handle_device_response(data)
        elif 'error' in message.lower():
            data = {
                'type': 'response',
                'device_id': device_id,
                'success': False,
                'message': message,
                'timestamp': datetime.now().isoformat()
            }
            await self._handle_device_response(data)
    
    async def _handle_device_response(self, data: Dict[str, Any]):
        """Handle device command response"""
        callback_key = f"devices/{data.get('device_id', 'unknown')}/response"
        if callback_key in self.message_callbacks:
            await self.message_callbacks[callback_key](data)
    
    async def _handle_sensor_data(self, data: Dict[str, Any]):
        """Handle sensor data from Arduino"""
        callback_key = f"devices/{data.get('device_id', 'unknown')}/sensors"
        if callback_key in self.message_callbacks:
            await self.message_callbacks[callback_key](data)
    
    async def _handle_device_status(self, data: Dict[str, Any]):
        """Handle device status update"""
        callback_key = f"devices/{data.get('device_id', 'unknown')}/status"
        if callback_key in self.message_callbacks:
            await self.message_callbacks[callback_key](data)
    
    async def _handle_heartbeat(self, data: Dict[str, Any]):
        """Handle device heartbeat"""
        # Update device as online
        status_data = {
            'device_id': data.get('device_id', 'arduino_device'),
            'status': 'online',
            'timestamp': datetime.now().isoformat()
        }
        await self._handle_device_status(status_data)
    
    async def send_command(self, device_id: str, command: str, parameters: Dict[str, Any] = None) -> bool:
        """Send command to Arduino via serial"""
        if not self.connected or not self.serial_port:
            logger.error("Serial port not connected")
            return False
        
        if parameters is None:
            parameters = {}
        
        try:
            # Create command message
            message = {
                'type': 'command',
                'device_id': device_id,
                'command': command,
                'parameters': parameters,
                'timestamp': datetime.now().isoformat()
            }
            
            # Send as JSON
            json_message = json.dumps(message) + '\n'
            self.serial_port.write(json_message.encode('utf-8'))
            self.serial_port.flush()
            
            logger.info(f"Sent command to Arduino: {command}")
            return True
            
        except Exception as e:
            logger.error(f"Error sending command via serial: {e}")
            return False
    
    async def send_device_command(self, device_id: str, command: str, parameters: Dict[str, Any] = None):
        """Send command to specific device (compatible with MQTT interface)"""
        return await self.send_command(device_id, command, parameters)
    
    async def _send_ping(self):
        """Send ping to check Arduino communication"""
        await self.send_command('arduino_device', 'ping', {})
    
    def register_message_callback(self, topic: str, callback: Callable):
        """Register callback for specific topic (compatible with MQTT interface)"""
        self.message_callbacks[topic] = callback
        logger.info(f"Registered callback for topic: {topic}")
    
    def register_device_callback(self, device_id: str, callback: Callable):
        """Register callback for specific device (compatible with MQTT interface)"""
        self.device_callbacks[device_id] = callback
        logger.info(f"Registered callback for device: {device_id}")
    
    async def request_device_status(self, device_id: str):
        """Request status from specific device"""
        return await self.send_command(device_id, "get_status")
    
    async def broadcast_discovery(self):
        """Broadcast discovery message to find devices"""
        return await self.send_command('all', 'discovery', {
            'server': 'home-iot-server',
            'timestamp': datetime.now().isoformat()
        })
    
    async def publish(self, topic: str, payload: Dict[str, Any], qos: int = 0):
        """Publish message (for compatibility with MQTT interface)"""
        # Extract device_id from topic if possible
        topic_parts = topic.split('/')
        device_id = topic_parts[1] if len(topic_parts) > 1 else 'arduino_device'
        
        # Convert topic to command
        if 'commands' in topic:
            command = payload.get('command', 'unknown')
            parameters = payload.get('parameters', {})
            return await self.send_command(device_id, command, parameters)
        else:
            # Generic message
            return await self.send_command(device_id, 'message', payload)
    
    def is_connected(self) -> bool:
        """Check if serial connection is active"""
        return self.connected and self.serial_port and self.serial_port.is_open 