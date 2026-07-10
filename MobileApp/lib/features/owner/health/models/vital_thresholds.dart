import 'health_vitals.dart';
import 'dog_profile.dart';

// ─────────────────────────────────────────────────────────────────────────────
// VitalThresholds — computed ranges for temperature and respiratory rate.
// All values are inclusive.
// ─────────────────────────────────────────────────────────────────────────────

class VitalThresholds {
  // Temperature (°C)
  final double tempNormalMin;
  final double tempNormalMax;
  final double tempCautionMin;  // always ≤ tempNormalMin
  final double tempCautionMax;  // always ≥ tempNormalMax

  // Respiratory rate (breaths / min)
  final int respNormalMin;
  final int respNormalMax;
  final int respCautionMin;     // always ≤ respNormalMin
  final int respCautionMax;     // always ≥ respNormalMax

  const VitalThresholds({
    required this.tempNormalMin,
    required this.tempNormalMax,
    required this.tempCautionMin,
    required this.tempCautionMax,
    required this.respNormalMin,
    required this.respNormalMax,
    required this.respCautionMin,
    required this.respCautionMax,
  });

  // ── Status helpers ──────────────────────────────────────────────────────────

  VitalStatus temperatureStatus(double temp) {
    if (temp >= tempNormalMin  && temp <= tempNormalMax)  return VitalStatus.normal;
    if (temp >= tempCautionMin && temp <= tempCautionMax) return VitalStatus.caution;
    return VitalStatus.danger;
  }

  VitalStatus respiratoryStatus(int rate) {
    if (rate >= respNormalMin  && rate <= respNormalMax)  return VitalStatus.normal;
    if (rate >= respCautionMin && rate <= respCautionMax) return VitalStatus.caution;
    return VitalStatus.danger;
  }

  // ── Factory: compute from a DogProfile ─────────────────────────────────────

  factory VitalThresholds.fromProfile(DogProfile p) {
    // ── Temperature ──────────────────────────────────────────────────────────
    // Baseline for a healthy adult medium dog with medium coat, normal breed,
    // moderate activity: normal 38.0–39.2 °C, caution 37.2–40.0 °C.

    double tNormalMin = 38.0;
    double tNormalMax = 39.2;

    // Age adjustments
    switch (p.age) {
      case DogAge.puppy:
        // Puppies run slightly warmer and tolerate less deviation
        tNormalMin -= 0.1;
        tNormalMax += 0.3;
      case DogAge.senior:
        // Seniors have lower thermoregulation capacity
        tNormalMax -= 0.2;
      case DogAge.adult:
        break;
    }

    // NOTE: Coat/fur type is NOT adjusted here — it is handled as a raw sensor
    // offset in HealthService.furOffsetForCoat() before the reading reaches
    // the UI. Adjusting thresholds for coat here would double-count that effect.

    // Flat-faced breeds overheat more easily
    if (p.breed == BreedFaceType.flatFaced) {
      tNormalMax -= 0.3;
    }

    // Activity level does not affect resting temperature thresholds.

    // Size adjustments (giant breeds run slightly cooler)
    switch (p.size) {
      case DogSize.giant:
        tNormalMin -= 0.1;
        tNormalMax -= 0.1;
      case DogSize.small:
        tNormalMin += 0.1;
        tNormalMax += 0.1;
      case DogSize.medium:
      case DogSize.large:
        break;
    }

    // Caution band is always ±0.8 °C around the normal band
    final tCautionMin = (tNormalMin - 0.8).clamp(35.0, 42.0);
    final tCautionMax = (tNormalMax + 0.8).clamp(35.0, 42.5);

    // Round to 1 decimal
    tNormalMin = _round1(tNormalMin);
    tNormalMax = _round1(tNormalMax);

    // ── Respiratory rate ─────────────────────────────────────────────────────
    // Baseline: normal 15–30 br/min, caution 10–40 br/min.

    int rNormalMin = 15;
    int rNormalMax = 30;

    // Size (larger dogs breathe more slowly)
    switch (p.size) {
      case DogSize.small:
        rNormalMin += 3;
        rNormalMax += 4;
      case DogSize.large:
        rNormalMin -= 2;
        rNormalMax -= 3;
      case DogSize.giant:
        rNormalMin -= 3;
        rNormalMax -= 5;
      case DogSize.medium:
        break;
    }

    // Age
    switch (p.age) {
      case DogAge.puppy:
        rNormalMin += 2;
        rNormalMax += 5;
      case DogAge.senior:
        // Seniors may breathe a bit faster due to reduced lung efficiency
        rNormalMax += 3;
      case DogAge.adult:
        break;
    }

    // Flat-faced breeds have naturally elevated respiratory rates
    if (p.breed == BreedFaceType.flatFaced) {
      rNormalMin += 2;
      rNormalMax += 5;
    }

    // Activity
    switch (p.activity) {
      case ActivityLevel.high:
        // High-activity dogs have stronger respiratory muscles; resting rate lower
        rNormalMin -= 1;
        rNormalMax -= 2;
      case ActivityLevel.low:
        rNormalMax += 2;
      case ActivityLevel.moderate:
        break;
    }

    // Caution band: ±8 br/min around normal band
    final rCautionMin = (rNormalMin - 8).clamp(4, rNormalMin - 1);
    final rCautionMax = (rNormalMax + 8).clamp(rNormalMax + 1, 70);

    return VitalThresholds(
      tempNormalMin:  tNormalMin,
      tempNormalMax:  tNormalMax,
      tempCautionMin: _round1(tCautionMin),
      tempCautionMax: _round1(tCautionMax),
      respNormalMin:  rNormalMin.clamp(8, 40),
      respNormalMax:  rNormalMax.clamp(10, 50),
      respCautionMin: rCautionMin,
      respCautionMax: rCautionMax,
    );
  }

  static double _round1(double v) => (v * 10).round() / 10;
}