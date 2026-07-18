#pragma once
// ── WiFi ──────────────────────────────────────────────────────
#define WIFI_SSID       "Redmi Note 11 Pro 5G"
#define WIFI_PASSWORD   "6ujeeuccxnaan2j"
// ── Firebase ──────────────────────────────────────────────────
#define FIREBASE_HOST   "petguardpro-efda9-default-rtdb.asia-southeast1.firebasedatabase.app"
#define FIREBASE_AUTH   "032FWNdxI7sdtn60rqBpTeSU0cPl0uQgLMoOYrgX"
#define PET_ID          "default_pet"
// ── GPS Pins ──────────────────────────────────────────────────
#define GPS_RX_PIN      16
#define GPS_TX_PIN      17
// ── Buzzer Pin ────────────────────────────────────────────────
#define BUZZ_CTRL       25              // Direct to KY-006 S pin
// ── Buzzer Configuration ──────────────────────────────────────
#define BUZZER_PWM_CH   0
#define BUZZER_PWM_RES  8
#define BUZZER_FREQ_HZ  1200            // Dog-friendly only
// ── Battery Monitor Pin ───────────────────────────────────────
#define BATT_PIN        34
// ── Timing (ms) ───────────────────────────────────────────────
#define CURRENT_UPDATE_INTERVAL_MS   5000
#define HISTORY_SAVE_INTERVAL_MS     7000
#define HEALTH_PUSH_INTERVAL_MS      5000
#define GPS_PUSH_INTERVAL_MS         6000
// ── IMU Activity Thresholds (m/s²) ───────────────────────────
#define THRESHOLD_IMPACT   25.0
#define THRESHOLD_RUNNING  15.0
#define THRESHOLD_WALKING  12.5

// ── IMU Gyro Thresholds (deg/s) ──────────────────────────────
#define GYRO_THRESHOLD_IMPACT   100.0
#define GYRO_THRESHOLD_RUNNING   30.0
#define GYRO_THRESHOLD_WALKING    8.0

// ── Respiratory Rate Detection ────────────────────────────────
#define RESP_ACCEL_SMOOTHING  0.1f    // Fast EMA alpha — noise filter
#define RESP_PEAK_THRESHOLD   0.04f   // Min deviation to count as a breath (m/s²)
#define RESP_WINDOW_MS        30000   // Counting window: 30s → multiply by 2 for br/min