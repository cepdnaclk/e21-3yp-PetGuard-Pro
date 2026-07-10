import 'package:flutter_test/flutter_test.dart';

// Mirrors classifyActivity() from PetGuard_Pro.ino / config.h
// THRESHOLD_IMPACT = 25.0, GYRO_THRESHOLD_IMPACT = 100.0 (compound condition)
// Accel-only shortcut = THRESHOLD_IMPACT + 5.0 = 30.0
const double thresholdImpact = 25.0;
const double gyroThresholdImpact = 100.0;
const double thresholdImpactShortcut = thresholdImpact + 5.0; // 30.0

bool isImpact(double accelMag, double gyroMag) {
  if (accelMag > thresholdImpact && gyroMag > gyroThresholdImpact) return true;
  if (accelMag > thresholdImpactShortcut) return true;
  return false;
}

void main() {
  group('[F1. ImpactEvent] classifyActivity impact detection — Equivalence Partitioning', () {
    test('resting: gravity baseline only, no motion', () {
      expect(isImpact(9.8, 0.0), isFalse);
    });
    test('active but non-impact: walking/running range', () {
      expect(isImpact(18.0, 40.0), isFalse);
    });
    test('impact via accel+gyro combo', () {
      expect(isImpact(26.0, 110.0), isTrue);
    });
    test('impact via accel-only shortcut', () {
      expect(isImpact(31.0, 10.0), isTrue);
    });
    test('high accel but gyro too low, below shortcut (compound-logic trap)', () {
      expect(isImpact(27.0, 50.0), isFalse);
    });
  });

  group('[F1. ImpactEvent] classifyActivity impact detection — Boundary Value Analysis', () {
    test('just below accel threshold (gyro high)', () {
      expect(isImpact(24.9, 150.0), isFalse);
    });
    test('exactly on accel threshold (strict >)', () {
      expect(isImpact(25.0, 150.0), isFalse);
    });
    test('just above accel threshold, gyro high', () {
      expect(isImpact(25.1, 150.0), isTrue);
    });
    test('just below gyro threshold (accel high)', () {
      expect(isImpact(26.0, 99.9), isFalse);
    });
    test('exactly on gyro threshold (strict >)', () {
      expect(isImpact(26.0, 100.0), isFalse);
    });
    test('just above gyro threshold', () {
      expect(isImpact(26.0, 100.1), isTrue);
    });
    test('just below shortcut threshold', () {
      expect(isImpact(29.9, 10.0), isFalse);
    });
    test('exactly on shortcut threshold (strict >)', () {
      expect(isImpact(30.0, 10.0), isFalse);
    });
    test('just above shortcut threshold', () {
      expect(isImpact(30.1, 10.0), isTrue);
    });
  });

  group('[F1. ImpactEvent] classifyActivity impact detection — Error / Negative Cases', () {
    test('all-zero vector: classifies as not impact, no exception', () {
      expect(isImpact(0.0, 0.0), isFalse);
    });
    test('NaN accel magnitude: falls through to not impact, no crash', () {
      expect(isImpact(double.nan, 150.0), isFalse);
    });
    test('negative accel magnitude: treated as below threshold, no exception', () {
      expect(() => isImpact(-5.0, 0.0), returnsNormally);
      expect(isImpact(-5.0, 0.0), isFalse);
    });
  });
}
