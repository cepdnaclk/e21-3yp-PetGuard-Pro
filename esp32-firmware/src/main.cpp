#include <Arduino.h>
#include <Wire.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <FirebaseESP32.h>
#include <ArduinoJson.h>
#include <TinyGPSPlus.h>
#include <MPU6050.h>
#include <Adafruit_MLX90614.h> // <-- Added MLX90614 Library
#include "MAX30105.h"
#include "heartRate.h"
#include "config.h"

// ─────────────────────────────────────────
//  Objects
// ─────────────────────────────────────────
MPU6050          mpu;
MAX30105         particleSensor;
Adafruit_MLX90614 mlx;         // <-- Added MLX90614 Object
HardwareSerial   gpsSerial(2);
TinyGPSPlus      gps;
FirebaseData     fbData;
FirebaseAuth     fbAuth;
FirebaseConfig   fbConfig;

// ─────────────────────────────────────────
//  Heart Rate State
// ─────────────────────────────────────────
const byte RATE_SIZE = 8;
byte  rates[RATE_SIZE];
byte  rateSpot        = 0;
long  lastBeat        = 0;
float beatsPerMinute  = 0;
int   beatAvg         = 0;
int   stableCount     = 0;
const int STABILITY_THRESHOLD = 5;

// ─────────────────────────────────────────
//  IMU / Activity State
// ─────────────────────────────────────────
int     stepCount          = 0;
double  lastMagnitude      = 0;
bool    stepPeak           = false;
double  totalActiveMinutes = 0.0;
bool    wasActive          = false;
unsigned long activeStartMs = 0;

// ─────────────────────────────────────────
//  Timers
// ─────────────────────────────────────────
unsigned long lastCurrentUpdate = 0;
unsigned long lastHistorySave   = 0;
unsigned long lastHealthPush    = 0;
unsigned long lastGpsPush       = 0;
unsigned long lastSensorRead = 0;
const unsigned long SENSOR_READ_INTERVAL = 20;

// ─────────────────────────────────────────
//  WiFi
// ─────────────────────────────────────────
void connectWiFi() {
  Serial.print("Connecting to WiFi");
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n✅ WiFi connected: " + WiFi.localIP().toString());
  } else {
    Serial.println("\n❌ WiFi failed. Will retry in loop.");
  }
}

// ─────────────────────────────────────────
//  Firebase
// ─────────────────────────────────────────
void connectFirebase() {
  fbConfig.host                       = FIREBASE_HOST;
  fbConfig.signer.tokens.legacy_token = FIREBASE_AUTH;
  Firebase.begin(&fbConfig, &fbAuth);
  Firebase.reconnectWiFi(true);
  fbData.setResponseSize(4096);
  Serial.println("✅ Firebase initialized!");
}

// ─────────────────────────────────────────
//  Timestamps
// ─────────────────────────────────────────
String getTimestampDashed() {
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) return "unknown";
  char buf[25];
  strftime(buf, sizeof(buf), "%Y-%m-%dT%H-%M-%S", &timeinfo);
  return String(buf);
}

String getISOTimestamp() {
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) return "2026-01-01T00:00:00.000Z";
  char buf[30];
  strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%S.000Z", &timeinfo);
  return String(buf);
}

unsigned long getUnixTimestampMs() {
  time_t now;
  time(&now);
  return (unsigned long)now * 1000UL;
}

// ─────────────────────────────────────────
//  GPS Helpers
// ─────────────────────────────────────────
float getAccuracy(int satellites) {
  if (satellites >= 10) return 5.0;
  if (satellites >= 7)  return 10.0;
  if (satellites >= 4)  return 20.0;
  return 50.0;
}

// ─────────────────────────────────────────
//  Activity Classification (IMU)
// ─────────────────────────────────────────
String classifyActivity(double magnitude) {
  if (magnitude > THRESHOLD_IMPACT)  return "impact";
  if (magnitude > THRESHOLD_RUNNING) return "running";
  if (magnitude > THRESHOLD_WALKING) return "walking";
  if (magnitude > THRESHOLD_PLAYING) return "playing";
  return "resting";
}

bool isActiveActivity(const String& activity) {
  return (activity == "walking" || activity == "running" || activity == "playing");
}

void updateStepCount(double magnitude) {
  bool currentPeak = (magnitude > 11.5);
  if (currentPeak && !stepPeak && magnitude > lastMagnitude) stepCount++;
  stepPeak      = currentPeak;
  lastMagnitude = magnitude;
}

// ─────────────────────────────────────────
//  Push Activity (current node)
// ─────────────────────────────────────────
void pushCurrentActivity(
    const String& activityType,
    float ax, float ay, float az,
    float gx, float gy, float gz,
    float magnitude,
    bool  impactDetected,
    float impactSeverity) {

  FirebaseJson json;
  json.set("activity_type",   activityType);
  json.set("magnitude",       magnitude);
  json.set("impact_detected", impactDetected);
  json.set("impact_severity", impactSeverity);
  json.set("timestamp",       (int)getUnixTimestampMs());
  json.set("step_count",      stepCount);
  json.set("active_minutes",  totalActiveMinutes);

  FirebaseJson accel;
  accel.set("x", ax); accel.set("y", ay); accel.set("z", az);
  json.set("accelerometer", accel);

  FirebaseJson gyro;
  gyro.set("x", gx); gyro.set("y", gy); gyro.set("z", gz);
  json.set("gyroscope", gyro);

  String path = "pets/" + String(PET_ID) + "/activity/current";
  if (Firebase.setJSON(fbData, path, json)) {
    Serial.println("✅ Activity current: " + activityType);
  } else {
    Serial.println("❌ Activity current failed: " + fbData.errorReason());
  }
}

// ─────────────────────────────────────────
//  Save Activity History
// ─────────────────────────────────────────
void saveActivityHistory(
    const String& activityType,
    float ax, float ay, float az,
    float gx, float gy, float gz,
    float magnitude,
    bool  impactDetected,
    float impactSeverity) {

  FirebaseJson json;
  json.set("activity_type",   activityType);
  json.set("magnitude",       magnitude);
  json.set("impact_detected", impactDetected);
  json.set("impact_severity", impactSeverity);
  json.set("timestamp",       (int)getUnixTimestampMs());
  json.set("step_count",      stepCount);
  json.set("active_minutes",  totalActiveMinutes);

  FirebaseJson accel;
  accel.set("x", ax); accel.set("y", ay); accel.set("z", az);
  json.set("accelerometer", accel);

  FirebaseJson gyro;
  gyro.set("x", gx); gyro.set("y", gy); gyro.set("z", gz);
  json.set("gyroscope", gyro);

  String path = "pets/" + String(PET_ID) + "/activity/history/"
              + String(getUnixTimestampMs());
  if (Firebase.setJSON(fbData, path, json)) {
    Serial.println("📝 Activity history saved");
  } else {
    Serial.println("❌ Activity history failed: " + fbData.errorReason());
  }
}

// ─────────────────────────────────────────
//  Push Health (heart rate + temperature)
// ─────────────────────────────────────────
void pushHealth(int heartRate, float temperature) {
  String timestamp = getTimestampDashed();

  FirebaseJson json;
  json.set("heartRate",   heartRate);
  json.set("temperature", temperature);
  json.set("timestamp",   timestamp);

  String livePath = "pets/" + String(PET_ID) + "/health";
  if (Firebase.setJSON(fbData, livePath, json)) {
    Serial.println("✅ Live health updated");
  } else {
    Serial.println("❌ Live health failed: " + fbData.errorReason());
  }

  String historyPath = "pets/" + String(PET_ID) + "/health_history/" + timestamp;
  if (Firebase.setJSON(fbData, historyPath, json)) {
    Serial.println("✅ Health history pushed");
  } else {
    Serial.println("❌ Health history failed: " + fbData.errorReason());
  }
}

// ─────────────────────────────────────────
//  Push GPS
// ─────────────────────────────────────────
void pushGPS() {
  if (!gps.location.isValid()) {
    Serial.println("⚠️  No GPS fix — skipping");
    return;
  }

  String timestamp = getISOTimestamp();
  String id        = String(millis());
  float  accuracy  = getAccuracy(gps.satellites.value());

  FirebaseJson locationJson;
  locationJson.set("latitude",  gps.location.lat());
  locationJson.set("longitude", gps.location.lng());
  locationJson.set("accuracy",  accuracy);
  locationJson.set("timestamp", timestamp);
  locationJson.set("heading",   0.0);

  String currentPath = "pets/" + String(PET_ID) + "/current_location";
  if (Firebase.setJSON(fbData, currentPath, locationJson)) {
    Serial.printf("✅ GPS updated: %.6f, %.6f\n",
      gps.location.lat(), gps.location.lng());
  } else {
    Serial.println("❌ GPS current failed: " + fbData.errorReason());
  }

  FirebaseJson historyJson;
  historyJson.set("id",        id);
  historyJson.set("latitude",  gps.location.lat());
  historyJson.set("longitude", gps.location.lng());
  historyJson.set("accuracy",  accuracy);
  historyJson.set("timestamp", timestamp);

  String historyPath = "pets/" + String(PET_ID) + "/location_history/" + id;
  if (Firebase.setJSON(fbData, historyPath, historyJson)) {
    Serial.println("✅ GPS history saved");
  } else {
    Serial.println("❌ GPS history failed: " + fbData.errorReason());
  }
}

// ─────────────────────────────────────────
//  Setup
// ─────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println("==================================");
  Serial.println("  PetGuard Pro — Full Integration");
  Serial.println("  Health + Activity + GPS");
  Serial.println("==================================");

  // ── I2C (MPU6050 + MAX30102 + MLX90614 share the bus) ──
  Wire.setClock(100000);  // 100kHz standard mode
  Wire.begin(21, 22);

  // ── MPU6050 ──
  mpu.initialize();
  if (mpu.testConnection()) {
    Serial.println("✅ MPU6050 ready");
  } else {
    Serial.println("❌ MPU6050 not found. Check wiring!");
    while (1) delay(1000);
  }

// ── MAX30102 ──
  // CHANGED: Must use I2C_SPEED_STANDARD (100kHz) so the MLX90614 doesn't crash!
  if (!particleSensor.begin(Wire, I2C_SPEED_STANDARD)) {
    Serial.println("❌ MAX30102 not found. Check wiring!");
    while (1) delay(1000);
  }
  particleSensor.setup();
  particleSensor.setPulseAmplitudeRed(0x0A);
  particleSensor.setPulseAmplitudeGreen(0);
  Serial.println("✅ MAX30102 ready");

  // ── MLX90614 ──  <-- Added Setup check
  if (!mlx.begin()) {
    Serial.println("❌ MLX90614 not found. Check wiring!");
    while (1) delay(1000);
  }
  Serial.println("✅ MLX90614 ready");

  // ── GPS ──
  gpsSerial.begin(9600, SERIAL_8N1, GPS_RX_PIN, GPS_TX_PIN);
  Serial.println("✅ GPS started");

  // ── WiFi ──
  connectWiFi();

  // ── NTP (UTC+5:30 for Sri Lanka) ──
  configTime(19800, 0, "pool.ntp.org");
  Serial.print("⏳ Waiting for NTP sync");
  struct tm timeinfo;
  while (!getLocalTime(&timeinfo)) { delay(500); Serial.print("."); }
  Serial.println("\n✅ Time synced");

  // ── Firebase ──
  connectFirebase();

  activeStartMs = millis();

  Serial.println("==================================");
  Serial.println("  All systems ready!");
  Serial.println("==================================");
}

// ─────────────────────────────────────────
//  Loop
// ─────────────────────────────────────────
// ─────────────────────────────────────────
//  Loop
// ─────────────────────────────────────────
void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("⚠️  WiFi dropped, reconnecting...");
    connectWiFi();
    return;
  }

  unsigned long now = millis();

  // ── Feed GPS ──
  while (gpsSerial.available() > 0) {
    gps.encode(gpsSerial.read());
  }

  // ── Read MAX30102 ──
  if (now - lastSensorRead >= SENSOR_READ_INTERVAL) {
    lastSensorRead = now;

    long irValue = particleSensor.getIR();
    bool fingerDetected = irValue >= 30000;

    // Removed the spammy Serial.printf("IR Value: %ld\n", irValue); here

    if (fingerDetected && checkForBeat(irValue)) {
      long delta = millis() - lastBeat;
      lastBeat = millis();
      beatsPerMinute = 60 / (delta / 1000.0);

      if (beatsPerMinute < 180 && beatsPerMinute > 20) {
        rates[rateSpot++] = (byte)beatsPerMinute;
        rateSpot %= RATE_SIZE;
        beatAvg = 0;
        for (byte x = 0; x < RATE_SIZE; x++) beatAvg += rates[x];
        beatAvg /= RATE_SIZE;
        stableCount++;
      } else {
        stableCount = 0;
      }
    }

    if (!fingerDetected) {
      beatAvg     = 0;
      rateSpot    = 0;
      stableCount = 0;
    }
  }

  // ── Read MPU6050 ──
  int16_t rawAx, rawAy, rawAz, rawGx, rawGy, rawGz;
  mpu.getMotion6(&rawAx, &rawAy, &rawAz, &rawGx, &rawGy, &rawGz);

  float ax = (rawAx / 16384.0f) * 9.81f;
  float ay = (rawAy / 16384.0f) * 9.81f;
  float az = (rawAz / 16384.0f) * 9.81f;
  float gx = rawGx / 131.0f;
  float gy = rawGy / 131.0f;
  float gz = rawGz / 131.0f;
  float magnitude = sqrt(ax*ax + ay*ay + az*az);

  // ── Activity Classification ──
  String activity = classifyActivity(magnitude);
  bool  impactDetected = (activity == "impact");
  float impactSeverity = 0.0f;
  if (impactDetected) {
    impactSeverity = ((magnitude - THRESHOLD_IMPACT) / 5.0f) * 10.0f;
    if (impactSeverity > 10.0f) impactSeverity = 10.0f;
  }

  updateStepCount(magnitude);

  bool currentlyActive = isActiveActivity(activity);
  if (currentlyActive && !wasActive) {
    activeStartMs = millis();
  } else if (!currentlyActive && wasActive) {
    totalActiveMinutes += (millis() - activeStartMs) / 60000.0;
  }
  wasActive = currentlyActive;

  // ── Clean Serial Output (Every 1 Second) ──
  static unsigned long lastSerialPrint = 0;
  if (now - lastSerialPrint >= 1000) {
    lastSerialPrint = now;
    
    float objTemp = mlx.readObjectTempC();
    float ambTemp = mlx.readAmbientTempC();
    bool fingerDetected = particleSensor.getIR() >= 30000;

    Serial.println("---------------------------------------------------------");
    Serial.printf("🏃 Activity : %-8s | Mag: %5.2f | Steps: %d\n", activity.c_str(), magnitude, stepCount);
    Serial.printf("❤️  Heart    : %3d BPM  | Sensor Contact: %s\n", beatAvg, (fingerDetected ? "YES" : "NO"));
    Serial.printf("🌡️  Temp     : Obj: %.1f°C | Amb: %.1f°C\n", objTemp, ambTemp);
    Serial.printf("🌍 GPS      : Sats: %d | Lat: %.6f | Lng: %.6f\n", gps.satellites.value(), gps.location.lat(), gps.location.lng());
    Serial.println("---------------------------------------------------------");
  }

  // ── Firebase pushes ──
  if (now - lastCurrentUpdate >= CURRENT_UPDATE_INTERVAL_MS) {
    lastCurrentUpdate = now;
    pushCurrentActivity(activity, ax, ay, az, gx, gy, gz,
                        magnitude, impactDetected, impactSeverity);
  }

  if (now - lastHistorySave >= HISTORY_SAVE_INTERVAL_MS) {
    lastHistorySave = now;
    saveActivityHistory(activity, ax, ay, az, gx, gy, gz,
                        magnitude, impactDetected, impactSeverity);
  }

  // ── HEALTH PUSH ──
  if (stableCount >= STABILITY_THRESHOLD && beatAvg > 0
      && (now - lastHealthPush >= HEALTH_PUSH_INTERVAL_MS)) {
    lastHealthPush = now;
    
    float temperature = mlx.readObjectTempC(); 
    Serial.printf("📤 Pushing Health to Firebase — BPM: %d  Temp: %.1f°C\n", beatAvg, temperature);
    pushHealth(beatAvg, temperature);
  }

  if (now - lastGpsPush >= GPS_PUSH_INTERVAL_MS) {
    lastGpsPush = now;
    pushGPS();
  }

  if (impactDetected) {
    Serial.println("⚠️  IMPACT! Pushing immediately...");
    pushCurrentActivity(activity, ax, ay, az, gx, gy, gz,
                        magnitude, impactDetected, impactSeverity);
    saveActivityHistory(activity, ax, ay, az, gx, gy, gz,
                        magnitude, impactDetected, impactSeverity);
    delay(3000); // Debounce impact
  }
}