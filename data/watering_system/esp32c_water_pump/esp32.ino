#include <WiFi.h>
#include <PubSubClient.h>

// Pin Definitions for ESP32-C3
const int WATER_LEVEL_TRIG_PIN = 2;
const int WATER_LEVEL_ECHO_PIN = 3;
const int PUMP_CONTROL_PIN = 4;

// Water Level Thresholds
const int WATER_LEVEL_EMPTY_THRESHOLD_CM = 40;
const int WATER_LEVEL_LOW_THRESHOLD_CM   = 25;
const int WATER_LEVEL_FULL_THRESHOLD_CM  = 5;

// WiFi and MQTT Configuration
const char* ssid = "praskovci";
const char* password = "maceradi1";
const char* mqtt_server = "raspberrypi";
const int mqtt_port = 1883;

// Globals for device identity
char device_id[32];
String friendly_name = "unknown";

WiFiClient espClient;
PubSubClient client(espClient);

// ---------------- BUCKET CLASS ----------------
class Bucket {
private:
  int _trigPin, _echoPin;
  int _emptyThresholdCm, _lowThresholdCm, _fullThresholdCm;
  float _distanceBeforeWatering;
  
public:
  Bucket(int trig, int echo, int emptyThreshold, int lowThreshold, int fullThreshold)
    : _trigPin(trig), _echoPin(echo),
      _emptyThresholdCm(emptyThreshold), _lowThresholdCm(lowThreshold), _fullThresholdCm(fullThreshold),
      _distanceBeforeWatering(0.0) {}
      
  void begin() {
    pinMode(_trigPin, OUTPUT);
    digitalWrite(_trigPin, LOW);
    pinMode(_echoPin, INPUT);
  }
  
  float getDistanceCm() {
    digitalWrite(_trigPin, LOW);
    delayMicroseconds(2);
    digitalWrite(_trigPin, HIGH);
    delayMicroseconds(10);
    digitalWrite(_trigPin, LOW);
    
    long duration = pulseIn(_echoPin, HIGH, 30000);
    if (duration == 0) return 999.0;
    
    return duration * 0.0343 / 2;
  }
  
  float getAverageDistance(int numProbes) {
    float total = 0;
    int valid = 0;
    for (int i = 0; i < numProbes; i++) {
      float d = getDistanceCm();
      if (d < 999.0) { total += d; valid++; }
      delay(10);
    }
    return valid > 0 ? total / valid : 999.0;
  }
  
  bool isBucketEmpty() {
    return getAverageDistance(5) > _emptyThresholdCm;
  }
  
  String getBucketLevelStatus() {
    float d = getAverageDistance(5);
    if (d >= 999.0) return "UNKNOWN";
    if (d > _emptyThresholdCm) return "EMPTY";
    if (d < _lowThresholdCm) return "LOW";
    if (d <= _fullThresholdCm) return "FULL";
    return "OK";
  }
  
  void recordDistanceBeforeWatering() { _distanceBeforeWatering = getAverageDistance(10); }
  void printWateringChange() {
    float after = getAverageDistance(10);
    float change = _distanceBeforeWatering - after;
    Serial.printf("Watering change: %.2f cm\n", change);
  }
};

// ---------------- PUMP CLASS ----------------
class Pump {
private:
  int _pin;
  unsigned long _startTime, _durationMillis;
  Bucket& _bucket;
  
public:
  enum PumpState { PUMP_OFF, PUMP_RUNNING_MANUAL };
  PumpState state;
  
  Pump(int pin, Bucket& bucketRef) : _pin(pin), _bucket(bucketRef) {
    state = PUMP_OFF;
    _startTime = 0;
    _durationMillis = 0;
  }
  
  void begin() {
    pinMode(_pin, OUTPUT);
    digitalWrite(_pin, LOW);
  }
  
  bool startManualPump(unsigned int seconds) {
    if (state != PUMP_OFF) return false;
    if (_bucket.isBucketEmpty()) return false;
    
    _durationMillis = (unsigned long)seconds * 1000;
    _startTime = millis();
    state = PUMP_RUNNING_MANUAL;
    digitalWrite(_pin, HIGH);
    _bucket.recordDistanceBeforeWatering();
    return true;
  }
  
  void update() {
    if (state == PUMP_RUNNING_MANUAL && millis() - _startTime >= _durationMillis) {
      digitalWrite(_pin, LOW);
      state = PUMP_OFF;
      _bucket.printWateringChange();
      
      // publish stopped status
      String topic = String(device_id) + "/pump/status";
      client.publish(topic.c_str(), "PUMP_STOPPED");
    }
  }
};

// ---------------- GLOBAL OBJECTS ----------------
Bucket bucket(WATER_LEVEL_TRIG_PIN, WATER_LEVEL_ECHO_PIN,
              WATER_LEVEL_EMPTY_THRESHOLD_CM, WATER_LEVEL_LOW_THRESHOLD_CM,
              WATER_LEVEL_FULL_THRESHOLD_CM);
Pump pump(PUMP_CONTROL_PIN, bucket);

// ---------------- HELPERS ----------------
void announceDevice() {
  if (!client.connected()) return;
  String payload = "{ \"id\": \"" + String(device_id) + "\", \"ip\": \"" + WiFi.localIP().toString() +
                   "\", \"name\": \"" + friendly_name + "\" }";
  client.publish("devices/announce", payload.c_str());
  Serial.println("Announced: " + payload);
}

// ---------------- MQTT CALLBACK ----------------
void mqtt_callback(char* topic, byte* payload, unsigned int length) {
  String msg;
  for (unsigned int i = 0; i < length; i++) msg += (char)payload[i];
  Serial.printf("Message [%s]: %s\n", topic, msg.c_str());

  String t = String(topic);

  if (t.endsWith("/pump/run")) {
    int sec = msg.toInt();
    String respTopic = String(device_id) + "/pump/status";
    if (sec >= 5 && sec <= 60) {
      if (pump.startManualPump(sec)) {
        String m = "PUMP_STARTED:" + String(sec);
        client.publish(respTopic.c_str(), m.c_str());
      } else {
        client.publish(respTopic.c_str(), "PUMP_NOT_STARTED");
      }
    } else {
      client.publish(respTopic.c_str(), "INVALID_TIME");
    }
  }
  else if (t.endsWith("/bucket/get")) {
    float dist = bucket.getAverageDistance(5);
    int percent = constrain(map((int)dist, WATER_LEVEL_EMPTY_THRESHOLD_CM,
                                WATER_LEVEL_FULL_THRESHOLD_CM, 0, 100), 0, 100);
    String msg = String(percent) + ":" + bucket.getBucketLevelStatus();
    client.publish((String(device_id) + "/bucket/status").c_str(), msg.c_str());
  }
  else if (t.endsWith("/wifi/get")) {
    String msg = (WiFi.status() == WL_CONNECTED) ? String(WiFi.RSSI()) + " dBm" : "DISCONNECTED";
    client.publish((String(device_id) + "/wifi/status").c_str(), msg.c_str());
  }
  else if (t.endsWith("/pump/get")) {
    String stateMsg = (pump.state == Pump::PUMP_OFF) ? "PUMP_OFF" : "PUMP_RUNNING_MANUAL";
    client.publish((String(device_id) + "/pump/status").c_str(), stateMsg.c_str());
  }
  else if (t.endsWith("/config/name")) {
    friendly_name = msg;
    announceDevice(); // re-announce with new name
  }
}

// ---------------- WIFI + MQTT ----------------
void setup_wifi() {
  WiFi.begin(ssid, password);
  int retries = 0;
  while (WiFi.status() != WL_CONNECTED && retries < 20) {
    delay(500);
    Serial.print(".");
    retries++;
  }
  Serial.println(WiFi.localIP());
}

void reconnect() {
  while (!client.connected()) {
    if (client.connect(device_id)) {
      Serial.println("MQTT connected");
      String base = String(device_id);
      client.subscribe((base + "/pump/run").c_str());
      client.subscribe((base + "/bucket/get").c_str());
      client.subscribe((base + "/wifi/get").c_str());
      client.subscribe((base + "/pump/get").c_str());
      client.subscribe((base + "/config/name").c_str());
      announceDevice();
      Serial.print("Announec device name.");
    } else {
      Serial.print("failed, rc=");
      Serial.print(client.state());
      Serial.println(" try again in 5 seconds");
      delay(5000);
      
      // Check WiFi status
      if (WiFi.status() != WL_CONNECTED) {
        Serial.println("WiFi disconnected during MQTT reconnect attempt. Reconnecting WiFi...");
        setup_wifi();
      }
    }
  }
}

// ---------------- SETUP + LOOP ----------------
void setup() {
  Serial.begin(115200);

  // Build unique device_id
  uint64_t chipid = ESP.getEfuseMac();
  snprintf(device_id, sizeof(device_id), "esp32c3_%04X", (uint16_t)(chipid & 0xFFFF));

  bucket.begin();
  pump.begin();
  setup_wifi();

  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(mqtt_callback);
}

void loop() {
  if (!client.connected()) reconnect();
  client.loop();
  pump.update();

    // Update pump state
  pump.update();
  
  // Check WiFi connection
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi Disconnected. Attempting to reconnect...");
    setup_wifi();
  }
  
  // Publish bucket level every 30 seconds
  static unsigned long lastPublish = 0;
  if (millis() - lastPublish > 30000) {
    float dist = bucket.getAverageDistance(5);
    int percent = constrain(map((int)dist, WATER_LEVEL_EMPTY_THRESHOLD_CM,
                                WATER_LEVEL_FULL_THRESHOLD_CM, 0, 100), 0, 100);
    String msg = String(percent) + ":" + bucket.getBucketLevelStatus();
    client.publish((String(device_id) + "/bucket/status").c_str(), msg.c_str());
    lastPublish = millis();
  }
  
  // Small delay to prevent watchdog issues
  delay(10);
}
