#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>

// Pin Definitions for ESP32-C3
const int WATER_LEVEL_TRIG_PIN = 2;
const int WATER_LEVEL_ECHO_PIN = 3;
const int PUMP_CONTROL_PIN     = 4;

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

void sendResponse(String method, String requestId, String result) {
  String respTopic = String(device_id) + "/" + method + "/response/" + requestId;
  StaticJsonDocument<128> resp;
  resp["requestId"] = requestId;
  resp["result"] = result;
  String out;
  serializeJson(resp, out);
  client.publish(respTopic.c_str(), out.c_str());
  Serial.printf("Published response to %s: %s\n", respTopic.c_str(), out.c_str());
}

// ---------------- MQTT CALLBACK ----------------
void mqtt_callback(char* topic, byte* payload, unsigned int length) {
  String msg;
  for (unsigned int i = 0; i < length; i++) msg += (char)payload[i];
  Serial.printf("Message [%s]: %s\n", topic, msg.c_str());

  // Parse JSON
  StaticJsonDocument<256> doc;
  DeserializationError err = deserializeJson(doc, msg);
  if (err) {
    Serial.println("JSON parse failed");
    return;
  }

  String requestId = doc["requestId"] | "";
  JsonObject params = doc["params"];
  String t = String(topic);

  // ---- Pump Run ----
  if (t.endsWith("/pump/run")) {
    int sec = params["duration"] | 0;
    if (sec >= 5 && sec <= 60 && pump.startManualPump(sec)) {
      sendResponse("pump", requestId, String("PUMP_STARTED:") + sec);
    } else {
      sendResponse("pump", requestId, "PUMP_NOT_STARTED");
    }
  }

  // ---- Bucket Get ----
  else if (t.endsWith("/bucket/get")) {
    float dist = bucket.getAverageDistance(5);
    int percent = constrain(map((int)dist,
                                WATER_LEVEL_EMPTY_THRESHOLD_CM,
                                WATER_LEVEL_FULL_THRESHOLD_CM,
                                0, 100), 0, 100);
    String status = String(percent) + ":" + bucket.getBucketLevelStatus();
    sendResponse("bucket", requestId, status);
  }

  // ---- WiFi Get ----
  else if (t.endsWith("/wifi/get")) {
    String wifiStatus = (WiFi.status() == WL_CONNECTED)
                        ? String(WiFi.RSSI()) + " dBm"
                        : "DISCONNECTED";
    sendResponse("wifi", requestId, wifiStatus);
  }

  // ---- Pump State ----
  else if (t.endsWith("/pump/get")) {
    String stateMsg = (pump.state == Pump::PUMP_OFF) ? "PUMP_OFF" : "PUMP_RUNNING_MANUAL";
    sendResponse("pump", requestId, stateMsg);
  }

  // ---- Config Name ----
  else if (t.endsWith("/config/name")) {
    String newName = params["name"] | "unknown";
    friendly_name = newName;
    sendResponse("config", requestId, String("NAME_SET:") + friendly_name);
    announceDevice();
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
    } else {
      Serial.print("failed, rc=");
      Serial.print(client.state());
      Serial.println(" try again in 5 seconds");
      delay(5000);

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

  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi Disconnected. Attempting to reconnect...");
    setup_wifi();
  }

  delay(10);
}
