import 'package:flutter_test/flutter_test.dart';

bool validateTemperature(double? t) {
  if (t == null || t.isNaN) return false;
  return t >= 35.0 && t <= 42.0;
}

void main() {
  group('[F2. HealthVitals] HealthVitals.validateTemperature — EP', () {
    test('below range', () => expect(validateTemperature(30.0), isFalse));
    test('within range', () => expect(validateTemperature(38.5), isTrue));
    test('above range', () => expect(validateTemperature(45.0), isFalse));
  });

  group('[F2. HealthVitals] BVA', () {
    test('34.9 -> false', () => expect(validateTemperature(34.9), isFalse));
    test('35.0 -> true', () => expect(validateTemperature(35.0), isTrue));
    test('35.1 -> true', () => expect(validateTemperature(35.1), isTrue));
    test('41.9 -> true', () => expect(validateTemperature(41.9), isTrue));
    test('42.0 -> true', () => expect(validateTemperature(42.0), isTrue));
    test('42.1 -> false', () => expect(validateTemperature(42.1), isFalse));
  });

  group('[F2. HealthVitals] Error cases', () {
    test('null reading', () => expect(validateTemperature(null), isFalse));
    test('NaN reading', () => expect(validateTemperature(double.nan), isFalse));
    test('negative temperature', () => expect(validateTemperature(-5.0), isFalse));
  });
}
