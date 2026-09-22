// ─────────────────────────────────────────────────────────────────────────────
// TemperatureAlertSettings — user-configurable custom limits for body
// temperature, layered on top of the auto-computed VitalThresholds. Stored
// per pet in Firestore under pets/{petId}.temperatureAlertSettings.
// ─────────────────────────────────────────────────────────────────────────────

class TemperatureAlertSettings {
  final bool enabled;

  /// °C. Null means "no lower limit check".
  final double? minTemp;

  /// °C. Null means "no upper limit check".
  final double? maxTemp;

  /// How many consecutive minutes the temperature must stay out of range
  /// before a notification is sent. Avoids alerting on a single noisy reading.
  final int sustainedMinutes;

  const TemperatureAlertSettings({
    this.enabled = false,
    this.minTemp,
    this.maxTemp,
    this.sustainedMinutes = 5,
  });

  static const disabled = TemperatureAlertSettings();

  bool get hasLimits => minTemp != null || maxTemp != null;

  factory TemperatureAlertSettings.fromFirestore(Map<String, dynamic>? data) {
    if (data == null) return disabled;
    return TemperatureAlertSettings(
      enabled: data['enabled'] as bool? ?? false,
      minTemp: (data['minTemp'] as num?)?.toDouble(),
      maxTemp: (data['maxTemp'] as num?)?.toDouble(),
      sustainedMinutes: (data['sustainedMinutes'] as num?)?.toInt() ?? 5,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'enabled': enabled,
        'minTemp': minTemp,
        'maxTemp': maxTemp,
        'sustainedMinutes': sustainedMinutes,
      };
}