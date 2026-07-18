// PetGuard Pro v6.4 — WiFi + Respiratory Rate

#include <Preferences.h>
#include <Arduino.h>
#include <Wire.h>
#include <ArduinoJson.h>
#include <TinyGPSPlus.h>
#include <MPU6050.h>
#include <Adafruit_MLX90614.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <time.h>
#include "config.h"

// ── WiFi and HTTP Client ──────────────────────────────────────
WiFiClientSecure wifiClient;
HTTPClient httpClient;

// ── GPS Serial ────────────────────────────────────────────────
HardwareSerial gpsSerial(2);   

// ── Flash Buffer (Offline Cache) ──────────────────────────────
Preferences flash;
const char* FLASH_NAMESPACE  = "petguard";
const char* FLASH_GPS_KEY    = "gps_queue";
const char* FLASH_HEALTH_KEY = "health_queue";
const int   MAX_FLASH_BYTES  = 8000;

// ── Objects ───────────────────────────────────────────────────
MPU6050           mpu;
Adafruit_MLX90614 mlx;
TinyGPSPlus       gps;

// ── Buzzer State ──────────────────────────────────────────────
bool          buzzerActive  = false;
unsigned long buzzerOnAt    = 0;
#define       BUZZER_SAFETY_MS  120000

// ── Respiratory Rate State ────────────────────────────────────
// Breath detection uses the accelerometer Z-axis (chest expansion oscillation).
// An EMA smooths out high-frequency motion noise, then we count peaks
// (rising zero-crossings through the baseline with sufficient amplitude)
// over a rolling RESP_WINDOW_MS window.
float         respEma           = 0.0f;
float         respEmaMean       = 0.0f;
bool          respLastAbove     = false;
int           respBreathCount   = 0;
unsigned long respWindowStart   = 0;
int           respiratoryRate   = 0;    // last computed rate (br/min)

// ── IMU / Activity State ──────────────────────────────────────
int           stepCount          = 0;
double        lastMagnitude      = 0;
bool          stepPeak           = false;
double        totalActiveMinutes = 0.0;
bool          wasActive          = false;
unsigned long activeStartMs      = 0;

// ── Timers ────────────────────────────────────────────────────
unsigned long lastCurrentUpdate = 0;
unsigned long lastHistorySave   = 0;
unsigned long lastHealthPush    = 0;
unsigned long lastGpsPush       = 0;
unsigned long lastSensorRead    = 0;
unsigned long lastFlashSync     = 0;
unsigned long lastConnCheck     = 0;
unsigned long lastBuzzerCheck   = 0;

const unsigned long SENSOR_READ_INTERVAL  = 20;
const unsigned long FLASH_SYNC_INTERVAL   = 30000;
const unsigned long CONN_CHECK_INTERVAL   = 30000;
const unsigned long BUZZER_CHECK_INTERVAL = 3000;

// ── Forward Declarations ──────────────────────────────────────
bool syncTimeFromNTP();
String getISOTimestamp();
unsigned long getUnixTimestampMs();
bool firebasePatch(const String& path, const String& jsonBody);
bool firebasePost(const String& path, const String& jsonBody);
String firebaseGet(const String& path);
bool connectWiFi();
bool isWiFiConnected();


// ═══════════════════════════════════════════════════════════════
//  SIMPLIFIED BUZZER - FIREBASE CONTROL ONLY
// ═══════════════════════════════════════════════════════════════

void initBuzzer() {
    pinMode(BUZZ_CTRL, OUTPUT);
    digitalWrite(BUZZ_CTRL, LOW);
    ledcSetup(BUZZER_PWM_CH, BUZZER_FREQ_HZ, BUZZER_PWM_RES);
    ledcAttachPin(BUZZ_CTRL, BUZZER_PWM_CH);
    ledcWrite(BUZZER_PWM_CH, 0);
    Serial.println("✓ Buzzer initialized (KY-006 Direct, 1.2kHz only)");
}

void checkBuzzerCommand() {
    String path = "pets/" + String(PET_ID) + "/commands/buzzer";
    String resp = firebaseGet(path);
    if (resp.length() == 0) return;
    int jsonStart = resp.indexOf('{');
    if (jsonStart == -1) return;
    String jsonStr = resp.substring(jsonStart);
    DynamicJsonDocument doc(256);
    DeserializationError err = deserializeJson(doc, jsonStr);
    if (err) return;
    bool active = doc["active"] | false;
    if (active && !buzzerActive) {
        buzzerActive = true;
        buzzerOnAt = millis();
        ledcSetup(BUZZER_PWM_CH, BUZZER_FREQ_HZ, BUZZER_PWM_RES);
        ledcAttachPin(BUZZ_CTRL, BUZZER_PWM_CH);
        ledcWrite(BUZZER_PWM_CH, 128);
        Serial.println("[BUZZER] ON - User activated via Firebase");
    } else if (!active && buzzerActive) {
        buzzerActive = false;
        ledcWrite(BUZZER_PWM_CH, 0);
        Serial.println("[BUZZER] OFF - User deactivated via Firebase");
    }
}

void buzzerSafetyWatchdog() {
    if (buzzerActive && (millis() - buzzerOnAt >= BUZZER_SAFETY_MS)) {
        buzzerActive = false;
        ledcWrite(BUZZER_PWM_CH, 0);
        Serial.println("[SAFETY] Buzzer stopped after 2 minutes");
    }
}


// ═══════════════════════════════════════════════════════════════
//  WIFI CONNECTION
// ═══════════════════════════════════════════════════════════════

bool connectWiFi() {
    Serial.println("\nInitializing WiFi...");
    Serial.printf("SSID: %s\n", WIFI_SSID);
    WiFi.mode(WIFI_STA);
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    int attempts = 0;
    while (WiFi.status() != WL_CONNECTED && attempts < 20) {
        delay(500);
        Serial.print(".");
        attempts++;
    }
    if (WiFi.status() == WL_CONNECTED) {
        Serial.println("\n✓ WiFi connected!");
        Serial.print("IP address: ");
        Serial.println(WiFi.localIP());
        syncTimeFromNTP();
        return true;
    } else {
        Serial.println("\n✗ WiFi connection failed!");
        return false;
    }
}

bool isWiFiConnected() {
    return (WiFi.status() == WL_CONNECTED);
}


// ═══════════════════════════════════════════════════════════════
//  NTP TIME SYNC
// ═══════════════════════════════════════════════════════════════

bool syncTimeFromNTP() {
    Serial.println("[TIME] Syncing time from NTP...");
    configTime(5.5 * 3600, 0, "pool.ntp.org", "time.nist.gov");
    Serial.print("[TIME] Waiting for NTP time sync: ");
    time_t now = time(nullptr);
    int attempts = 0;
    while (now < 24 * 3600 && attempts < 20) {
        delay(500);
        Serial.print(".");
        now = time(nullptr);
        attempts++;
    }
    Serial.println();
    struct tm timeinfo;
    localtime_r(&now, &timeinfo);
    if (timeinfo.tm_year > (2024 - 1900)) {
        Serial.print("[TIME] Time set: ");
        Serial.println(asctime(&timeinfo));
        return true;
    } else {
        Serial.println("[TIME] NTP sync failed!");
        return false;
    }
}


// ═══════════════════════════════════════════════════════════════
//  TIMESTAMPS
// ═══════════════════════════════════════════════════════════════

String getISOTimestamp() {
    time_t now = time(nullptr);
    struct tm* timeinfo = localtime(&now);
    char buf[35];
    strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%S.000+05:30", timeinfo);
    return String(buf);
}

unsigned long getUnixTimestampMs() {
    time_t now = time(nullptr);
    if (now < 1700000000UL) {
        Serial.printf("[TIME] Unix timestamp looks wrong: %lu — skipping\n", now);
        return 0;
    }
    return (unsigned long)now * 1000UL;
}


// ═══════════════════════════════════════════════════════════════
//  FIREBASE HTTP FUNCTIONS
// ═══════════════════════════════════════════════════════════════

bool firebasePatch(const String& path, const String& jsonBody) {
    if (!isWiFiConnected()) { connectWiFi(); }
    String url = String("https://") + FIREBASE_HOST + "/"
               + path + ".json?auth=" + FIREBASE_AUTH;
    httpClient.begin(wifiClient, url);
    httpClient.addHeader("Content-Type", "application/json");
    httpClient.setRedirectLimit(3);
    int httpResponseCode = httpClient.sendRequest("PATCH", jsonBody);
    if (httpResponseCode > 0) {
        Serial.printf("Firebase PATCH response: %d\n", httpResponseCode);
        httpClient.end();
        return (httpResponseCode == 200);
    } else {
        Serial.printf("Firebase PATCH failed: %s\n",
            httpClient.errorToString(httpResponseCode).c_str());
        httpClient.end();
        return false;
    }
}

bool firebasePost(const String& path, const String& jsonBody) {
    if (!isWiFiConnected()) { connectWiFi(); }
    String url = String("https://") + FIREBASE_HOST + "/"
               + path + ".json?auth=" + FIREBASE_AUTH;
    httpClient.begin(wifiClient, url);
    httpClient.addHeader("Content-Type", "application/json");
    httpClient.setRedirectLimit(3);
    int httpResponseCode = httpClient.POST(jsonBody);
    if (httpResponseCode > 0) {
        Serial.printf("Firebase POST response: %d\n", httpResponseCode);
        httpClient.end();
        return (httpResponseCode == 200);
    } else {
        Serial.printf("Firebase POST failed: %s\n",
            httpClient.errorToString(httpResponseCode).c_str());
        httpClient.end();
        return false;
    }
}

String firebaseGet(const String& path) {
    if (!isWiFiConnected()) { connectWiFi(); }
    String url = String("https://") + FIREBASE_HOST + "/"
               + path + ".json?auth=" + FIREBASE_AUTH;
    httpClient.begin(wifiClient, url);
    httpClient.setRedirectLimit(3);
    int httpResponseCode = httpClient.GET();
    String response = "";
    if (httpResponseCode > 0) {
        response = httpClient.getString();
    } else {
        Serial.printf("Firebase GET failed: %s\n",
            httpClient.errorToString(httpResponseCode).c_str());
    }
    httpClient.end();
    return response;
}


// ═══════════════════════════════════════════════════════════════
//  FLASH CACHE
// ═══════════════════════════════════════════════════════════════

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
    int synced = 0, start = 0, end;
    while ((end = data.indexOf('\n', start)) != -1) {
        String entry = data.substring(start, end);
        if (entry.length() > 10) {
            if (firebasePost(basePath, entry)) {
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
    syncBuffer(FLASH_GPS_KEY,    "pets/" + String(PET_ID) + "/location_history");
    syncBuffer(FLASH_HEALTH_KEY, "pets/" + String(PET_ID) + "/health_history");
    Serial.println("--- Flash sync complete ---");
}


// ═══════════════════════════════════════════════════════════════
//  GPS HELPERS
// ═══════════════════════════════════════════════════════════════

float getAccuracy(float hdop) {
    float accuracy = hdop * 2.0f;
    if (accuracy < 2.0f)  accuracy = 2.0f;
    if (accuracy > 50.0f) accuracy = 50.0f;
    return accuracy;
}


// ═══════════════════════════════════════════════════════════════
//  ACTIVITY CLASSIFICATION
// ═══════════════════════════════════════════════════════════════

String classifyActivity(float accelMag, float gyroMag) {
    if (accelMag > THRESHOLD_IMPACT && gyroMag > GYRO_THRESHOLD_IMPACT)
        return "impact";
    if (accelMag > THRESHOLD_IMPACT + 5.0f)
        return "impact";
    if (accelMag > THRESHOLD_RUNNING && gyroMag > GYRO_THRESHOLD_RUNNING)
        return "running";
    if (accelMag > THRESHOLD_WALKING && gyroMag > GYRO_THRESHOLD_WALKING)
        return "walking";
    return "resting";
}

bool isActiveActivity(const String& activity) {
    return (activity == "walking" || activity == "running");
}

void updateStepCount(double magnitude) {
    bool currentPeak = (magnitude > 11.5);
    if (currentPeak && !stepPeak && magnitude > lastMagnitude)
        stepCount++;
    stepPeak      = currentPeak;
    lastMagnitude = magnitude;
}


// ═══════════════════════════════════════════════════════════════
//  FIREBASE PUSH FUNCTIONS
// ═══════════════════════════════════════════════════════════════

void pushCurrentActivity(
        const String& activityType,
        float ax, float ay, float az,
        float gx, float gy, float gz,
        float magnitude,
        bool  impactDetected,
        float impactSeverity) {

    DynamicJsonDocument doc(600);
    doc["activity_type"]   = activityType;
    doc["magnitude"]       = magnitude;
    doc["impact_detected"] = impactDetected;
    doc["impact_severity"] = impactSeverity;
    JsonObject ts = doc.createNestedObject("timestamp");
    ts[".sv"] = "timestamp";
    doc["step_count"]     = stepCount;
    doc["active_minutes"] = totalActiveMinutes;
    JsonObject accel = doc.createNestedObject("accelerometer");
    accel["x"] = ax; accel["y"] = ay; accel["z"] = az;
    JsonObject gyro = doc.createNestedObject("gyroscope");
    gyro["x"] = gx; gyro["y"] = gy; gyro["z"] = gz;
    String body;
    serializeJson(doc, body);
    firebasePatch("pets/" + String(PET_ID) + "/activity/current", body);
}

void saveActivityHistory(
        const String& activityType,
        float ax, float ay, float az,
        float gx, float gy, float gz,
        float magnitude,
        bool  impactDetected,
        float impactSeverity) {

    DynamicJsonDocument doc(600);
    doc["activity_type"]   = activityType;
    doc["magnitude"]       = magnitude;
    doc["impact_detected"] = impactDetected;
    doc["impact_severity"] = impactSeverity;
    JsonObject ts = doc.createNestedObject("timestamp");
    ts[".sv"] = "timestamp";
    doc["step_count"]     = stepCount;
    doc["active_minutes"] = totalActiveMinutes;
    JsonObject accel = doc.createNestedObject("accelerometer");
    accel["x"] = ax; accel["y"] = ay; accel["z"] = az;
    JsonObject gyro = doc.createNestedObject("gyroscope");
    gyro["x"] = gx; gyro["y"] = gy; gyro["z"] = gz;
    String body;
    serializeJson(doc, body);
    firebasePost("pets/" + String(PET_ID) + "/activity/history", body);
}

// pushHealth now accepts respiratoryRate and saves both fields
// to /health (live) and /health_history (timestamped record).
// On failure, caches to flash with both values preserved.
void pushHealth(float temperature, int respRate) {
    DynamicJsonDocument doc(300);
    doc["temperature"]     = temperature;
    doc["respiratoryRate"] = respRate;
    JsonObject ts = doc.createNestedObject("timestamp");
    ts[".sv"] = "timestamp";
    String body;
    serializeJson(doc, body);

    String livePath = "pets/" + String(PET_ID) + "/health";
    if (!firebasePatch(livePath, body)) {
        // Cache both temperature and respiratory rate for later sync
        DynamicJsonDocument cacheDoc(256);
        cacheDoc["temperature"]        = temperature;
        cacheDoc["respiratoryRate"]    = respRate;
        cacheDoc["timestamp_relative"] = (unsigned long)millis();
        cacheDoc["cached"]             = true;
        String cacheBody;
        serializeJson(cacheDoc, cacheBody);
        saveToFlash(FLASH_HEALTH_KEY, cacheBody);
    }

    String histPath = "pets/" + String(PET_ID) + "/health_history";
    firebasePost(histPath, body);
}

void pushGPS() {
    if (!gps.location.isValid()) {
        Serial.println("No GPS fix — skipping");
        return;
    }
    float hdop     = gps.hdop.hdop();
    float accuracy = getAccuracy(hdop);

    DynamicJsonDocument locDoc(300);
    locDoc["latitude"]  = gps.location.lat();
    locDoc["longitude"] = gps.location.lng();
    locDoc["accuracy"]  = accuracy;
    locDoc["heading"]   = 0.0;
    JsonObject locTs = locDoc.createNestedObject("timestamp");
    locTs[".sv"] = "timestamp";
    String locBody;
    serializeJson(locDoc, locBody);
    String currentPath = "pets/" + String(PET_ID) + "/current_location";
    if (firebasePatch(currentPath, locBody)) {
        Serial.printf("GPS updated: %.6f, %.6f (HDOP:%.1f -> +/-%.1fm)\n",
            gps.location.lat(), gps.location.lng(), hdop, accuracy);
    } else {
        saveToFlash(FLASH_GPS_KEY, locBody);
    }

    DynamicJsonDocument histDoc(300);
    histDoc["latitude"]  = gps.location.lat();
    histDoc["longitude"] = gps.location.lng();
    histDoc["accuracy"]  = accuracy;
    JsonObject histTs = histDoc.createNestedObject("timestamp");
    histTs[".sv"] = "timestamp";
    String histBody;
    serializeJson(histDoc, histBody);
    firebasePost("pets/" + String(PET_ID) + "/location_history", histBody);
}

// ═══════════════════════════════════════════════════════════════
//  SETUP
// ═══════════════════════════════════════════════════════════════

void setup() {
    Serial.begin(115200);
    delay(1000);

    Serial.println("==================================================");
    Serial.println("  PetGuard Pro v6.4 - WiFi + Respiratory Rate");
    Serial.println("==================================================");

    initBuzzer();

    flash.begin(FLASH_NAMESPACE, false);
    Serial.println("Flash buffer initialized");

    Wire.begin(21, 22);
    delay(100);
    Wire.setClock(100000);
    delay(100);

    mpu.initialize();
    delay(100);
    if (mpu.testConnection()) {
        Serial.println("MPU6050 ready");
    } else {
        Serial.println("MPU6050 not found — check wiring!");
    }

    if (!mlx.begin()) {
        Serial.println("MLX90614 not found — skipping");
    } else {
        Serial.println("MLX90614 ready");
    }

    gpsSerial.begin(9600, SERIAL_8N1, GPS_RX_PIN, GPS_TX_PIN);
    Serial.println("GPS started");

    wifiClient.setInsecure();
    connectWiFi();
    if (isWiFiConnected()) {
        syncAllFlashBuffers();
    }

    activeStartMs  = millis();
    respWindowStart = millis();

    Serial.println("==================================================");
    Serial.println("       All systems ready!");
    Serial.println("==================================================");
}


// ═══════════════════════════════════════════════════════════════
//  LOOP
// ═══════════════════════════════════════════════════════════════

void loop() {
    unsigned long now    = millis();
    bool          wifiOK = isWiFiConnected();

    // ── WiFi health check ──────────────────────────────────────
    if (now - lastConnCheck >= CONN_CHECK_INTERVAL) {
        lastConnCheck = now;
        wifiOK = isWiFiConnected();
        if (!wifiOK) {
            Serial.println("WiFi lost — reconnecting...");
            connectWiFi();
            wifiOK = isWiFiConnected();
        }
    }

    // ── GPS feed ───────────────────────────────────────────────
    while (gpsSerial.available() > 0) {
        gps.encode(gpsSerial.read());
    }

    // ── Respiratory Rate — sampled every 20ms ─────────────────
    // Uses accel Z-axis (collar on dog's chest): chest expansion during
    // inhalation causes a measurable periodic displacement.
    //
    // Algorithm:
    //   1. Fast EMA (alpha=RESP_ACCEL_SMOOTHING) removes sample noise.
    //   2. Slow EMA (alpha=0.01) tracks the drifting DC mean (gravity+posture).
    //   3. A rising zero-crossing through the baseline with amplitude >
    //      RESP_PEAK_THRESHOLD counts as one breath.
    //   4. After RESP_WINDOW_MS, breaths are converted to br/min and reset.
    if (now - lastSensorRead >= SENSOR_READ_INTERVAL) {
        lastSensorRead = now;

        int16_t rzRaw, dummy;
        mpu.getAcceleration(&dummy, &dummy, &rzRaw);
        float az_resp = (rzRaw / 16384.0f) * 9.81f;

        if (respEma == 0.0f)     respEma     = az_resp;
        if (respEmaMean == 0.0f) respEmaMean = az_resp;

        respEma     = RESP_ACCEL_SMOOTHING * az_resp
                    + (1.0f - RESP_ACCEL_SMOOTHING) * respEma;
        respEmaMean = 0.01f * respEma + 0.99f * respEmaMean;

        float deviation = respEma - respEmaMean;
        bool  aboveNow  = (deviation > RESP_PEAK_THRESHOLD);
        if (aboveNow && !respLastAbove) {
            respBreathCount++;
        }
        respLastAbove = aboveNow;

        if (now - respWindowStart >= RESP_WINDOW_MS) {
            float windowSec = (now - respWindowStart) / 1000.0f;
            respiratoryRate = (int)((respBreathCount / windowSec) * 60.0f + 0.5f);
            respBreathCount = 0;
            respWindowStart = now;
            Serial.printf("[RESP] Respiratory rate updated: %d br/min\n",
                respiratoryRate);
        }
    }

    // ── IMU read ───────────────────────────────────────────────
    int16_t rawAx, rawAy, rawAz, rawGx, rawGy, rawGz;
    mpu.getMotion6(&rawAx, &rawAy, &rawAz, &rawGx, &rawGy, &rawGz);

    if (rawAx == 0 && rawAy == 0 && rawAz == 0 &&
        rawGx == 0 && rawGy == 0 && rawGz == 0) {
        Serial.println("[IMU] Zero reading — reinitializing MPU6050...");
        Wire.begin(21, 22);
        delay(50);
        Wire.setClock(100000);
        mpu.initialize();
        delay(100);
        return;
    }

    float ax  = (rawAx / 16384.0f) * 9.81f;
    float ay  = (rawAy / 16384.0f) * 9.81f;
    float az  = (rawAz / 16384.0f) * 9.81f;
    float gxf = rawGx / 131.0f;
    float gyf = rawGy / 131.0f;
    float gzf = rawGz / 131.0f;
    float magnitude = sqrt(ax*ax + ay*ay + az*az);
    float gyroMag   = sqrt(gxf*gxf + gyf*gyf + gzf*gzf);

    String activity       = classifyActivity(magnitude, gyroMag);
    bool   impactDetected = (activity == "impact");
    float  impactSeverity = 0.0f;
    if (impactDetected) {
        float accelContrib = (magnitude - THRESHOLD_IMPACT) / 5.0f;
        float gyroContrib  = gyroMag / 200.0f;
        impactSeverity = ((accelContrib + gyroContrib) / 2.0f) * 10.0f;
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

    // ── Buzzer command check from Firebase (every 3s) ──────────
    if (wifiOK && (now - lastBuzzerCheck >= BUZZER_CHECK_INTERVAL)) {
        lastBuzzerCheck = now;
        checkBuzzerCommand();
    }

    buzzerSafetyWatchdog();

    // ── Serial monitor (every 1s) ──────────────────────────────
    static unsigned long lastSerialPrint = 0;
    if (now - lastSerialPrint >= 1000) {
        lastSerialPrint = now;

        float objTemp  = mlx.readObjectTempC();
        float ambTemp  = mlx.readAmbientTempC();
        float hdop     = gps.hdop.hdop();
        float accuracy = getAccuracy(hdop);

        int gpsBytes = 0, healthBytes = 0;
        if (flash.isKey(FLASH_GPS_KEY))
            gpsBytes    = flash.getString(FLASH_GPS_KEY,    "").length();
        if (flash.isKey(FLASH_HEALTH_KEY))
            healthBytes = flash.getString(FLASH_HEALTH_KEY, "").length();

        time_t now_time = time(nullptr);
        struct tm* timeinfo = localtime(&now_time);
        char timeBuf[30];
        strftime(timeBuf, sizeof(timeBuf), "%Y-%m-%d %H:%M:%S", timeinfo);

        Serial.println("\n==================================================");
        Serial.println("         PETGUARD PRO LIVE DATA PIPELINE");
        Serial.printf ("         %s\n", timeBuf);
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

        Serial.println("\n[2] Temperature (MLX90614)");
        Serial.println("--------------------------------------------");
        Serial.printf("  Object Temp  : %.1f C\n", objTemp);
        Serial.printf("  Ambient Temp : %.1f C\n", ambTemp);

        Serial.println("\n[3] Respiratory Rate + Activity (MPU6050)");
        Serial.println("--------------------------------------------");
        Serial.printf("  Respiratory Rate: %d br/min%s\n",
            respiratoryRate,
            respiratoryRate == 0 ? "  (calibrating...)" : "");
        Serial.printf("  Activity       : %s\n",         activity.c_str());
        Serial.printf("  Magnitude      : %.2f m/s2\n",  magnitude);
        Serial.printf("  Gyro Magnitude : %.2f deg/s\n", gyroMag);
        Serial.printf("  Step Count     : %d\n",         stepCount);
        Serial.printf("  Active Minutes : %.1f min\n",   totalActiveMinutes);
        if (impactDetected) {
            Serial.printf("  IMPACT! Severity: %.1f/10\n", impactSeverity);
        }

        Serial.println("\n[4] Buzzer Status (Firebase Only)");
        Serial.println("--------------------------------------------");
        Serial.printf("  Status : %s\n",
            buzzerActive ? "BEEPING (1.2kHz)" : "Silent");

        Serial.println("\n[5] WiFi Connection");
        Serial.println("--------------------------------------------");
        Serial.printf("  WiFi         : %s\n",
            wifiOK ? "Connected" : "DISCONNECTED — offline mode");
        Serial.printf("  SSID         : %s\n", WIFI_SSID);
        if (wifiOK) {
            Serial.printf("  Signal       : %d dBm\n", WiFi.RSSI());
        }
        Serial.printf("  GPS cache    : %d bytes%s\n",
            gpsBytes,
            gpsBytes > 0 ? " <- PENDING SYNC" : "");
        Serial.printf("  Health cache : %d bytes%s\n",
            healthBytes,
            healthBytes > 0 ? " <- PENDING SYNC" : "");
        Serial.println("==================================================");
    }

    // ── Firebase pushes ────────────────────────────────────────
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

    if (now - lastHealthPush >= HEALTH_PUSH_INTERVAL_MS) {
        lastHealthPush = now;
        float temperature = mlx.readObjectTempC();
        Serial.printf("Pushing Health — Temp: %.1fC  Resp: %d br/min\n",
            temperature, respiratoryRate);
        pushHealth(temperature, respiratoryRate);
    }

    if (now - lastGpsPush >= GPS_PUSH_INTERVAL_MS) {
        lastGpsPush = now;
        pushGPS();
    }

    if (wifiOK && now - lastFlashSync >= FLASH_SYNC_INTERVAL) {
        lastFlashSync = now;
        syncAllFlashBuffers();
    }

    // ── Immediate impact push ──────────────────────────────────
    if (impactDetected) {
        Serial.println("IMPACT! Pushing immediately...");
        pushCurrentActivity(activity, ax, ay, az, gxf, gyf, gzf,
                            magnitude, impactDetected, impactSeverity);
        saveActivityHistory(activity, ax, ay, az, gxf, gyf, gzf,
                            magnitude, impactDetected, impactSeverity);
        delay(3000);
    }
}