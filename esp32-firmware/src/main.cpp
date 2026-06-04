// PetGuard Pro v5.3


#include <Preferences.h>
#include <Arduino.h>
#include <Wire.h>
#include <ArduinoJson.h>
#include <TinyGPSPlus.h>
#include <MPU6050.h>
#include <Adafruit_MLX90614.h>
#include "config.h"


// ── Serial Ports ──────────────────────────────────────────────
HardwareSerial gsmSerial(1);   // UART1 — SIM800L on GPIO 26 (RX) / 27 (TX)
HardwareSerial gpsSerial(2);   // UART2 — GPS    on GPIO 16 (RX) / 17 (TX)



//  Flash Buffer (Offline Cache)
Preferences flash;
const char* FLASH_NAMESPACE  = "petguard";
const char* FLASH_GPS_KEY    = "gps_queue";
const char* FLASH_HEALTH_KEY = "health_queue";
const int   MAX_FLASH_BYTES  = 8000;


//  Objects
MPU6050           mpu;
Adafruit_MLX90614 mlx;
//HardwareSerial    gpsSerial(2);
TinyGPSPlus       gps;


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
unsigned long lastConnCheck     = 0; //new
const unsigned long SENSOR_READ_INTERVAL = 20;
const unsigned long FLASH_SYNC_INTERVAL  = 30000;
const unsigned long CONN_CHECK_INTERVAL  = 30000; //new



//  AT COMMAND UTILITIES
// ═══════════════════════════════════════════════════════════════

// Send AT command, wait for expected response string
bool sendAT(const String& cmd, const String& expected, int timeout = 3000) {
    gsmSerial.println(cmd);
    unsigned long start = millis();
    String response = "";
    while (millis() - start < timeout) {
        while (gsmSerial.available()) {
            response += (char)gsmSerial.read();
        }
        if (response.indexOf(expected) != -1) return true;
    }
    Serial.println("AT FAIL [" + cmd + "] → " + response);
    return false;
}

// Send AT command, return full response string
String sendATread(const String& cmd, int timeout = 3000) {
    gsmSerial.println(cmd);
    unsigned long start = millis();
    String response = "";
    while (millis() - start < timeout) {
        while (gsmSerial.available()) {
            response += (char)gsmSerial.read();
        }
    }
    return response;
}

// ═══════════════════════════════════════════════════════════════
//  GPRS CONNECTION
// ═══════════════════════════════════════════════════════════════

bool connectGPRS() {
    Serial.println("Initializing SIM800L...");
    gsmSerial.begin(GSM_BAUD, SERIAL_8N1, GSM_RX_PIN, GSM_TX_PIN);
    delay(8000);

    // 1. AT handshake — retry up to 10 times
    bool alive = false;
    for (int i = 0; i < 10; i++) {
        if (sendAT("AT", "OK", 2000)) { alive = true; break; }
        delay(1000);
    }
    if (!alive) { Serial.println("SIM800L not responding!"); return false; }
    Serial.println("SIM800L alive");

    // 2. Disable echo
    sendAT("ATE0", "OK");

    // 3. Wait for network registration
    Serial.print("Waiting for network");
    bool registered = false;
    for (int i = 0; i < 30; i++) {
        String resp = sendATread("AT+CREG?");
        if (resp.indexOf(",1") != -1 || resp.indexOf(",5") != -1) {
            registered = true; break;
        }
        Serial.print("."); delay(2000);
    }
    if (!registered) { Serial.println(" FAILED — check SIM/antenna"); return false; }
    Serial.println(" registered!");

    // 4. Attach GPRS
    sendAT("AT+CGATT=1", "OK", 10000);

    // 5. Configure bearer profile
    sendAT("AT+SAPBR=3,1,\"Contype\",\"GPRS\"", "OK");
    sendAT("AT+SAPBR=3,1,\"APN\",\""  + String(GSM_APN)      + "\"", "OK");
    if (strlen(GSM_APN_USER) > 0) {
        sendAT("AT+SAPBR=3,1,\"USER\",\"" + String(GSM_APN_USER) + "\"", "OK");
        sendAT("AT+SAPBR=3,1,\"PWD\",\""  + String(GSM_APN_PASS) + "\"", "OK");
    }

    // 6. Open bearer / get IP
    if (!sendAT("AT+SAPBR=1,1", "OK", 10000)) {
        Serial.println("Bearer open failed — may already be open");
    }
    String ip = sendATread("AT+SAPBR=2,1");
    Serial.println("GPRS IP: " + ip);

    // 7. NTP time sync via GPRS (UTC+5:30 = offset 22 × 15min)
    sendAT("AT+CNTPCID=1", "OK");
    sendAT("AT+CNTP=\"pool.ntp.org\",22", "OK");
    sendAT("AT+CNTP", "+CNTP:", 5000);
    delay(2000);

    Serial.println("GPRS connected and ready!");
    return true;
}

bool isGPRSConnected() {
    String resp = sendATread("AT+SAPBR=2,1");
    return (resp.indexOf("0.0.0.0") == -1 && resp.indexOf("\"") != -1);
}

// ═══════════════════════════════════════════════════════════════
//  FIREBASE HTTP FUNCTIONS
// ═══════════════════════════════════════════════════════════════

// PATCH — merges JSON into existing node (use for live/current nodes)
bool firebasePatch(const String& path, const String& jsonBody) {
    if (!isGPRSConnected()) {
        Serial.println("GPRS not connected — reconnecting...");
        connectGPRS();
    }

    String url = "https://" + String(FIREBASE_HOST) + "/"
           + path + ".json?auth=" + String(FIREBASE_AUTH);

    Serial.println("PATCH → " + url);

    sendAT("AT+HTTPINIT", "OK", 5000);
    sendAT("AT+HTTPPARA=\"REDIR\",1", "OK");   // ← ADD
    sendAT("AT+HTTPSSL=1", "OK");
    sendAT("AT+HTTPPARA=\"CID\",1", "OK");
    sendAT("AT+HTTPPARA=\"URL\",\"" + url + "\"", "OK");
    sendAT("AT+HTTPPARA=\"CONTENT\",\"application/json\"", "OK");
    // SIM800L only supports GET/POST/HEAD via AT+HTTPACTION
    // Firebase REST accepts POST + this header as a PATCH
    sendAT("AT+HTTPPARA=\"USERDATA\",\"X-HTTP-Method-Override: PATCH\"", "OK");

    int bodyLen = jsonBody.length();
    if (!sendAT("AT+HTTPDATA=" + String(bodyLen) + ",10000", "DOWNLOAD", 5000)) {
        sendAT("AT+HTTPTERM", "OK");
        return false;
    }
    gsmSerial.print(jsonBody);
    delay(1000);

    if (!sendAT("AT+HTTPACTION=1", "+HTTPACTION:", 15000)) {
        Serial.println("HTTP action timeout");
        sendAT("AT+HTTPTERM", "OK");
        return false;
    }

    String resp = sendATread("AT+HTTPREAD", 3000);
    Serial.println("Firebase response: " + resp);
    sendAT("AT+HTTPTERM", "OK");
    return (resp.indexOf("200") != -1);
}

// POST — creates a new auto-keyed child (use for history nodes)
bool firebasePost(const String& path, const String& jsonBody) {
    if (!isGPRSConnected()) {
        Serial.println("GPRS not connected — reconnecting...");
        connectGPRS();
    }

    String url = "https://" + String(FIREBASE_HOST) + "/"
               + path + ".json?auth=" + String(FIREBASE_AUTH);

    sendAT("AT+HTTPINIT", "OK", 5000);
    sendAT("AT+HTTPPARA=\"REDIR\",1", "OK"); 
    sendAT("AT+HTTPSSL=1", "OK");   
    sendAT("AT+HTTPPARA=\"CID\",1", "OK");
    sendAT("AT+HTTPPARA=\"URL\",\"" + url + "\"", "OK");
    sendAT("AT+HTTPPARA=\"CONTENT\",\"application/json\"", "OK");

    int bodyLen = jsonBody.length();
    if (!sendAT("AT+HTTPDATA=" + String(bodyLen) + ",10000", "DOWNLOAD", 5000)) {
        sendAT("AT+HTTPTERM", "OK");
        return false;
    }
    gsmSerial.print(jsonBody);
    delay(1000);

    bool ok = sendAT("AT+HTTPACTION=1", "+HTTPACTION:", 15000);
    sendAT("AT+HTTPTERM", "OK");
    return ok;
}

// ═══════════════════════════════════════════════════════════════
//  FLASH CACHE (unchanged logic, updated sync to use firebasePost)
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
    int synced = 0;
    int start  = 0;
    int end;
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
    syncBuffer(FLASH_GPS_KEY,
               "pets/" + String(PET_ID) + "/location_history");
    syncBuffer(FLASH_HEALTH_KEY,
               "pets/" + String(PET_ID) + "/health_history");
    Serial.println("--- Flash sync complete ---");
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


//newly added
String classifyActivity(float accelMag, float gyroMag) {
    if (accelMag > THRESHOLD_IMPACT && gyroMag > GYRO_THRESHOLD_IMPACT)
        return "impact";
    if (accelMag > THRESHOLD_IMPACT + 5.0f)
        return "impact";
    if (accelMag > THRESHOLD_RUNNING && gyroMag > GYRO_THRESHOLD_RUNNING)
        return "running";
    if (accelMag > THRESHOLD_WALKING && gyroMag > GYRO_THRESHOLD_WALKING)
        return "walking";
    if (gyroMag > GYRO_THRESHOLD_PLAYING && accelMag > 10.0f)
        return "playing";
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



    DynamicJsonDocument doc(512);
    doc["activity_type"]   = activityType;
    doc["magnitude"]       = magnitude;
    doc["impact_detected"] = impactDetected;
    doc["impact_severity"] = impactSeverity;
    doc["timestamp"]       = (unsigned long)getUnixTimestampMs();
    doc["step_count"]      = stepCount;
    doc["active_minutes"]  = totalActiveMinutes;

    JsonObject accel = doc.createNestedObject("accelerometer");
    accel["x"] = ax; accel["y"] = ay; accel["z"] = az;

    JsonObject gyro = doc.createNestedObject("gyroscope");
    gyro["x"] = gx; gyro["y"] = gy; gyro["z"] = gz;

    String body;
    serializeJson(doc, body);

    String path = "pets/" + String(PET_ID) + "/activity/current";
    firebasePatch(path, body);   // current node — always PATCH
}

void saveActivityHistory(
        const String& activityType,
        float ax, float ay, float az,
        float gx, float gy, float gz,
        float magnitude,
        bool  impactDetected,
        float impactSeverity) {

    

    DynamicJsonDocument doc(512);
    doc["activity_type"]   = activityType;
    doc["magnitude"]       = magnitude;
    doc["impact_detected"] = impactDetected;
    doc["impact_severity"] = impactSeverity;
    doc["timestamp"]       = (unsigned long)getUnixTimestampMs();
    doc["step_count"]      = stepCount;
    doc["active_minutes"]  = totalActiveMinutes;

    JsonObject accel = doc.createNestedObject("accelerometer");
    accel["x"] = ax; accel["y"] = ay; accel["z"] = az;

    JsonObject gyro = doc.createNestedObject("gyroscope");
    gyro["x"] = gx; gyro["y"] = gy; gyro["z"] = gz;

    String body;
    serializeJson(doc, body);

    String path = "pets/" + String(PET_ID) + "/activity/history";
    firebasePost(path, body);    // history — POST creates auto-keyed child
}

//  Push Health
// Uses lastValidSpo2 so SpO2 persists in Firebase between buffer cycles
void pushHealth(int heartRate, float temperature) {
    String timestamp = getISOTimestamp();

    DynamicJsonDocument doc(256);
    doc["temperature"] = temperature;
    doc["timestamp"]   = timestamp;

    String body;
    serializeJson(doc, body);

    // Live health node — PATCH (merge)
    String livePath = "pets/" + String(PET_ID) + "/health";
    if (!firebasePatch(livePath, body)) {
        saveToFlash(FLASH_HEALTH_KEY, body);
    }

    // History node — POST (auto-keyed child)
    String histPath = "pets/" + String(PET_ID) + "/health_history";
    firebasePost(histPath, body);
}

//  Push GPS
void pushGPS() {
    if (!gps.location.isValid()) {
        Serial.println("No GPS fix — skipping");
        return;
    }

    String timestamp = getISOTimestamp();
    //String id        = String(millis());
    float  hdop      = gps.hdop.hdop();
    float  accuracy  = getAccuracy(hdop);

    

    // Current location document
    DynamicJsonDocument locDoc(256);
    locDoc["latitude"]  = gps.location.lat();
    locDoc["longitude"] = gps.location.lng();
    locDoc["accuracy"]  = accuracy;
    locDoc["timestamp"] = timestamp;
    locDoc["heading"]   = 0.0;

    String locBody;
    serializeJson(locDoc, locBody);

    String currentPath = "pets/" + String(PET_ID) + "/current_location";
    if (firebasePatch(currentPath, locBody)) {
        Serial.printf("GPS updated: %.6f, %.6f (HDOP:%.1f -> +/-%.1fm)\n",
            gps.location.lat(), gps.location.lng(), hdop, accuracy);
    } else {
        saveToFlash(FLASH_GPS_KEY, locBody);
    }

    // History entry — POST
    DynamicJsonDocument histDoc(256);
    histDoc["latitude"]  = gps.location.lat();
    histDoc["longitude"] = gps.location.lng();
    histDoc["accuracy"]  = accuracy;
    histDoc["timestamp"] = timestamp;

    String histBody;
    serializeJson(histDoc, histBody);

    String historyPath = "pets/" + String(PET_ID) + "/location_history";
    firebasePost(historyPath, histBody);
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
    }


    if (!mlx.begin()) {
        Serial.println("MLX90614 not found — skipping");
    } else {
        Serial.println("MLX90614 ready");
    }

    gpsSerial.begin(9600, SERIAL_8N1, GPS_RX_PIN, GPS_TX_PIN);
    Serial.println("GPS started");

    
    
    connectGPRS();

    // Sync any cached data from previous offline session
    if (isGPRSConnected()) {
        syncAllFlashBuffers();
    }


    activeStartMs = millis();

    Serial.println("==================================================");
    Serial.println("       All systems ready!");
    Serial.println("==================================================");
}

//  Loop
void loop() {
    
    bool gprsOK = true;
    unsigned long now = millis();

    if (now - lastConnCheck >= CONN_CHECK_INTERVAL) {
        lastConnCheck = now;
        gprsOK = isGPRSConnected();
        if (!gprsOK) {
            Serial.println("GPRS lost — reconnecting...");
            connectGPRS();
            gprsOK = isGPRSConnected();
        }
    }

    //unsigned long now = millis();

    while (gpsSerial.available() > 0) {
        gps.encode(gpsSerial.read());
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
    //newly added
    float gyroMag = sqrt(gxf*gxf + gyf*gyf + gzf*gzf);


    //String activity       = classifyActivity(magnitude);
    String activity = classifyActivity(magnitude, gyroMag);

    bool   impactDetected = (activity == "impact");
    float  impactSeverity = 0.0f;
    /*
    if (impactDetected) {
        impactSeverity = ((magnitude - THRESHOLD_IMPACT) / 5.0f) * 10.0f;
        if (impactSeverity > 10.0f) impactSeverity = 10.0f;
    }
    */
    //newly added
    if (impactDetected) {
        // Combine accel + gyro contribution for more accurate severity
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

    // Serial Output (every 1 second)
    static unsigned long lastSerialPrint = 0;
    if (now - lastSerialPrint >= 1000) {
        lastSerialPrint = now;

        float objTemp  = mlx.readObjectTempC();
        float ambTemp  = mlx.readAmbientTempC();
        float hdop     = gps.hdop.hdop();
        float accuracy = getAccuracy(hdop);

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

        Serial.println("\n[3] Activity (MPU6050)");
        Serial.println("--------------------------------------------");
        Serial.printf("  Activity       : %s\n",        activity.c_str());
        Serial.printf("  Magnitude      : %.2f m/s2\n", magnitude);
        //newly added
        Serial.printf("  Gyro Magnitude : %.2f deg/s\n", gyroMag);
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
        Serial.printf ("    temperature: %.1f C\n", objTemp);
        Serial.println("  Path: pets/" + String(PET_ID) +
                       "/activity/current");
        Serial.printf ("    activity   : %s\n",   activity.c_str());
        Serial.printf ("    steps      : %d\n",   stepCount);
        Serial.println("  Timestamp    : " + getISOTimestamp());

        

        Serial.println("\n[5] Connection + Flash Cache Status");
        Serial.println("--------------------------------------------");
        Serial.printf("  GPRS         : %s\n",
            gprsOK ? "Connected" : "DISCONNECTED — data being cached");
        Serial.printf("  GPS cache    : %d bytes%s\n",
            gpsBytes,
            gpsBytes > 0 ? "  <-- PENDING SYNC" : "");
        Serial.printf("  Health cache : %d bytes%s\n",
            healthBytes,
            healthBytes > 0 ? "  <-- PENDING SYNC" : "");
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
    if (now - lastHealthPush >= HEALTH_PUSH_INTERVAL_MS) {
        lastHealthPush = now;
        float temperature = mlx.readObjectTempC();
        Serial.printf("Pushing Health — Temp: %.1fC\n", temperature);
        pushHealth(0, temperature);
    }

    if (now - lastGpsPush >= GPS_PUSH_INTERVAL_MS) {
        lastGpsPush = now;
        pushGPS();
    }

    if (gprsOK && now - lastFlashSync >= FLASH_SYNC_INTERVAL) {
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