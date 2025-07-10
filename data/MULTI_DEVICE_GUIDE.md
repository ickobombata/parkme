# Multi-Device IoT System Setup Guide

This guide explains how to set up and manage multiple IoT devices using the enhanced mixed communication system. Each device can be configured independently for either serial or MQTT communication.

## Overview

The system now supports:
- **Mixed Communication**: Some devices via serial (USB), others via MQTT (WiFi)
- **Multiple Serial Devices**: Each on different USB ports
- **Multiple MQTT Devices**: Each with unique topics and IP addresses
- **Automatic Device Registration**: Devices are configured in `config.yaml`
- **Unified Management**: All devices managed through the same web interface

## Architecture

```
[Angular Frontend] 
       ↓
[FastAPI Backend]
       ↓
[Mixed Communication Service]
       ├── [MQTT Service] ← → [WiFi Devices (ESP32/ESP8266)]
       └── [Serial Services] ← → [USB Devices (Arduino)]
```

## Device Configuration

### 1. Configuration File Structure

Edit `data/backend/config.yaml` to define your devices:

```yaml
# IoT System Configuration - Mixed Communication Mode
# Each device can be configured for either serial or MQTT communication

# MQTT Configuration (for WiFi-enabled devices)
mqtt:
  broker_host: 'localhost'
  broker_port: 1883
  username: null
  password: null

# Device Configuration - specify communication method per device
devices:
  # Serial connected devices
  - id: 'arduino_pump'
    name: 'Arduino Water Pump'
    device_type: 'pump'
    location: 'Balcony'
    description: 'Main watering pump for balcony plants'
    communication: 'serial'
    capabilities: ['water_control', 'status_reporting']
    config:
      port: '/dev/ttyUSB0'
      baudrate: 115200
      timeout: 5
      max_water_duration: 60
      default_water_duration: 5
      
  - id: 'arduino_sensors'
    name: 'Arduino Sensor Array'
    device_type: 'sensor'
    location: 'Garden'
    description: 'Temperature, humidity, and soil moisture sensors'
    communication: 'serial'
    capabilities: ['temperature_reading', 'humidity_reading', 'soil_moisture_reading']
    config:
      port: '/dev/ttyUSB1'
      baudrate: 115200
      timeout: 5
      reading_interval: 30
      
  # MQTT connected devices (WiFi)
  - id: 'esp32_outdoor'
    name: 'ESP32 Outdoor Station'
    device_type: 'controller'
    location: 'Garden'
    description: 'WiFi-enabled outdoor sensor and control station'
    communication: 'mqtt'
    capabilities: ['water_control', 'temperature_reading', 'humidity_reading', 'light_control']
    config:
      mqtt_topic: 'devices/esp32_outdoor'
      ip_address: '192.168.1.100'
      max_water_duration: 60
      
  - id: 'esp8266_indoor'
    name: 'ESP8266 Indoor Monitor'
    device_type: 'sensor'
    location: 'Living Room'
    description: 'WiFi-enabled indoor environmental monitor'
    communication: 'mqtt'
    capabilities: ['temperature_reading', 'humidity_reading', 'air_quality_reading']
    config:
      mqtt_topic: 'devices/esp8266_indoor'
      ip_address: '192.168.1.101'
      reading_interval: 60
```

### 2. Device Properties

Each device configuration includes:

- **id**: Unique identifier for the device
- **name**: Human-readable name
- **device_type**: Type of device (`pump`, `sensor`, `controller`, `light`, `fan`)
- **location**: Physical location
- **description**: Detailed description
- **communication**: Communication method (`serial` or `mqtt`)
- **capabilities**: List of device capabilities
- **config**: Device-specific configuration

## Hardware Setup

### Serial Devices (Arduino)

1. **Connect Multiple Arduinos**:
   ```
   Raspberry Pi USB Ports:
   ├── /dev/ttyUSB0 → Arduino Pump Controller
   ├── /dev/ttyUSB1 → Arduino Sensor Array
   └── /dev/ttyUSB2 → Arduino Light Controller
   ```

2. **Upload Arduino Code**:
   - Use `data/arduino_examples/serial_communication/serial_communication.ino`
   - Modify `DEVICE_ID` in each Arduino sketch to match config
   - Upload to each Arduino separately

3. **Pin Configuration** (adjust per device):
   ```
   Arduino Pump (arduino_pump):
   - Pin 12: Pump relay
   - Pin 13: Status LED
   
   Arduino Sensors (arduino_sensors):
   - Pin 7: Sensor power
   - A0: Soil moisture
   - A1: Temperature (TMP36)
   - A2: Humidity sensor
   
   Arduino Lights (arduino_lights):
   - Pin 8: LED strip relay
   - Pin 9: Status LED
   ```

### MQTT Devices (ESP32/ESP8266)

1. **WiFi Configuration**:
   ```cpp
   const char* ssid = "your_wifi_ssid";
   const char* password = "your_wifi_password";
   const char* mqtt_server = "192.168.1.10";  // Your Pi's IP
   ```

2. **Device Topics**:
   ```
   ESP32 Outdoor:
   - devices/esp32_outdoor/commands
   - devices/esp32_outdoor/sensors
   - devices/esp32_outdoor/status
   
   ESP8266 Indoor:
   - devices/esp8266_indoor/commands
   - devices/esp8266_indoor/sensors
   - devices/esp8266_indoor/status
   ```

## Software Setup

### 1. Install Dependencies

```bash
cd data/backend
pip install -r requirements.txt
```

### 2. Configure Devices

Edit `config.yaml` with your specific device configurations.

### 3. Find Serial Ports

```bash
# Linux - list USB devices
ls /dev/tty* | grep USB

# Check which device is which
dmesg | grep tty | tail -10

# Test connection
screen /dev/ttyUSB0 115200
```

### 4. Set Serial Permissions

```bash
# Add user to dialout group
sudo usermod -a -G dialout $USER

# Or set permissions directly
sudo chmod 666 /dev/ttyUSB0
sudo chmod 666 /dev/ttyUSB1
```

### 5. Start Services

```bash
# Start MQTT broker (if using MQTT devices)
sudo systemctl start mosquitto

# Start backend
cd data/backend
python main.py

# Start frontend
cd data/frontend
npm start
```

## Usage Examples

### Adding New Devices

1. **Add Serial Device**:
   ```yaml
   - id: 'arduino_greenhouse'
     name: 'Greenhouse Controller'
     device_type: 'controller'
     location: 'Greenhouse'
     description: 'Temperature and humidity control for greenhouse'
     communication: 'serial'
     capabilities: ['temperature_reading', 'humidity_reading', 'fan_control', 'heater_control']
     config:
       port: '/dev/ttyUSB2'
       baudrate: 115200
       timeout: 5
   ```

2. **Add MQTT Device**:
   ```yaml
   - id: 'esp32_pool'
     name: 'Pool Monitor'
     device_type: 'sensor'
     location: 'Pool Area'
     description: 'Pool temperature and chemical monitoring'
     communication: 'mqtt'
     capabilities: ['temperature_reading', 'ph_reading', 'chlorine_reading']
     config:
       mqtt_topic: 'devices/esp32_pool'
       ip_address: '192.168.1.105'
       reading_interval: 300
   ```

### Device Control Examples

1. **Water Pump Control**:
   ```json
   POST /api/devices/arduino_pump/command
   {
     "command": "water_start",
     "parameters": {
       "duration": 10
     }
   }
   ```

2. **Sensor Reading**:
   ```json
   GET /api/devices/arduino_sensors/sensors/latest
   ```

3. **Status Check**:
   ```json
   GET /api/devices/esp32_outdoor/status
   ```

## Device Types and Capabilities

### Device Types
- `pump`: Water pump controllers
- `sensor`: Environmental sensors
- `controller`: Multi-function controllers
- `light`: Lighting controllers
- `fan`: Ventilation controllers

### Common Capabilities
- `water_control`: Can start/stop water pumps
- `temperature_reading`: Temperature sensors
- `humidity_reading`: Humidity sensors
- `soil_moisture_reading`: Soil moisture sensors
- `light_control`: Light on/off control
- `fan_control`: Fan speed control
- `status_reporting`: Device status updates

## Troubleshooting

### Serial Device Issues

1. **Device Not Found**:
   ```bash
   # Check if device is connected
   lsusb
   
   # Check serial ports
   dmesg | grep tty
   
   # Try different port
   ls /dev/tty*
   ```

2. **Permission Denied**:
   ```bash
   # Fix permissions
   sudo chmod 666 /dev/ttyUSB0
   
   # Or add to group
   sudo usermod -a -G dialout $USER
   ```

3. **Connection Timeout**:
   - Check USB cable
   - Verify baud rate (115200)
   - Ensure Arduino Serial Monitor is closed

### MQTT Device Issues

1. **Connection Failed**:
   ```bash
   # Test MQTT broker
   mosquitto_pub -h localhost -t test -m "hello"
   mosquitto_sub -h localhost -t test
   ```

2. **Device Not Responding**:
   - Check WiFi connection
   - Verify MQTT broker IP
   - Check device power

### Mixed Issues

1. **Some Devices Not Loading**:
   - Check config.yaml syntax
   - Verify device IDs are unique
   - Check logs for specific errors

2. **Frontend Shows Wrong Status**:
   - Restart backend service
   - Check WebSocket connection
   - Verify device communication

## Scaling Up

### Adding More Devices

1. **Plan Your Setup**:
   - Identify communication method per device
   - Assign unique IDs and ports
   - Plan physical connections

2. **Update Configuration**:
   - Add device entries to config.yaml
   - Assign appropriate capabilities
   - Configure device-specific settings

3. **Test Incrementally**:
   - Add one device at a time
   - Test each device before adding next
   - Monitor logs for errors

### Performance Considerations

- **Serial**: Limited by USB ports (use USB hubs if needed)
- **MQTT**: Limited by network bandwidth and broker capacity
- **Mixed**: Best of both worlds - reliable serial + flexible WiFi

## Best Practices

1. **Device Naming**: Use descriptive, consistent naming
2. **Configuration**: Keep config.yaml organized with comments
3. **Testing**: Test each device individually before integration
4. **Documentation**: Document your specific setup and pin assignments
5. **Monitoring**: Regularly check device status and logs
6. **Backup**: Keep backup of working configurations

## Future Enhancements

The system is designed to be extensible:
- Add new device types easily
- Support additional communication protocols
- Implement device grouping and scenes
- Add scheduling and automation rules
- Integrate with home automation systems 