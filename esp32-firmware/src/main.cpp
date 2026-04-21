// PetGuard Pro v5.3

#include <Preferences.h>
#include <Arduino.h>
#include <Wire.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <FirebaseESP32.h>
#include <ArduinoJson.h>
#include <TinyGPSPlus.h>
#include <MPU6050.h>
#include <Adafruit_MLX90614.h>
#include "MAX30105.h"
#include "heartRate.h"
#include "spo2_algorithm.h"
#include "config.h"

//  Firebase Objects
FirebaseData   fbData;
FirebaseAuth   fbAuth;
FirebaseConfig fbConfig;

//  Flash Buffer (Offline Cache)
Preferences flash;
const char* FLASH_NAMESPACE  = "petguard";
const char* FLASH_GPS_KEY    = "gps_queue";
const char* FLASH_HEALTH_KEY = "health_queue";
const int   MAX_FLASH_BYTES  = 8000;

void saveToFlash(const char* key, const String& jsonStr) {
    String existing = "";
    if (flash.isKey(key)) existing = flash.getString(key, "");
    if (existing.length() + jsonStr.length() > MAX_FLASH_BYTES) {
        int firstNewline = existing.indexOf('\n');
        if (firstNewline != -1) {
            existing = existing.substring(firstNewline + 1);
            Serial.println("Flash buffer full — dropped oldest entry");
        } else {
            existing = "";
        }
    }
    existing += jsonStr + "\n";
    flash.putString(key, existing);
    Serial.printf("Saved to flash [%s] — cache now %d bytes\n",
        key, existing.length());
}

void syncBuffer(const char* key, const String& basePath) {
    if (!flash.isKey(key)) return;
    String data = flash.getString(key, "");
    if (data.length() == 0) return;
    Serial.printf("Syncing flash [%s] — %d bytes\n", key, data.length());
    int synced = 0;
    int start  = 0;
    int end;
    while ((end = data.indexOf('\n', start)) != -1) {
        String entry = data.substring(start, end);
        if (entry.length() > 10) {
            FirebaseJson json;
            json.setJsonData(entry);
            String path = basePath + "/" + String(millis() + synced);
            if (Firebase.pushJSON(fbData, path, json)) {
                synced++;
                Serial.printf("  Synced entry %d\n", synced);
            } else {
                Serial.println("  Sync failed — keeping remaining entries");
                flash.putString(key, data.substring(start));
                return;
            }
        }
        start = end + 1;
    }
    flash.putString(key, "");
    Serial.printf("Flash [%s] cleared — synced %d entries\n", key, synced);
}

void syncAllFlashBuffers() {
    bool hasGPS    = flash.isKey(FLASH_GPS_KEY) &&
                     flash.getString(FLASH_GPS_KEY, "").length() > 0;
    bool hasHealth = flash.isKey(FLASH_HEALTH_KEY) &&
                     flash.getString(FLASH_HEALTH_KEY, "").length() > 0;
    if (!hasGPS && !hasHealth) return;
    Serial.println("--- Syncing flash buffers ---");
    syncBuffer(FLASH_GPS_KEY,
               "pets/" + String(PET_ID) + "/location_history");
    syncBuffer(FLASH_HEALTH_KEY,
               "pets/" + String(PET_ID) + "/health_history");
    Serial.println("--- Flash sync complete ---");
}

bool safeFirebaseSet(const String& path, FirebaseJson& json,
                     bool cacheable = false,
                     const char* cacheKey = nullptr) {
    if (Firebase.setJSON(fbData, path, json)) {
        return true;
    }
    Serial.println("Firebase failed: " + fbData.errorReason());
    if (cacheable && cacheKey != nullptr) {
        saveToFlash(cacheKey, json.raw());
    } else {
        Serial.println("Data not cached (non-critical)");
    }
    return false;
}

//  Objects
MPU6050           mpu;
MAX30105          particleSensor;
Adafruit_MLX90614 mlx;
HardwareSerial    gpsSerial(2);
TinyGPSPlus       gps;

// ── Heart Rate State ──────────────────────────────────────────────────────────
const byte RATE_SIZE = 8;
byte  rates[RATE_SIZE];
byte  rateSpot       = 0;
long  lastBeat       = 0;
float beatsPerMinute = 0;
int   beatAvg        = 0;
int   stableCount    = 0;
const int STABILITY_THRESHOLD = 5;

// ── SpO2 State ────────────────────────────────────────────────────────────────
#define SPO2_BUFFER_LENGTH 100
uint32_t irBuffer[SPO2_BUFFER_LENGTH];
uint32_t redBuffer[SPO2_BUFFER_LENGTH];
int32_t  spo2Value       = 0;
int8_t   validSPO2       = 0;
int32_t  hrFromSpo2      = 0;
int8_t   validHR         = 0;
byte     spo2BufferIndex = 0;
bool     spo2BufferFull  = false;

// Last known good SpO2 — persists across buffer resets and finger removal
// so Firebase is never overwritten with a blank value
int lastValidSpo2 = 0;

// ── Finger contact tracking for fallback health push ─────────────────────────
unsigned long fingerContactStartMs = 0;
bool          fingerWasOn          = false;

//  IMU / Activity State
int     stepCount          = 0;
double  lastMagnitude      = 0;
bool    stepPeak           = false;
double  totalActiveMinutes = 0.0;
bool    wasActive          = false;
unsigned long activeStartMs = 0;

//  Timers
unsigned long lastCurrentUpdate = 0;
unsigned long lastHistorySave   = 0;
unsigned long lastHealthPush    = 0;
unsigned long lastGpsPush       = 0;
unsigned long lastSensorRead    = 0;
unsigned long lastFlashSync     = 0;
const unsigned long SENSOR_READ_INTERVAL = 20;
const unsigned long FLASH_SYNC_INTERVAL  = 30000;

//  WiFi
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
        Serial.println(String("\nWiFi connected: ") + WiFi.localIP().toString());
    } else {
        Serial.println("\nWiFi failed. Will retry in loop.");
    }
}

//  Firebase
void connectFirebase() {
    fbConfig.host                       = FIREBASE_HOST;
    fbConfig.signer.tokens.legacy_token = FIREBASE_AUTH;
    fbConfig.timeout.serverResponse     = 10000;
    Firebase.begin(&fbConfig, &fbAuth);
    Firebase.reconnectWiFi(true);
    fbData.setResponseSize(4096);
    Serial.println("Firebase initialized!");
}

//  Timestamps
String getTimestampDashed() {
    struct tm timeinfo;
    if (!getLocalTime(&timeinfo)) return "unknown";
    char buf[30];
    strftime(buf, sizeof(buf), "%Y-%m-%dT%H-%M-%S", &timeinfo);
    return String(buf);
}

String getISOTimestamp() {
    struct tm timeinfo;
    if (!getLocalTime(&timeinfo))
        return "2026-01-01T00:00:00.000+05:30";
    char buf[35];
    strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%S.000+05:30", &timeinfo);
    return String(buf);
}

unsigned long getUnixTimestampMs() {
    time_t now;
    time(&now);
    return (unsigned long)now * 1000UL;
}

//  GPS Helpers
float getAccuracy(float hdop) {
    float accuracy = hdop * 2.0f;
    if (accuracy < 2.0f)  accuracy = 2.0f;
    if (accuracy > 50.0f) accuracy = 50.0f;
    return accuracy;
}

//  Activity Classification
String classifyActivity(double magnitude) {
    if (magnitude > THRESHOLD_IMPACT)  return "impact";
    if (magnitude > THRESHOLD_RUNNING) return "running";
    if (magnitude > THRESHOLD_WALKING) return "walking";
    if (magnitude > THRESHOLD_PLAYING) return "playing";
    return "resting";
}

bool isActiveActivity(const String& activity) {
    return (activity == "walking" ||
            activity == "running" ||
            activity == "playing");
}

void updateStepCount(double magnitude) {
    bool currentPeak = (magnitude > 11.5);
    if (currentPeak && !stepPeak && magnitude > lastMagnitude)
        stepCount++;
    stepPeak      = currentPeak;
    lastMagnitude = magnitude;
}

//  Push Activity — not cached
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
    safeFirebaseSet(path, json, false, nullptr);
}

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
    safeFirebaseSet(path, json, false, nullptr);
}

//  Push Health
// Uses lastValidSpo2 so SpO2 persists in Firebase between buffer cycles
void pushHealth(int heartRate, float temperature) {
    String timestamp = getISOTimestamp();

    FirebaseJson json;
    json.set("heartRate",   heartRate);
    json.set("temperature", temperature);
    json.set("timestamp",   timestamp);

    // Always include SpO2 if we have any valid reading ever recorded
    if (lastValidSpo2 > 0) {
        json.set("spo2", lastValidSpo2);
    }

    String livePath = "pets/" + String(PET_ID) + "/health";
    safeFirebaseSet(livePath, json, false, nullptr);

    String histPath = "pets/" + String(PET_ID) + "/health_history/"
                    + getTimestampDashed();
    safeFirebaseSet(histPath, json, true, FLASH_HEALTH_KEY);
}

//  Push GPS
void pushGPS() {
    if (!gps.location.isValid()) {
        Serial.println("No GPS fix — skipping");
        return;
    }

    String timestamp = getISOTimestamp();
    String id        = String(millis());
    float  hdop      = gps.hdop.hdop();
    float  accuracy  = getAccuracy(hdop);

    FirebaseJson locationJson;
    locationJson.set("latitude",  gps.location.lat());
    locationJson.set("longitude", gps.location.lng());
    locationJson.set("accuracy",  accuracy);
    locationJson.set("timestamp", timestamp);
    locationJson.set("heading",   0.0);

    String currentPath = "pets/" + String(PET_ID) + "/current_location";
    if (safeFirebaseSet(currentPath, locationJson, false, nullptr)) {
        Serial.printf("GPS updated: %.6f, %.6f (HDOP:%.1f -> +/-%.1fm)\n",
            gps.location.lat(), gps.location.lng(), hdop, accuracy);
    }

    FirebaseJson historyJson;
    historyJson.set("id",        id);
    historyJson.set("latitude",  gps.location.lat());
    historyJson.set("longitude", gps.location.lng());
    historyJson.set("accuracy",  accuracy);
    historyJson.set("timestamp", timestamp);

    String historyPath = "pets/" + String(PET_ID) +
                         "/location_history/" + id;
    safeFirebaseSet(historyPath, historyJson, true, FLASH_GPS_KEY);
}

//  Setup
void setup() {
    Serial.begin(115200);
    delay(1000);

    Serial.println("==================================================");
    Serial.println("       PetGuard Pro — Full System Boot v5.3");
    Serial.println("       Health + Activity + GPS + Flash Cache");
    Serial.println("==================================================");

    flash.begin(FLASH_NAMESPACE, false);
    Serial.println("Flash buffer initialized");

    int prevGPS    = 0;
    int prevHealth = 0;
    if (flash.isKey(FLASH_GPS_KEY))
        prevGPS = flash.getString(FLASH_GPS_KEY, "").length();
    if (flash.isKey(FLASH_HEALTH_KEY))
        prevHealth = flash.getString(FLASH_HEALTH_KEY, "").length();

    if (prevGPS > 0 || prevHealth > 0) {
        Serial.println("Cached data found from previous session:");
        Serial.printf("  GPS cache    : %d bytes\n", prevGPS);
        Serial.printf("  Health cache : %d bytes\n", prevHealth);
        Serial.println("Will sync after WiFi connects...");
    } else {
        Serial.println("No cached data from previous session");
    }

    Wire.setClock(100000);
    Wire.begin(21, 22);

    mpu.initialize();
    if (mpu.testConnection()) {
        Serial.println("MPU6050 ready");
    } else {
        Serial.println("MPU6050 not found!");
        while (1) delay(1000);
    }

    // MAX30102 — configured for HR + SpO2 (ledMode=2)
    if (!particleSensor.begin(Wire, I2C_SPEED_STANDARD)) {
        Serial.println("MAX30102 not found!");
        while (1) delay(1000);
    }
    byte ledBrightness = 60;
    byte sampleAverage = 4;
    byte ledMode       = 2;    // 2 = Red + IR (enables SpO2)
    int  sampleRate    = 100;
    int  pulseWidth    = 411;
    int  adcRange      = 4096;
    particleSensor.setup(ledBrightness, sampleAverage, ledMode,
                         sampleRate, pulseWidth, adcRange);
    particleSensor.setPulseAmplitudeGreen(0);
    Serial.println("MAX30102 ready (HR + SpO2 mode)");

    if (!mlx.begin()) {
        Serial.println("MLX90614 not found!");
        while (1) delay(1000);
    }
    Serial.println("MLX90614 ready");

    gpsSerial.begin(9600, SERIAL_8N1, GPS_RX_PIN, GPS_TX_PIN);
    Serial.println("GPS started");

    connectWiFi();

    configTime(19800, 0, "pool.ntp.org",
               "time.google.com", "time.cloudflare.com");
    Serial.print("Waiting for NTP sync");
    struct tm timeinfo;
    int ntpAttempts = 0;
    while (!getLocalTime(&timeinfo) && ntpAttempts < 20) {
        delay(500);
        Serial.print(".");
        ntpAttempts++;
    }
    if (ntpAttempts >= 20) {
        Serial.println("\nNTP sync timed out — continuing anyway");
    } else {
        Serial.println("\nTime synced");
    }

    connectFirebase();

    if (WiFi.status() == WL_CONNECTED) {
        syncAllFlashBuffers();
    }

    activeStartMs = millis();

    Serial.println("==================================================");
    Serial.println("       All systems ready!");
    Serial.println("==================================================");
}

//  Loop
void loop() {
    bool wifiOK = (WiFi.status() == WL_CONNECTED);
    if (!wifiOK) {
        static unsigned long lastReconnect = 0;
        if (millis() - lastReconnect > 10000) {
            lastReconnect = millis();
            Serial.println("WiFi down — attempting reconnect...");
            connectWiFi();
        }
    }

    unsigned long now = millis();

    while (gpsSerial.available() > 0) {
        gps.encode(gpsSerial.read());
    }

    // Read MAX30102 — HR + SpO2 every 20ms
    if (now - lastSensorRead >= SENSOR_READ_INTERVAL) {
        lastSensorRead = now;

        long irValue        = particleSensor.getIR();
        long redValue       = particleSensor.getRed();
        bool fingerDetected = irValue >= 30000;

        if (fingerDetected) {

            // Track when finger first makes contact
            if (!fingerWasOn) {
                fingerContactStartMs = now;
                fingerWasOn          = true;
            }

            // Heart rate detection via checkForBeat()
            if (checkForBeat(irValue)) {
                long delta     = millis() - lastBeat;
                lastBeat       = millis();
                beatsPerMinute = 60 / (delta / 1000.0);

                if (beatsPerMinute < 180 && beatsPerMinute > 20) {
                    rates[rateSpot++] = (byte)beatsPerMinute;
                    rateSpot %= RATE_SIZE;
                    beatAvg = 0;
                    for (byte x = 0; x < RATE_SIZE; x++)
                        beatAvg += rates[x];
                    beatAvg /= RATE_SIZE;
                    stableCount++;
                } else {
                    stableCount = 0;
                }
            }

            // SpO2 — fill rolling buffer with red + IR samples
            irBuffer[spo2BufferIndex]  = (uint32_t)irValue;
            redBuffer[spo2BufferIndex] = (uint32_t)redValue;
            spo2BufferIndex++;

            // Calculate SpO2 once buffer is full (100 samples = ~2 seconds)
            if (spo2BufferIndex >= SPO2_BUFFER_LENGTH) {
                spo2BufferIndex = 0;
                spo2BufferFull  = true;
                maxim_heart_rate_and_oxygen_saturation(
                    irBuffer,  SPO2_BUFFER_LENGTH, redBuffer,
                    &spo2Value, &validSPO2,
                    &hrFromSpo2, &validHR
                );

                // Only accept physiologically plausible SpO2 readings (>= 80%)
                // Values below 80 are almost certainly noise or poor contact
                if (validSPO2 == 1 && spo2Value >= 80) {
                    lastValidSpo2 = (int)spo2Value;
                    Serial.printf("SpO2 updated — last valid: %d%%\n", lastValidSpo2);

                    // CHANGE: Use hrFromSpo2 as BPM fallback when checkForBeat()
                    // hasn't produced a stable beatAvg yet. Both come from the
                    // same buffer so if SpO2 is valid, HR from same calc is usable.
                    if (beatAvg == 0 && validHR == 1
                            && hrFromSpo2 > 20 && hrFromSpo2 < 300) {
                        beatAvg = (int)hrFromSpo2;
                        Serial.printf("BPM fallback from SpO2 algorithm: %d BPM\n",
                            beatAvg);
                    }

                } else if (validSPO2 == 1 && spo2Value < 80) {
                    // Implausible value — reject and keep previous lastValidSpo2
                    Serial.printf("SpO2 rejected — implausible value: %d%%\n",
                        (int)spo2Value);
                }
            }

        } else {
            // Finger removed — reset live sensor state
            // NOTE: lastValidSpo2 intentionally NOT reset here so the last
            // known good value continues to be pushed to Firebase
            fingerWasOn     = false;
            beatAvg         = 0;
            rateSpot        = 0;
            stableCount     = 0;
            spo2BufferIndex = 0;
            spo2BufferFull  = false;
            spo2Value       = 0;
            validSPO2       = 0;
        }
    }

    int16_t rawAx, rawAy, rawAz, rawGx, rawGy, rawGz;
    mpu.getMotion6(&rawAx, &rawAy, &rawAz, &rawGx, &rawGy, &rawGz);

    float ax  = (rawAx / 16384.0f) * 9.81f;
    float ay  = (rawAy / 16384.0f) * 9.81f;
    float az  = (rawAz / 16384.0f) * 9.81f;
    float gxf = rawGx / 131.0f;
    float gyf = rawGy / 131.0f;
    float gzf = rawGz / 131.0f;
    float magnitude = sqrt(ax*ax + ay*ay + az*az);

    String activity       = classifyActivity(magnitude);
    bool   impactDetected = (activity == "impact");
    float  impactSeverity = 0.0f;
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

    // Serial Output (every 1 second)
    static unsigned long lastSerialPrint = 0;
    if (now - lastSerialPrint >= 1000) {
        lastSerialPrint = now;

        float objTemp  = mlx.readObjectTempC();
        float ambTemp  = mlx.readAmbientTempC();
        float hdop     = gps.hdop.hdop();
        float accuracy = getAccuracy(hdop);
        bool  fingerOn = particleSensor.getIR() >= 30000;

        int gpsBytes    = 0;
        int healthBytes = 0;
        if (flash.isKey(FLASH_GPS_KEY))
            gpsBytes    = flash.getString(FLASH_GPS_KEY,    "").length();
        if (flash.isKey(FLASH_HEALTH_KEY))
            healthBytes = flash.getString(FLASH_HEALTH_KEY, "").length();

        struct tm timeinfo;
        getLocalTime(&timeinfo);
        char timeBuf[30];
        strftime(timeBuf, sizeof(timeBuf), "%Y-%m-%d %H:%M:%S", &timeinfo);

        Serial.println("\n==================================================");
        Serial.println("         PETGUARD PRO LIVE DATA PIPELINE");
        Serial.printf ("         %s (Sri Lanka Time)\n", timeBuf);
        Serial.println("==================================================");

        Serial.println("\n[1] GPS Data");
        Serial.println("--------------------------------------------");
        Serial.printf("  Satellites : %d\n",       gps.satellites.value());
        Serial.printf("  HDOP       : %.2f\n",      hdop);
        Serial.printf("  Latitude   : %.6f\n",      gps.location.lat());
        Serial.printf("  Longitude  : %.6f\n",      gps.location.lng());
        Serial.printf("  Accuracy   : +/-%.1f m\n", accuracy);
        Serial.printf("  Fix Valid  : %s\n",
            gps.location.isValid() ? "YES" : "NO — waiting for fix");

        Serial.println("\n[2] Temperature Data (MLX90614)");
        Serial.println("--------------------------------------------");
        Serial.printf("  Object Temp  : %.1f C  (pet body surface)\n", objTemp);
        Serial.printf("  Ambient Temp : %.1f C  (environment)\n",       ambTemp);

        Serial.println("\n[3] Heart Rate + SpO2 + Activity (MAX30102 + MPU6050)");
        Serial.println("--------------------------------------------");
        Serial.printf("  Heart Rate     : %d BPM%s\n",
            beatAvg,
            (beatAvg > 0 && stableCount < STABILITY_THRESHOLD)
                ? "  (fallback from SpO2 algo)" : "");

        // Live SpO2 display
        if (!fingerOn) {
            Serial.println("  SpO2 (live)      : -- (no sensor contact)");
        } else if (!spo2BufferFull) {
            Serial.printf("  SpO2 (live)      : Calibrating... (%d/100 samples)\n",
                spo2BufferIndex);
        } else if (validSPO2 == 1 && spo2Value >= 80) {
            Serial.printf("  SpO2 (live)      : %d%%\n", (int)spo2Value);
        } else if (validSPO2 == 1 && spo2Value < 80) {
            Serial.printf("  SpO2 (live)      : %d%% — rejected (implausible)\n",
                (int)spo2Value);
        } else {
            Serial.println("  SpO2 (live)      : Invalid reading");
        }

        // Always show last valid SpO2 so it's clear what Firebase holds
        if (lastValidSpo2 > 0) {
            Serial.printf("  SpO2 (last valid): %d%%  <-- sent to Firebase\n",
                lastValidSpo2);
        } else {
            Serial.println("  SpO2 (last valid): none yet");
        }

        Serial.printf("  Sensor Contact : %s\n", fingerOn ? "YES" : "NO");
        Serial.printf("  Activity       : %s\n",        activity.c_str());
        Serial.printf("  Magnitude      : %.2f m/s2\n", magnitude);
        Serial.printf("  Step Count     : %d\n",        stepCount);
        Serial.printf("  Active Minutes : %.1f min\n",  totalActiveMinutes);
        if (impactDetected) {
            Serial.printf("  IMPACT! Severity: %.1f/10\n", impactSeverity);
        }

        Serial.println("\n[4] Data Sent to Firebase");
        Serial.println("--------------------------------------------");
        if (gps.location.isValid()) {
            Serial.println("  Path: pets/" + String(PET_ID) +
                           "/current_location");
            Serial.printf ("    latitude   : %.6f\n",  gps.location.lat());
            Serial.printf ("    longitude  : %.6f\n",  gps.location.lng());
            Serial.printf ("    accuracy   : %.1f m\n", accuracy);
        } else {
            Serial.println("  GPS: No fix — NOT sent to Firebase");
        }
        Serial.println("  Path: pets/" + String(PET_ID) + "/health");
        Serial.printf ("    heartRate  : %d BPM\n",  beatAvg);
        Serial.printf ("    temperature: %.1f C\n",   objTemp);
        if (lastValidSpo2 > 0) {
            Serial.printf("    spo2       : %d%%  (last valid)\n", lastValidSpo2);
        } else {
            Serial.println("    spo2       : not yet available");
        }
        Serial.println("  Path: pets/" + String(PET_ID) +
                       "/activity/current");
        Serial.printf ("    activity   : %s\n",   activity.c_str());
        Serial.printf ("    steps      : %d\n",   stepCount);
        Serial.println("  Timestamp    : " + getISOTimestamp());

        Serial.println("\n[5] Flash Cache Status");
        Serial.println("--------------------------------------------");
        Serial.printf("  GPS cache    : %d bytes%s\n",
            gpsBytes,
            gpsBytes > 0 ? "  <-- PENDING SYNC" : "");
        Serial.printf("  Health cache : %d bytes%s\n",
            healthBytes,
            healthBytes > 0 ? "  <-- PENDING SYNC" : "");
        Serial.printf("  WiFi         : %s\n",
            wifiOK ? "Connected" : "DISCONNECTED — data being cached");
        Serial.println("==================================================");
    }

    //  Firebase Pushes
    if (now - lastCurrentUpdate >= CURRENT_UPDATE_INTERVAL_MS) {
        lastCurrentUpdate = now;
        pushCurrentActivity(activity, ax, ay, az, gxf, gyf, gzf,
                            magnitude, impactDetected, impactSeverity);
    }

    if (now - lastHistorySave >= HISTORY_SAVE_INTERVAL_MS) {
        lastHistorySave = now;
        saveActivityHistory(activity, ax, ay, az, gxf, gyf, gzf,
                            magnitude, impactDetected, impactSeverity);
    }

    // Health push — stable normal operation OR fallback after 10s contact
    // Normal:   stableCount >= 5 && beatAvg > 0  → reliable stable reading
    // Fallback: sensor on for 10s but HR still unstable → push anyway so app can alert
    bool stableReading          = (stableCount >= STABILITY_THRESHOLD && beatAvg > 0);
    bool sensorContactConfirmed = (fingerWasOn &&
                                  (now - fingerContactStartMs > 10000));

    if ((stableReading || sensorContactConfirmed)
            && (now - lastHealthPush >= HEALTH_PUSH_INTERVAL_MS)) {
        lastHealthPush = now;
        float temperature = mlx.readObjectTempC();
        Serial.printf("Pushing Health — BPM: %d  Temp: %.1fC  SpO2: %s  Reason: %s\n",
            beatAvg, temperature,
            lastValidSpo2 > 0 ? (String(lastValidSpo2) + "%").c_str() : "N/A",
            stableReading ? "stable" : "fallback(10s contact)");
        pushHealth(beatAvg, temperature);
    }

    if (now - lastGpsPush >= GPS_PUSH_INTERVAL_MS) {
        lastGpsPush = now;
        pushGPS();
    }

    if (wifiOK && now - lastFlashSync >= FLASH_SYNC_INTERVAL) {
        lastFlashSync = now;
        syncAllFlashBuffers();
    }

    if (impactDetected) {
        Serial.println("IMPACT! Pushing immediately...");
        pushCurrentActivity(activity, ax, ay, az, gxf, gyf, gzf,
                            magnitude, impactDetected, impactSeverity);
        saveActivityHistory(activity, ax, ay, az, gxf, gyf, gzf,
                            magnitude, impactDetected, impactSeverity);
        delay(3000);
    }
}
