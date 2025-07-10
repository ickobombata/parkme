# Quick Start Guide - Serial Communication

This guide will help you quickly set up the Home IoT system using serial communication for testing purposes.

## Prerequisites

- Raspberry Pi (or any computer with Python 3.8+)
- Arduino (any model with USB connection)
- Water pump or LED for testing
- Sensors (optional for testing)

## Step 1: Hardware Setup

### Arduino Connections

```
Arduino Pin → Component
12          → Pump relay IN pin (or LED for testing)
7           → Sensor power (optional)
A0          → Soil moisture sensor (optional)
A1          → TMP36 temperature sensor (optional)
A2          → Humidity sensor (optional)
GND         → All sensor/relay grounds
5V          → Relay VCC, sensor VCC
```

### Connect Arduino to Raspberry Pi

1. Connect Arduino to Raspberry Pi via USB cable
2. Note the serial port (usually `/dev/ttyUSB0` or `/dev/ttyACM0`)

## Step 2: Upload Arduino Code

1. Open Arduino IDE
2. Install ArduinoJson library:
   - Go to Sketch → Include Library → Manage Libraries
   - Search for "ArduinoJson" and install version 6.x
3. Open `data/arduino_examples/serial_communication/serial_communication.ino`
4. Upload to your Arduino

## Step 3: Backend Setup

```bash
cd data/backend

# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Create configuration file
cat > config.yaml << EOF
communication_method: 'serial'

serial:
  port: '/dev/ttyUSB0'  # Change this to your actual port
  baudrate: 115200
  timeout: 5

database:
  path: 'data/iot_system.db'

system:
  default_water_duration: 5
  max_water_duration: 60
  sensor_read_interval: 30
  device_heartbeat_interval: 60
  log_level: 'INFO'
EOF

# Start the backend
python main.py
```

## Step 4: Frontend Setup

```bash
cd data/frontend

# Install dependencies
npm install

# Start development server
npm start
```

## Step 5: Test the System

1. Open browser to `http://localhost:4200`
2. Go to "Functions" section
3. Try controlling the water pump
4. Check "Home" section for sensor readings
5. View "Logs" for system activity

## Finding Your Serial Port

### Linux
```bash
# List all serial ports
ls /dev/tty*

# Find Arduino specifically
dmesg | grep tty
```

### Windows
1. Open Device Manager
2. Look under "Ports (COM & LPT)"
3. Find your Arduino (usually COM3, COM4, etc.)

### macOS
```bash
ls /dev/cu.usbserial*
```

## Common Issues

### Permission Denied (Linux)
```bash
sudo chmod 666 /dev/ttyUSB0
# Or add user to dialout group
sudo usermod -a -G dialout $USER
# Then logout and login again
```

### Arduino Not Responding
1. Check USB cable connection
2. Verify correct serial port in config.yaml
3. Make sure Arduino IDE Serial Monitor is closed
4. Check baud rate (should be 115200)

### No Sensor Data
1. Check sensor connections
2. Verify sensor power (pin 7 should be HIGH)
3. Sensors are optional - pump control should work without them

## Testing Without Hardware

You can test the system without physical hardware:

1. Upload the Arduino code anyway
2. Open Arduino IDE Serial Monitor at 115200 baud
3. Send test JSON commands:
   ```json
   {"type":"command","device_id":"arduino_pump","command":"ping","parameters":{},"timestamp":"2024-01-01T12:00:00Z"}
   ```

## Next Steps

Once serial communication is working:

1. Set up WiFi module for wireless communication
2. Configure MQTT broker
3. Switch to `communication_method: 'mqtt'` in config.yaml
4. Deploy to production environment

## Switching to MQTT Later

When ready to switch to MQTT:

1. Edit `config.yaml`:
   ```yaml
   communication_method: 'mqtt'
   ```
2. Set up MQTT broker (Mosquitto)
3. Upload MQTT Arduino code
4. Configure WiFi settings in Arduino code

The frontend and backend will work exactly the same way - only the communication method changes! 