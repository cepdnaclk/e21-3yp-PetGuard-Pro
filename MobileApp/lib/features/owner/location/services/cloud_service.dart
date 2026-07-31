// lib/features/owner/location/services/cloud_service.dart

import 'package:flutter/foundation.dart';
import '../repositories/cloud_repository.dart';
import '../repositories/firebase_repository.dart';
import '../models/pet_location.dart';
import '../models/geofence.dart';
import '../models/location_history_entry.dart';
import '../../../auth/services/pet_authorization_module.dart';

class CloudService {
  static final CloudService _instance = CloudService._internal();
  factory CloudService() => _instance;
  CloudService._internal();

  late CloudRepository _repository = FirebaseRepository();

  // ─────────────────────────────────────────────────────────────
  // FIX: exposed as a public method so location_provider.dart
  // can resolve the petId once via locationPetIdProvider and
  // pass it explicitly to stream/history methods.
  // Previously every method called this privately, which meant
  // the singleton resolved the ID at stream-start time and then
  // never re-resolved it — causing stale data after account switch.
  // ─────────────────────────────────────────────────────────────
  Future<String> getPetId() async {
    return await PetAuthorizationModule.instance.getSelectedPetId();
  }

  Future<void> initialize() async {
    await _repository.initialize();
    debugPrint('Cloud service initialized');
  }

  // ─────────────────────────────────────────────────────────────
  // Original method kept for backward compatibility.
  // Internally resolves petId each time it's called.
  // ─────────────────────────────────────────────────────────────
  Stream<PetLocation> getLocationStream() async* {
    final petId = await getPetId();
    yield* _repository.getLocationStream(petId);
  }

  // ─────────────────────────────────────────────────────────────
  // FIX: new explicit-petId version used by locationStreamProvider.
  // The provider resolves petId once via locationPetIdProvider,
  // then calls this — so the stream is always for the correct pet
  // and doesn't need to re-resolve on every emission.
  // ─────────────────────────────────────────────────────────────
  Stream<PetLocation> getLocationStreamForPet(String petId) {
    return _repository.getLocationStream(petId);
  }

  Future<void> uploadLocation(PetLocation location) async {
    final petId = await getPetId();
    await _repository.uploadLocation(petId, location);
  }

  Future<void> saveGeofence(Geofence geofence) async {
    final petId = await getPetId();
    await _repository.saveGeofence(petId, geofence);
  }

  Future<void> deleteGeofence(String geofenceId) async {
    final petId = await getPetId();
    await _repository.deleteGeofence(petId, geofenceId);
  }

  Future<List<Geofence>> getGeofences() async {
    final petId = await getPetId();
    return await _repository.getGeofences(petId);
  }

  Stream<List<Geofence>> getGeofencesStream() async* {
    final petId = await getPetId();
    yield* _repository.getGeofencesStream(petId);
  }

  Future<void> uploadHistory(List history) async {
    final petId = await getPetId();
    await _repository.uploadLocationHistory(petId, history);
  }

  Future<void> logEvent(String eventType, Map<String, dynamic> data) async {
    final petId = await getPetId();
    await _repository.logEvent(petId, eventType, data);
  }

  // ─────────────────────────────────────────────────────────────
  // Original — resolves petId internally each call.
  // ─────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getLocationHistory() async {
    final petId = await getPetId();
    return await _repository.getLocationHistory(petId);
  }

  // ─────────────────────────────────────────────────────────────
  // FIX: explicit-petId version used by history providers.
  // Avoids the singleton resolving a stale petId inside the
  // polling loop after an account switch.
  // ─────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getLocationHistoryForPet(
      String petId) async {
    return await _repository.getLocationHistory(petId);
  }

  Future<void> saveHistoryEntry(LocationHistoryEntry entry) async {
    final petId = await getPetId();
    await _repository.saveHistoryEntry(petId, entry.toJson());
  }

  void setRepository(CloudRepository repository) {
    _repository = repository;
    debugPrint('Cloud repository switched');
  }

  Stream<List<Map<String, dynamic>>> getLocationHistoryStream() async* {
    final petId = await getPetId();
    yield* _repository.getLocationHistoryStream(petId);
  }

  /// Sends a buzzer command to the collar via Firebase.
  /// The ESP32 firmware polls `pets/{petId}/commands/buzzer` and
  /// triggers the buzzer when it finds `active: true`.
  Future<void> sendBuzzerCommand(bool active) async {
    final petId = await getPetId();
    await _repository.sendCommand(petId, 'buzzer', {
      'active': active,
      'timestamp': DateTime.now().toIso8601String(),
    });
    debugPrint('Buzzer command sent: active=$active');
  }

  /// Clears a command after the collar has acknowledged it.
  Future<void> clearCommand(String commandName) async {
    final petId = await getPetId();
    await _repository.sendCommand(petId, commandName, {
      'active': false,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}
