// ─────────────────────────────────────────────────────────────────────────────
// RespiratoryAlertSettings — user-configurable custom limits for respiratory
// rate, layered on top of the auto-computed VitalThresholds. Stored per pet
// in Firestore under pets/{petId}.respiratoryAlertSettings.
// ─────────────────────────────────────────────────────────────────────────────

class RespiratoryAlertSettings {
  final bool enabled;

  /// Breaths/min. Null means "no lower limit check".
  final int? minRate;

  /// Breaths/min. Null means "no upper limit check".
  final int? maxRate;

  /// How many consecutive minutes the rate must stay out of range before
  /// a notification is sent. Avoids alerting on a single noisy reading.
  final int sustainedMinutes;

  const RespiratoryAlertSettings({
    this.enabled = false,
    this.minRate,
    this.maxRate,
    this.sustainedMinutes = 5,
  });

  static const disabled = RespiratoryAlertSettings();

  bool get hasLimits => minRate != null || maxRate != null;

  factory RespiratoryAlertSettings.fromFirestore(Map<String, dynamic>? data) {
    if (data == null) return disabled;
    return RespiratoryAlertSettings(
      enabled: data['enabled'] as bool? ?? false,
      minRate: (data['minRate'] as num?)?.toInt(),
      maxRate: (data['maxRate'] as num?)?.toInt(),
      sustainedMinutes: (data['sustainedMinutes'] as num?)?.toInt() ?? 5,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'enabled': enabled,
        'minRate': minRate,
        'maxRate': maxRate,
        'sustainedMinutes': sustainedMinutes,
      };
}