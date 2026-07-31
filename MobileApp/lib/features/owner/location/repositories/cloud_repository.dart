import '../models/pet_location.dart';
import '../models/geofence.dart';

abstract class CloudRepository {
  Future<void> initialize();
  Stream<PetLocation> getLocationStream(String petId);
  Future<void> uploadLocation(String petId, PetLocation location);
  Future<void> saveGeofence(String petId, Geofence geofence);
  Future<void> deleteGeofence(String petId, String geofenceId);
  Future<List<Geofence>> getGeofences(String petId);
  Stream<List<Geofence>> getGeofencesStream(String petId);
  Future<void> uploadLocationHistory(String petId, List history);
  Future<void> logEvent(String petId, String eventType, Map<String, dynamic> data);
  Future<List<Map<String, dynamic>>> getLocationHistory(String petId);
  Future<void> saveHistoryEntry(String petId, Map<String, dynamic> entry);
  Stream<List<Map<String, dynamic>>> getLocationHistoryStream(String petId);

  /// Write a command for the ESP32 collar firmware to read and act on.
  /// path: pets/{petId}/commands/{commandName}
  Future<void> sendCommand(
      String petId, String commandName, Map<String, dynamic> payload);
}
