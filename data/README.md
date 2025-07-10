# Home IoT Control System

A complete IoT home automation system with Angular frontend and FastAPI backend, designed for controlling Arduino-based devices like watering systems, sensors, and more.

## Features

- **Web-based Dashboard**: Angular PWA with Material Design
- **Real-time Updates**: WebSocket communication for live data
- **Multi-Device Support**: Control multiple IoT devices simultaneously
- **Mixed Communication**: Serial (USB) and MQTT (WiFi) devices in one system
- **Device Control**: Water pump control, sensor monitoring, lighting, and more
- **Flexible Configuration**: Easy device addition via configuration file
- **Extensible Architecture**: Support for various device types and capabilities
- **Mobile-friendly**: PWA support for Android installation

## Architecture

The system supports two communication methods for flexibility:

### MQTT Communication (WiFi)
```
[Angular PWA Frontend] <-> [FastAPI Backend] <-> [MQTT Broker] <-> [Arduino Devices]
                      |                    |
                      v                    v
                  [WebSocket]         [SQLite Database]
```

### Serial Communication (USB/UART)
```
[Angular PWA Frontend] <-> [FastAPI Backend] <-> [Serial Connection] <-> [Arduino Device]
                      |                    |
                      v                    v
                  [WebSocket]         [SQLite Database]
```

## Prerequisites

- Python 3.8+
- Node.js 14+ and npm
- Arduino with sensors/actuators

**For MQTT Communication:**
- MQTT Broker (Mosquitto recommended)
- Arduino with WiFi module (ESP32/ESP8266)

**For Serial Communication:**
- USB cable or UART connection
- Arduino (any model with serial communication)

## Quick Start

> **📖 For detailed multi-device setup**: See [Multi-Device Setup Guide](MULTI_DEVICE_GUIDE.md)
> 
> **🚀 For simple serial testing**: See [Serial Quick Start](QUICK_START_SERIAL.md)

### 1. Backend Setup

```bash
cd data/backend

# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Start the backend server
python main.py
```

The backend will be available at `http://localhost:8000`

### 2. Frontend Setup

```bash
cd data/frontend

# Install dependencies
npm install

# Start development server
npm start
```

The frontend will be available at `http://localhost:4200`

### 3. MQTT Broker Setup

Install and start Mosquitto MQTT broker:

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install mosquitto mosquitto-clients

# macOS
brew install mosquitto

# Start the broker
mosquitto -c /usr/local/etc/mosquitto/mosquitto.conf
```

## Configuration

### Multi-Device Configuration

The system now supports multiple devices with mixed communication methods. Each device can be configured independently:

Create/edit `data/backend/config.yaml`:

```yaml
# IoT System Configuration - Mixed Communication Mode

# MQTT Configuration (for WiFi devices)
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
    communication: 'serial'
    capabilities: ['water_control', 'status_reporting']
    config:
      port: '/dev/ttyUSB0'
      baudrate: 115200
      timeout: 5
      
  # MQTT connected devices
  - id: 'esp32_outdoor'
    name: 'ESP32 Outdoor Station'
    device_type: 'controller'
    location: 'Garden'
    communication: 'mqtt'
    capabilities: ['water_control', 'temperature_reading']
    config:
      mqtt_topic: 'devices/esp32_outdoor'
      ip_address: '192.168.1.100'
      
# Database Configuration
database:
  path: 'data/iot_system.db'
  
# System Configuration
system:
  default_water_duration: 5
  max_water_duration: 60
  sensor_read_interval: 30
  device_heartbeat_interval: 60
  log_level: 'INFO'
```

### Backend Configuration

The backend automatically uses the communication method specified in `config.yaml`.

### Frontend Configuration

Edit `data/frontend/src/environments/environment.ts`:

```typescript
export const environment = {
  production: false,
  apiUrl: 'http://your-backend-ip:8000/api',
  wsUrl: 'ws://your-backend-ip:8000/ws'
};
```

## Arduino Setup

### Method 1: Serial Communication (Recommended for Testing)

**Required Libraries:**
- ArduinoJson

**Hardware Setup:**
1. Connect Arduino to Raspberry Pi via USB cable
2. Connect sensors and actuators to Arduino pins
3. Upload the serial communication sketch

**Example Arduino Code (Serial):**

Use the provided `data/arduino_examples/serial_communication/serial_communication.ino`

**Pin Configuration:**
- Pin 12: Pump relay control
- Pin 7: Sensor power control
- A0: Soil moisture sensor
- A1: Temperature sensor (TMP36)
- A2: Humidity sensor

### Method 2: MQTT Communication (For Production)

**Required Libraries:**
- WiFi (ESP32/ESP8266)
- PubSubClient (MQTT)
- ArduinoJson

### Example Arduino Code

```cpp
#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>

const char* ssid = "your_wifi_ssid";
const char* password = "your_wifi_password";
const char* mqtt_server = "your_mqtt_broker_ip";

WiFiClient espClient;
PubSubClient client(espClient);

void setup() {
  Serial.begin(115200);
  
  // Connect to WiFi
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  
  // Connect to MQTT
  client.setServer(mqtt_server, 1883);
  client.setCallback(callback);
  
  while (!client.connected()) {
    if (client.connect("arduino_pump")) {
      client.subscribe("devices/arduino_pump/commands");
    }
  }
}

void callback(char* topic, byte* payload, unsigned int length) {
  // Handle commands from server
  StaticJsonDocument<200> doc;
  deserializeJson(doc, payload, length);
  
  String command = doc["command"];
  if (command == "water_start") {
    int duration = doc["parameters"]["duration"];
    startWatering(duration);
  } else if (command == "water_stop") {
    stopWatering();
  }
}

void startWatering(int duration) {
  // Control your pump here
  digitalWrite(PUMP_PIN, HIGH);
  delay(duration * 1000);
  digitalWrite(PUMP_PIN, LOW);
  
  // Send response back
  StaticJsonDocument<200> response;
  response["device_id"] = "arduino_pump";
  response["command"] = "water_start";
  response["success"] = true;
  response["message"] = "Watering completed";
  
  char buffer[256];
  serializeJson(response, buffer);
  client.publish("devices/arduino_pump/response", buffer);
}
```

## Communication Protocol

The system uses the same message format for both MQTT and Serial communication:

### MQTT Topics (When using MQTT)

- `devices/{device_id}/commands` - Send commands to devices
- `devices/{device_id}/response` - Device responses
- `devices/{device_id}/status` - Device status updates
- `devices/{device_id}/sensors` - Sensor data from devices
- `system/discovery` - Device discovery

### Serial Communication (When using Serial)

- Messages are sent as JSON strings over serial connection
- Same message format as MQTT but directly over serial
- Each device configured with specific serial port

### Mixed Communication (Recommended)

- **Best of Both Worlds**: Combine serial and MQTT devices
- **Per-Device Configuration**: Each device specifies its communication method
- **Unified Management**: All devices controlled through same interface
- **Easy Scaling**: Add devices without changing existing setup

### Example Messages

**Water Command:**
```json
{
  "command": "water_start",
  "parameters": {
    "duration": 5
  },
  "timestamp": "2024-01-01T12:00:00Z"
}
```

**Sensor Data:**
```json
{
  "device_id": "arduino_sensors",
  "readings": [
    {
      "sensor_type": "temperature",
      "value": 25.6,
      "unit": "°C",
      "timestamp": "2024-01-01T12:00:00Z"
    }
  ]
}
```

## Production Deployment

### Backend (FastAPI)

```bash
# Install production server
pip install gunicorn

# Run with Gunicorn
gunicorn -w 4 -k uvicorn.workers.UvicornWorker main:app --bind 0.0.0.0:8000
```

### Frontend (Angular PWA)

```bash
# Build for production
npm run build

# Serve with nginx or apache
# Copy dist/home-iot-frontend/* to your web server
```

### Docker Deployment

Create `docker-compose.yml`:

```yaml
version: '3.8'
services:
  backend:
    build: ./backend
    ports:
      - "8000:8000"
    depends_on:
      - mosquitto
    
  frontend:
    build: ./frontend
    ports:
      - "80:80"
    depends_on:
      - backend
    
  mosquitto:
    image: eclipse-mosquitto:latest
    ports:
      - "1883:1883"
    volumes:
      - ./mosquitto.conf:/mosquitto/config/mosquitto.conf
```

## System Navigation

- **Home**: Dashboard with device status and sensor readings
- **Functions**: Control devices (water pump, future devices)
- **Logs**: System logs and device activity
- **Settings**: System configuration

## Extending the System

### Adding New Devices

1. Define device in `backend/services/device_service.py`
2. Add MQTT message handlers
3. Update frontend components
4. Configure Arduino code

### Adding New Sensors

1. Update `SensorType` enum in `backend/models/device.py`
2. Add sensor icons and formatting in frontend
3. Update database schema if needed

## Troubleshooting

### Common Issues

1. **MQTT Connection Failed**
   - Check broker is running
   - Verify firewall settings
   - Confirm network connectivity

2. **Serial Connection Failed**
   - Check USB cable connection
   - Verify correct serial port in `config.yaml`
   - Check serial port permissions (`sudo chmod 666 /dev/ttyUSB0`)
   - Ensure Arduino is not connected to Serial Monitor

3. **Device Not Responding**
   - **MQTT**: Check Arduino WiFi connection and MQTT subscriptions
   - **Serial**: Check serial connection and baud rate (115200)
   - Verify device power and sensor connections

4. **Frontend Can't Connect**
   - Verify backend is running
   - Check CORS settings
   - Confirm API endpoints

### Finding Serial Port

**Linux:**
```bash
ls /dev/tty*
# Usually /dev/ttyUSB0 or /dev/ttyACM0
```

**Windows:**
```cmd
# Check Device Manager → Ports (COM & LPT)
# Usually COM3, COM4, etc.
```

**macOS:**
```bash
ls /dev/cu.usbserial*
# Usually /dev/cu.usbserial-*
```

## Security Considerations

- Use MQTT authentication in production
- Implement HTTPS for web interface
- Secure your WiFi network
- Regular security updates

## License

MIT License - Feel free to use and modify for your projects.

## Support

For issues and questions, please create an issue in the repository. 