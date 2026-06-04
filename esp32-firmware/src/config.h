

#pragma once

// ── GSM / SIM800L ─────────────────────────────────────────────
#define GSM_RX_PIN      26       // SIM800L TXD → ESP32 GPIO26
#define GSM_TX_PIN      27       // SIM800L RXD ← ESP32 GPIO27
#define GSM_RST_PIN     5        // Optional hardware reset
#define GSM_BAUD        9600

// ── SIM Card APN (Sri Lanka) ───────────────────────────────────
#define GSM_APN         "mobitel"   // Mobitel: "mobitel" | Dialog: "dialogbb"
#define GSM_APN_USER    ""          // Usually blank for Sri Lanka SIMs
#define GSM_APN_PASS    ""          // Usually blank for Sri Lanka SIMs

// ── Firebase ──────────────────────────────────────────────────
#define FIREBASE_HOST   "petguardpro-efda9-default-rtdb.asia-southeast1.firebasedatabase.app"
#define FIREBASE_AUTH   "032FWNdxI7sdtn60rqBpTeSU0cPl0uQgLMoOYrgX"
#define PET_ID   "default_pet"

// ── GPS Pins (unchanged) ──────────────────────────────────────
#define GPS_RX_PIN      16
#define GPS_TX_PIN      17

// ── Timing (ms) ───────────────────────────────────────────────
#define CURRENT_UPDATE_INTERVAL_MS   8000   // IMU → Firebase every 8s
#define HISTORY_SAVE_INTERVAL_MS     10000  // IMU history every 10s
#define HEALTH_PUSH_INTERVAL_MS      8000  // Heart rate every 15s
#define GPS_PUSH_INTERVAL_MS         10000  // GPS every 10s

// ── IMU Activity Thresholds (m/s²) ───────────────────────────
#define THRESHOLD_IMPACT   25.0
#define THRESHOLD_RUNNING  15.0
#define THRESHOLD_WALKING  12.5
#define THRESHOLD_PLAYING  11.5

// ── IMU Gyro Thresholds (deg/s) ──────────────────────────────
#define GYRO_THRESHOLD_IMPACT   100.0
#define GYRO_THRESHOLD_RUNNING   30.0
#define GYRO_THRESHOLD_WALKING    8.0
#define GYRO_THRESHOLD_PLAYING   80.0