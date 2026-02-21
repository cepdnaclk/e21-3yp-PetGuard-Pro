import '../models/pet_location.dart';
import '../models/geofence.dart';

/// Abstract interface for cloud data operations
/// This allows easy switching between Firebase, AWS, or any cloud provider
abstract class CloudRepository {
  /// Initialize the repository
  Future<void> initialize();

  /// Stream of real-time location updates from cloud
  Stream<PetLocation> getLocationStream(String petId);

  /// Upload a location to cloud
  Future<void> uploadLocation(String petId, PetLocation location);

  /// Save a geofence to cloud
  Future<void> saveGeofence(String petId, Geofence geofence);

  /// Delete a geofence from cloud
  Future<void> deleteGeofence(String petId, String geofenceId);

  /// Get all geofences for a pet
  Future<List<Geofence>> getGeofences(String petId);

  /// Stream of geofence updates
  Stream<List<Geofence>> getGeofencesStream(String petId);

  /// Upload location history
  Future<void> uploadLocationHistory(String petId, List<dynamic> history);

  /// Log an event (geofence breach, etc.)
  Future<void> logEvent(
    String petId,
    String eventType,
    Map<String, dynamic> data,
  );

  // NEW
  Future<List<Map<String, dynamic>>> getLocationHistory(String petId);
  Future<void> saveHistoryEntry(String petId, Map<String, dynamic> entry);
}
