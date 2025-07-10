// Home IoT Arduino Code - Serial Communication Version
// This version communicates via serial connection to Raspberry Pi

#include <ArduinoJson.h>

// Pin definitions
#define PUMP_PIN 12       // Relay pin for water pump
#define SENSOR_POWER_PIN 7
#define SOIL_MOISTURE_PIN A0
#define TEMP_SENSOR_PIN A1
#define HUMIDITY_SENSOR_PIN A2

// Device configuration
const String DEVICE_ID = "arduino_pump";
const String DEVICE_NAME = "Arduino Water Pump";
const unsigned long HEARTBEAT_INTERVAL = 30000; // 30 seconds
const unsigned long SENSOR_INTERVAL = 60000;    // 1 minute

// Global variables
unsigned long lastHeartbeat = 0;
unsigned long lastSensorReading = 0;
bool pumpRunning = false;
unsigned long pumpStartTime = 0;
unsigned long pumpDuration = 0;

void setup() {
  Serial.begin(115200);
  
  // Initialize pins
  pinMode(PUMP_PIN, OUTPUT);
  pinMode(SENSOR_POWER_PIN, OUTPUT);
  pinMode(LED_BUILTIN, OUTPUT);
  
  digitalWrite(PUMP_PIN, LOW);
  digitalWrite(SENSOR_POWER_PIN, HIGH);
  digitalWrite(LED_BUILTIN, HIGH);
  
  // Wait for serial connection
  while (!Serial) {
    delay(100);
  }
  
  delay(2000); // Give system time to initialize
  
  // Send startup message
  sendStatusMessage("Arduino started - Serial mode");
  sendHeartbeat();
  
  Serial.println("Arduino IoT Device Ready - Serial Communication");
}

void loop() {
  // Check for incoming serial commands
  if (Serial.available()) {
    processSerialCommand();
  }
  
  // Handle pump timing
  if (pumpRunning) {
    if (millis() - pumpStartTime >= pumpDuration) {
      stopWatering();
    }
  }
  
  // Send periodic heartbeat
  if (millis() - lastHeartbeat >= HEARTBEAT_INTERVAL) {
    sendHeartbeat();
    lastHeartbeat = millis();
  }
  
  // Send periodic sensor readings
  if (millis() - lastSensorReading >= SENSOR_INTERVAL) {
    sendSensorData();
    lastSensorReading = millis();
  }
  
  delay(100); // Small delay for stability
}

void processSerialCommand() {
  String message = Serial.readStringUntil('\n');
  message.trim();
  
  if (message.length() == 0) return;
  
  // Try to parse JSON command
  StaticJsonDocument<256> doc;
  DeserializationError error = deserializeJson(doc, message);
  
  if (error) {
    Serial.println("Invalid JSON command received");
    return;
  }
  
  String command = doc["command"];
  String deviceId = doc["device_id"];
  
  // Check if command is for this device
  if (deviceId != DEVICE_ID && deviceId != "all") {
    return;
  }
  
  // Process commands
  if (command == "water_start") {
    int duration = doc["parameters"]["duration"] | 5; // Default 5 seconds
    startWatering(duration);
  }
  else if (command == "water_stop") {
    stopWatering();
  }
  else if (command == "get_status") {
    sendDeviceStatus();
  }
  else if (command == "ping") {
    sendPingResponse();
  }
  else if (command == "get_sensors") {
    sendSensorData();
  }
  else if (command == "discovery") {
    sendDiscoveryResponse();
  }
  else {
    sendErrorResponse("Unknown command: " + command);
  }
}

void startWatering(int duration) {
  if (pumpRunning) {
    sendErrorResponse("Pump is already running");
    return;
  }
  
  pumpDuration = duration * 1000; // Convert to milliseconds
  pumpStartTime = millis();
  pumpRunning = true;
  
  digitalWrite(PUMP_PIN, HIGH);
  digitalWrite(LED_BUILTIN, LOW); // LED on when pump running
  
  // Send response
  StaticJsonDocument<256> response;
  response["type"] = "response";
  response["device_id"] = DEVICE_ID;
  response["command"] = "water_start";
  response["success"] = true;
  response["message"] = "Watering started for " + String(duration) + " seconds";
  response["timestamp"] = millis();
  
  String responseStr;
  serializeJson(response, responseStr);
  Serial.println(responseStr);
  
  // Also send plain text for debugging
  Serial.println("Watering started for " + String(duration) + " seconds");
}

void stopWatering() {
  if (!pumpRunning) {
    sendErrorResponse("Pump is not running");
    return;
  }
  
  pumpRunning = false;
  digitalWrite(PUMP_PIN, LOW);
  digitalWrite(LED_BUILTIN, HIGH); // LED off when pump stopped
  
  int actualDuration = (millis() - pumpStartTime) / 1000;
  
  // Send response
  StaticJsonDocument<256> response;
  response["type"] = "response";
  response["device_id"] = DEVICE_ID;
  response["command"] = "water_stop";
  response["success"] = true;
  response["message"] = "Watering stopped after " + String(actualDuration) + " seconds";
  response["timestamp"] = millis();
  
  String responseStr;
  serializeJson(response, responseStr);
  Serial.println(responseStr);
  
  // Also send plain text for debugging
  Serial.println("Watering stopped after " + String(actualDuration) + " seconds");
}

void sendHeartbeat() {
  StaticJsonDocument<256> heartbeat;
  heartbeat["type"] = "heartbeat";
  heartbeat["device_id"] = DEVICE_ID;
  heartbeat["status"] = "online";
  heartbeat["timestamp"] = millis();
  heartbeat["pump_running"] = pumpRunning;
  
  String heartbeatStr;
  serializeJson(heartbeat, heartbeatStr);
  Serial.println(heartbeatStr);
}

void sendSensorData() {
  // Read sensors
  digitalWrite(SENSOR_POWER_PIN, HIGH);
  delay(100); // Let sensors stabilize
  
  int soilMoisture = analogRead(SOIL_MOISTURE_PIN);
  int tempRaw = analogRead(TEMP_SENSOR_PIN);
  int humidityRaw = analogRead(HUMIDITY_SENSOR_PIN);
  
  // Convert to meaningful values (adjust these formulas based on your sensors)
  float temperature = (tempRaw * 5.0 / 1024.0 - 0.5) * 100; // TMP36 sensor formula
  float humidity = map(humidityRaw, 0, 1023, 0, 100);
  float soilMoisturePercent = map(soilMoisture, 0, 1023, 100, 0); // Inverted scale
  
  // Create sensor data message
  StaticJsonDocument<512> sensorMsg;
  sensorMsg["type"] = "sensor_data";
  sensorMsg["device_id"] = DEVICE_ID;
  sensorMsg["timestamp"] = millis();
  
  JsonArray readings = sensorMsg.createNestedArray("readings");
  
  JsonObject tempReading = readings.createNestedObject();
  tempReading["sensor_type"] = "temperature";
  tempReading["value"] = temperature;
  tempReading["unit"] = "°C";
  tempReading["timestamp"] = millis();
  tempReading["device_id"] = DEVICE_ID;
  
  JsonObject humidityReading = readings.createNestedObject();
  humidityReading["sensor_type"] = "humidity";
  humidityReading["value"] = humidity;
  humidityReading["unit"] = "%";
  humidityReading["timestamp"] = millis();
  humidityReading["device_id"] = DEVICE_ID;
  
  JsonObject soilReading = readings.createNestedObject();
  soilReading["sensor_type"] = "soil_moisture";
  soilReading["value"] = soilMoisturePercent;
  soilReading["unit"] = "%";
  soilReading["timestamp"] = millis();
  soilReading["device_id"] = DEVICE_ID;
  
  String sensorStr;
  serializeJson(sensorMsg, sensorStr);
  Serial.println(sensorStr);
}

void sendDeviceStatus() {
  StaticJsonDocument<256> status;
  status["type"] = "status";
  status["device_id"] = DEVICE_ID;
  status["status"] = "online";
  status["pump_running"] = pumpRunning;
  status["firmware_version"] = "1.0.0";
  status["uptime"] = millis();
  status["timestamp"] = millis();
  
  String statusStr;
  serializeJson(status, statusStr);
  Serial.println(statusStr);
}

void sendPingResponse() {
  StaticJsonDocument<256> response;
  response["type"] = "response";
  response["device_id"] = DEVICE_ID;
  response["command"] = "ping";
  response["success"] = true;
  response["message"] = "Pong";
  response["timestamp"] = millis();
  
  String responseStr;
  serializeJson(response, responseStr);
  Serial.println(responseStr);
}

void sendDiscoveryResponse() {
  StaticJsonDocument<512> discovery;
  discovery["type"] = "response";
  discovery["command"] = "discovery";
  discovery["device_info"]["id"] = DEVICE_ID;
  discovery["device_info"]["name"] = DEVICE_NAME;
  discovery["device_info"]["device_type"] = "pump";
  discovery["device_info"]["firmware_version"] = "1.0.0";
  discovery["device_info"]["capabilities"].add("water_control");
  discovery["device_info"]["capabilities"].add("status_reporting");
  discovery["device_info"]["capabilities"].add("sensor_reading");
  discovery["timestamp"] = millis();
  
  String discoveryStr;
  serializeJson(discovery, discoveryStr);
  Serial.println(discoveryStr);
}

void sendErrorResponse(String errorMessage) {
  StaticJsonDocument<256> response;
  response["type"] = "response";
  response["device_id"] = DEVICE_ID;
  response["success"] = false;
  response["message"] = errorMessage;
  response["timestamp"] = millis();
  
  String responseStr;
  serializeJson(response, responseStr);
  Serial.println(responseStr);
}

void sendStatusMessage(String message) {
  StaticJsonDocument<256> status;
  status["type"] = "status";
  status["device_id"] = DEVICE_ID;
  status["message"] = message;
  status["timestamp"] = millis();
  
  String statusStr;
  serializeJson(status, statusStr);
  Serial.println(statusStr);
} 