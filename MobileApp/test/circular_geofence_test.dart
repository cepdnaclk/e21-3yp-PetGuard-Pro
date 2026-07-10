import 'package:flutter_test/flutter_test.dart';

// distanceMeters() uses the Haversine formula; mocked here as a
// direct distance value so the boundary logic is isolated from GPS math.
bool checkBreach(double distanceMeters, double radiusMeters) {
  return distanceMeters > radiusMeters;
}

void main() {
  const radius = 100.0;
  
  group('[F3. Circular Geofence] CircularGeofence.checkBreach — EP', () {
    test('well inside', () => expect(checkBreach(radius - 50, radius), isFalse));
    test('well outside', () => expect(checkBreach(radius + 50, radius), isTrue));
  });

  group('[F3. Circular Geofence] BVA', () {
    test('radius - 1 -> inside', () => expect(checkBreach(radius - 1, radius), isFalse));
    test('exactly on radius -> inside', () => expect(checkBreach(radius, radius), isFalse));
    test('radius + 1 -> breach', () => expect(checkBreach(radius + 1, radius), isTrue));
  });

  group('[F3. Circular Geofence] Error cases', () {
    test('zero radius -> any positive distance breaches', () {
      expect(checkBreach(1, 0), isTrue);
    });
    test('negative radius does not throw', () {
      expect(() => checkBreach(5, -10), returnsNormally);
    });
  });
}
