#pragma once

// ── WiFi ──────────────────────────────────────────────────────
#define WIFI_SSID       "your wifi"
#define WIFI_PASSWORD   "your password"

// ── Firebase ──────────────────────────────────────────────────
#define FIREBASE_HOST   "petguardpro-efda9-default-rtdb.asia-southeast1.firebasedatabase.app"
#define FIREBASE_AUTH   "032FWNdxI7sdtn60rqBpTeSU0cPl0uQgLMoOYrgX"
#define FIREBASE_SECRET FIREBASE_AUTH
#define PET_ID          "default_pet"

// ── GPS Pins ──────────────────────────────────────────────────
#define GPS_RX_PIN      16
#define GPS_TX_PIN      17

// ── Timing (ms) ───────────────────────────────────────────────
#define CURRENT_UPDATE_INTERVAL_MS   2000   // IMU → Firebase every 2s
#define HISTORY_SAVE_INTERVAL_MS     30000  // IMU history every 30s
#define HEALTH_PUSH_INTERVAL_MS      30000  // Heart rate every 30s
#define GPS_PUSH_INTERVAL_MS         10000  // GPS every 10s

// ── IMU Activity Thresholds (m/s²) ───────────────────────────
#define THRESHOLD_IMPACT   25.0
#define THRESHOLD_RUNNING  15.0
#define THRESHOLD_WALKING  11.5
#define THRESHOLD_PLAYING  10.5