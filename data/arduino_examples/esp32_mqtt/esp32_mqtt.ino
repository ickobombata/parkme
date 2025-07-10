// ESP32 MQTT IoT Device Example
// This example shows how to create a WiFi-connected device for the Home IoT system

#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <DHT.h>

// WiFi credentials
const char* ssid = "your_wifi_ssid";
const char* password = "your_wifi_password";

// MQTT configuration
const char* mqtt_server = "192.168.1.10";  // Your Raspberry Pi IP
const int mqtt_port = 1883;

// Device configuration - MUST match config.yaml
const String DEVICE_ID = "esp32_outdoor";
const String DEVICE_NAME = "ESP32 Outdoor Station";
const String DEVICE_TYPE = "controller";

// Pin definitions
#define DHT_PIN 4
#define DHT_TYPE DHT22
#define PUMP_RELAY_PIN 12
#define LIGHT_RELAY_PIN 13
#define SOIL_MOISTURE_PIN A0
#define STATUS_LED_PIN 2

// Sensor and control objects
DHT dht(DHT_PIN, DHT_TYPE);
WiFiClient espClient;
PubSubClient client(espClient);

// Device state
bool pumpRunning = false;
bool lightOn = false;
unsigned long pumpStartTime = 0;
unsigned long pumpDuration = 0;

// Timing intervals
const unsigned long HEARTBEAT_INTERVAL = 30000; // 30 seconds
const unsigned long SENSOR_INTERVAL = 60000;    // 1 minute
unsigned long lastHeartbeat = 0;
unsigned long lastSensorReading = 0;

void setup() {
  Serial.begin(115200);
  
  // Initialize pins
  pinMode(PUMP_RELAY_PIN, OUTPUT);
  pinMode(LIGHT_RELAY_PIN, OUTPUT);
  pinMode(STATUS_LED_PIN, OUTPUT);
  
  digitalWrite(PUMP_RELAY_PIN, LOW);
  digitalWrite(LIGHT_RELAY_PIN, LOW);
  digitalWrite(STATUS_LED_PIN, HIGH);
  
  // Initialize DHT sensor
  dht.begin();
  
  // Connect to WiFi
  setupWiFi();
  
  // Setup MQTT
  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(callback);
  
  // Connect to MQTT broker
  connectMQTT();
  
  // Send initial status
  sendHeartbeat();
  sendDeviceStatus();
  
  Serial.println("ESP32 IoT Device Ready");
}

void loop() {
  // Maintain MQTT connection
  if (!client.connected()) {
    connectMQTT();
  }
  client.loop();
  
  // Check WiFi connection
  if (WiFi.status() != WL_CONNECTED) {
    setupWiFi();
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
  
  delay(100);
}

void setupWiFi() {
  delay(10);
  Serial.println();
  Serial.print("Connecting to ");
  Serial.println(ssid);
  
  WiFi.begin(ssid, password);
  
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  
  Serial.println("");
  Serial.println("WiFi connected");
  Serial.println("IP address: ");
  Serial.println(WiFi.localIP());
  
  digitalWrite(STATUS_LED_PIN, LOW); // LED on when connected
}

void connectMQTT() {
  while (!client.connected()) {
    Serial.print("Attempting MQTT connection...");
    
    if (client.connect(DEVICE_ID.c_str())) {
      Serial.println("connected");
      
      // Subscribe to command topic
      String commandTopic = "devices/" + DEVICE_ID + "/commands";
      client.subscribe(commandTopic.c_str());
      Serial.println("Subscribed to: " + commandTopic);
      
      // Subscribe to discovery topic
      client.subscribe("system/discovery");
      
    } else {
      Serial.print("failed, rc=");
      Serial.print(client.state());
      Serial.println(" try again in 5 seconds");
      delay(5000);
    }
  }
}

void callback(char* topic, byte* payload, unsigned int length) {
  Serial.print("Message arrived [");
  Serial.print(topic);
  Serial.print("] ");
  
  // Convert payload to string
  String message;
  for (int i = 0; i < length; i++) {
    message += (char)payload[i];
  }
  Serial.println(message);
  
  // Parse JSON message
  StaticJsonDocument<256> doc;
  DeserializationError error = deserializeJson(doc, message);
  
  if (error) {
    Serial.print("JSON parse error: ");
    Serial.println(error.c_str());
    return;
  }
  
  String command = doc["command"];
  
  // Handle system discovery
  if (String(topic) == "system/discovery") {
    sendDiscoveryResponse();
    return;
  }
  
  // Handle device commands
  if (command == "water_start") {
    int duration = doc["parameters"]["duration"] | 5;
    startWatering(duration);
  }
  else if (command == "water_stop") {
    stopWatering();
  }
  else if (command == "light_on") {
    turnLightOn();
  }
  else if (command == "light_off") {
    turnLightOff();
  }
  else if (command == "get_status") {
    sendDeviceStatus();
  }
  else if (command == "get_sensors") {
    sendSensorData();
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
  
  digitalWrite(PUMP_RELAY_PIN, HIGH);
  
  // Send response
  StaticJsonDocument<256> response;
  response["type"] = "response";
  response["device_id"] = DEVICE_ID;
  response["command"] = "water_start";
  response["success"] = true;
  response["message"] = "Watering started for " + String(duration) + " seconds";
  response["timestamp"] = millis();
  
  publishMessage("devices/" + DEVICE_ID + "/response", response);
}

void stopWatering() {
  if (!pumpRunning) {
    sendErrorResponse("Pump is not running");
    return;
  }
  
  pumpRunning = false;
  digitalWrite(PUMP_RELAY_PIN, LOW);
  
  int actualDuration = (millis() - pumpStartTime) / 1000;
  
  // Send response
  StaticJsonDocument<256> response;
  response["type"] = "response";
  response["device_id"] = DEVICE_ID;
  response["command"] = "water_stop";
  response["success"] = true;
  response["message"] = "Watering stopped after " + String(actualDuration) + " seconds";
  response["timestamp"] = millis();
  
  publishMessage("devices/" + DEVICE_ID + "/response", response);
}

void turnLightOn() {
  lightOn = true;
  digitalWrite(LIGHT_RELAY_PIN, HIGH);
  
  StaticJsonDocument<256> response;
  response["type"] = "response";
  response["device_id"] = DEVICE_ID;
  response["command"] = "light_on";
  response["success"] = true;
  response["message"] = "Light turned on";
  response["timestamp"] = millis();
  
  publishMessage("devices/" + DEVICE_ID + "/response", response);
}

void turnLightOff() {
  lightOn = false;
  digitalWrite(LIGHT_RELAY_PIN, LOW);
  
  StaticJsonDocument<256> response;
  response["type"] = "response";
  response["device_id"] = DEVICE_ID;
  response["command"] = "light_off";
  response["success"] = true;
  response["message"] = "Light turned off";
  response["timestamp"] = millis();
  
  publishMessage("devices/" + DEVICE_ID + "/response", response);
}

void sendHeartbeat() {
  StaticJsonDocument<256> heartbeat;
  heartbeat["type"] = "heartbeat";
  heartbeat["device_id"] = DEVICE_ID;
  heartbeat["status"] = "online";
  heartbeat["timestamp"] = millis();
  heartbeat["pump_running"] = pumpRunning;
  heartbeat["light_on"] = lightOn;
  heartbeat["wifi_rssi"] = WiFi.RSSI();
  heartbeat["free_heap"] = ESP.getFreeHeap();
  
  publishMessage("devices/" + DEVICE_ID + "/status", heartbeat);
}

void sendSensorData() {
  // Read sensors
  float temperature = dht.readTemperature();
  float humidity = dht.readHumidity();
  int soilMoisture = analogRead(SOIL_MOISTURE_PIN);
  float soilMoisturePercent = map(soilMoisture, 0, 4095, 100, 0); // ESP32 ADC is 12-bit
  
  // Create sensor data message
  StaticJsonDocument<512> sensorMsg;
  sensorMsg["type"] = "sensor_data";
  sensorMsg["device_id"] = DEVICE_ID;
  sensorMsg["timestamp"] = millis();
  
  JsonArray readings = sensorMsg.createNestedArray("readings");
  
  if (!isnan(temperature)) {
    JsonObject tempReading = readings.createNestedObject();
    tempReading["sensor_type"] = "temperature";
    tempReading["value"] = temperature;
    tempReading["unit"] = "°C";
    tempReading["timestamp"] = millis();
    tempReading["device_id"] = DEVICE_ID;
  }
  
  if (!isnan(humidity)) {
    JsonObject humidityReading = readings.createNestedObject();
    humidityReading["sensor_type"] = "humidity";
    humidityReading["value"] = humidity;
    humidityReading["unit"] = "%";
    humidityReading["timestamp"] = millis();
    humidityReading["device_id"] = DEVICE_ID;
  }
  
  JsonObject soilReading = readings.createNestedObject();
  soilReading["sensor_type"] = "soil_moisture";
  soilReading["value"] = soilMoisturePercent;
  soilReading["unit"] = "%";
  soilReading["timestamp"] = millis();
  soilReading["device_id"] = DEVICE_ID;
  
  publishMessage("devices/" + DEVICE_ID + "/sensors", sensorMsg);
}

void sendDeviceStatus() {
  StaticJsonDocument<256> status;
  status["type"] = "status";
  status["device_id"] = DEVICE_ID;
  status["status"] = "online";
  status["pump_running"] = pumpRunning;
  status["light_on"] = lightOn;
  status["firmware_version"] = "1.0.0";
  status["uptime"] = millis();
  status["timestamp"] = millis();
  status["ip_address"] = WiFi.localIP().toString();
  status["wifi_rssi"] = WiFi.RSSI();
  
  publishMessage("devices/" + DEVICE_ID + "/status", status);
}

void sendDiscoveryResponse() {
  StaticJsonDocument<512> discovery;
  discovery["type"] = "response";
  discovery["command"] = "discovery";
  discovery["device_info"]["id"] = DEVICE_ID;
  discovery["device_info"]["name"] = DEVICE_NAME;
  discovery["device_info"]["device_type"] = DEVICE_TYPE;
  discovery["device_info"]["firmware_version"] = "1.0.0";
  discovery["device_info"]["ip_address"] = WiFi.localIP().toString();
  discovery["device_info"]["capabilities"].add("water_control");
  discovery["device_info"]["capabilities"].add("light_control");
  discovery["device_info"]["capabilities"].add("temperature_reading");
  discovery["device_info"]["capabilities"].add("humidity_reading");
  discovery["device_info"]["capabilities"].add("soil_moisture_reading");
  discovery["device_info"]["capabilities"].add("status_reporting");
  discovery["timestamp"] = millis();
  
  publishMessage("system/discovery", discovery);
}

void sendErrorResponse(String errorMessage) {
  StaticJsonDocument<256> response;
  response["type"] = "response";
  response["device_id"] = DEVICE_ID;
  response["success"] = false;
  response["message"] = errorMessage;
  response["timestamp"] = millis();
  
  publishMessage("devices/" + DEVICE_ID + "/response", response);
}

void publishMessage(String topic, StaticJsonDocument<256> doc) {
  String message;
  serializeJson(doc, message);
  client.publish(topic.c_str(), message.c_str());
}

void publishMessage(String topic, StaticJsonDocument<512> doc) {
  String message;
  serializeJson(doc, message);
  client.publish(topic.c_str(), message.c_str());
} 