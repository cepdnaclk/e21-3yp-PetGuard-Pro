import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../repositories/health_repository.dart';
import '../repositories/firebase_health_repository.dart';
import '../models/health_vitals.dart';
import '../models/dog_profile.dart';
import '../models/respiratory_alert_settings.dart';
import '../models/temperature_alert_settings.dart';
import '../../location/services/notification_service.dart';

class HealthService {
  // Singleton
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  late HealthRepository _repository = FirebaseHealthRepository();

  // ── Collar alignment detection state ──────────────────────────────────────
  // A temperature below this almost certainly means the sensor is reading
  // ambient air rather than the dog's skin surface.
  static const double _collarMinPlausibleTemp = 30.0;
  static const double _collarMaxPlausibleTemp = 45.0;
  static const int _collarOutOfRangeThreshold = 5; // consecutive bad readings

  int _consecutiveOutOfRangeCount = 0;
  bool _collarAlertSent = false;

  Future<void> initialize() async {
    await _repository.initialize();
    debugPrint('Health service initialized');
  }

  Future<String> _getPetId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'default_pet';

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists) return 'default_pet';
    final data = doc.data();
    if (data == null) return 'default_pet';

    return data['selectedPetId'] ?? 'default_pet';
  }

  /// Returns the fur offset in °C for the given coat type.
  /// Short/hairless: +0.5 | Medium: +1.0 | Long & thick: +1.8
  static double furOffsetForCoat(CoatType coat) {
    switch (coat) {
      case CoatType.shortOrHairless: return 0.5;
      case CoatType.medium:          return 1.0;
      case CoatType.longAndThick:    return 1.8;
    }
  }

  /// Checks whether the raw temperature is physically plausible for a sensor
  /// in contact with a dog's skin. Updates the consecutive out-of-range counter
  /// and fires a local notification if the collar appears misaligned.
  void _checkCollarAlignment(double rawTemp) {
    final isOutOfRange = rawTemp < _collarMinPlausibleTemp ||
        rawTemp > _collarMaxPlausibleTemp;

    if (isOutOfRange) {
      _consecutiveOutOfRangeCount++;
      debugPrint(
          '⚠️ Collar out-of-range reading #$_consecutiveOutOfRangeCount '
          '(raw: ${rawTemp.toStringAsFixed(1)}°C)');

      if (_consecutiveOutOfRangeCount >= _collarOutOfRangeThreshold &&
          !_collarAlertSent) {
        _collarAlertSent = true;
        NotificationService().showNotification(
          title: '🐾 Check your dog\'s collar',
          body: 'The temperature sensor may not be in contact with your dog\'s skin. '
              'Please make sure the collar is properly fitted.',
        );
        debugPrint('📱 Collar alignment notification sent');
      }
    } else {
      // Reset as soon as a valid reading comes in
      _consecutiveOutOfRangeCount = 0;
      _collarAlertSent = false;
    }
  }

  /// Streams live vitals with the fur offset applied and collar alignment checked.
  Stream<HealthVitals> getHealthVitalsStream() async* {
    final petId = await _getPetId();
    final profile = await _getDogProfile(petId);
    final offset = furOffsetForCoat(profile.coat);

    yield* _repository
        .getHealthVitalsStream(petId)
        .map((v) {
          _checkCollarAlignment(v.temperature);
          return v.withFurOffset(offset);
        });
  }

  Future<List<HealthVitals>> getHealthHistoryForDay(DateTime day) async {
    final petId = await _getPetId();
    final profile = await _getDogProfile(petId);
    final offset = furOffsetForCoat(profile.coat);

    final raw = await _repository.getHealthHistoryForDay(petId, day);
    return raw.map((v) => v.withFurOffset(offset)).toList();
  }

  Stream<List<HealthVitals>> getHealthHistoryStream(DateTime day) async* {
    final petId = await _getPetId();
    final profile = await _getDogProfile(petId);
    final offset = furOffsetForCoat(profile.coat);

    yield* _repository
        .getHealthHistoryStream(petId, day)
        .map((list) => list.map((v) => v.withFurOffset(offset)).toList());
  }

  /// Fetches the dog profile once from Firestore.
  Future<DogProfile> _getDogProfile(String petId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('pets')
          .doc(petId)
          .get();
      if (!snap.exists || snap.data() == null) return DogProfile.defaults;
      return DogProfile.fromFirestore(snap.data()!);
    } catch (_) {
      return DogProfile.defaults;
    }
  }

  void setRepository(HealthRepository repository) {
    _repository = repository;
    debugPrint('Health repository switched');
  }

  // ── Custom respiratory rate alerts ──────────────────────────────────────

  /// Streams the user's custom respiratory-rate alert settings for their
  /// currently selected pet.
  Stream<RespiratoryAlertSettings> getRespiratoryAlertSettingsStream() async* {
    final petId = await _getPetId();
    yield* FirebaseFirestore.instance
        .collection('pets')
        .doc(petId)
        .snapshots()
        .map((snap) => RespiratoryAlertSettings.fromFirestore(
            snap.data()?['respiratoryAlertSettings'] as Map<String, dynamic>?));
  }

  /// Persists the user's custom respiratory-rate alert settings.
  Future<void> saveRespiratoryAlertSettings(
      RespiratoryAlertSettings settings) async {
    final petId = await _getPetId();
    await FirebaseFirestore.instance.collection('pets').doc(petId).set(
      {'respiratoryAlertSettings': settings.toFirestore()},
      SetOptions(merge: true),
    );
  }

  // Tracks how long the current reading has stayed continuously out of the
  // user's custom range, and whether we've already alerted for this streak.
  DateTime? _respOutOfRangeSince;
  bool _respAlertSent = false;

  /// Checks a live reading against the user's custom respiratory-rate
  /// limits (if enabled) and fires a notification once the rate has stayed
  /// continuously out of range for [RespiratoryAlertSettings.sustainedMinutes].
  /// Only one notification is sent per continuous out-of-range streak; the
  /// streak resets as soon as a reading comes back in range.
  void checkCustomRespiratoryAlert(
    HealthVitals vitals,
    RespiratoryAlertSettings settings,
  ) {
    if (!settings.enabled || !settings.hasLimits || vitals.respiratoryRate <= 0) {
      _respOutOfRangeSince = null;
      _respAlertSent = false;
      return;
    }

    final rate = vitals.respiratoryRate;
    final belowMin = settings.minRate != null && rate < settings.minRate!;
    final aboveMax = settings.maxRate != null && rate > settings.maxRate!;

    if (!belowMin && !aboveMax) {
      _respOutOfRangeSince = null;
      _respAlertSent = false;
      return;
    }

    // Use the sensor's own timestamp (not wall-clock "now") so the sustained
    // duration reflects actual elapsed sensor time, not app processing time.
    _respOutOfRangeSince ??= vitals.timestamp;
    final sustainedFor = vitals.timestamp.difference(_respOutOfRangeSince!);

    if (!_respAlertSent &&
        sustainedFor >= Duration(minutes: settings.sustainedMinutes)) {
      _respAlertSent = true;
      final direction = aboveMax ? 'above' : 'below';
      final limit = aboveMax ? settings.maxRate : settings.minRate;

      debugPrint(
          '⚠️ Respiratory rate $direction custom limit ($limit br/min) '
          'for ${settings.sustainedMinutes}+ min — sending alert');

      NotificationService().showNotification(
        title: '⚠️ Respiratory Rate Out of Range',
        body: 'Rate has stayed $direction your $limit br/min limit for '
            '${settings.sustainedMinutes}+ min (currently $rate br/min).',
      );
    }
  }

  // ── Custom temperature alerts ───────────────────────────────────────────

  /// Streams the user's custom temperature alert settings for their
  /// currently selected pet.
  Stream<TemperatureAlertSettings> getTemperatureAlertSettingsStream() async* {
    final petId = await _getPetId();
    yield* FirebaseFirestore.instance
        .collection('pets')
        .doc(petId)
        .snapshots()
        .map((snap) => TemperatureAlertSettings.fromFirestore(
            snap.data()?['temperatureAlertSettings'] as Map<String, dynamic>?));
  }

  /// Persists the user's custom temperature alert settings.
  Future<void> saveTemperatureAlertSettings(
      TemperatureAlertSettings settings) async {
    final petId = await _getPetId();
    await FirebaseFirestore.instance.collection('pets').doc(petId).set(
      {'temperatureAlertSettings': settings.toFirestore()},
      SetOptions(merge: true),
    );
  }

  // Tracks how long the current reading has stayed continuously out of the
  // user's custom range, and whether we've already alerted for this streak.
  DateTime? _tempOutOfRangeSince;
  bool _tempAlertSent = false;

  /// Checks a live reading against the user's custom temperature limits (if
  /// enabled) and fires a notification once the temperature has stayed
  /// continuously out of range for [TemperatureAlertSettings.sustainedMinutes].
  /// Only one notification is sent per continuous out-of-range streak; the
  /// streak resets as soon as a reading comes back in range.
  void checkCustomTemperatureAlert(
    HealthVitals vitals,
    TemperatureAlertSettings settings,
  ) {
    if (!settings.enabled || !settings.hasLimits || vitals.temperature <= 0) {
      _tempOutOfRangeSince = null;
      _tempAlertSent = false;
      return;
    }

    final temp = vitals.calibratedTemperature;
    final belowMin = settings.minTemp != null && temp < settings.minTemp!;
    final aboveMax = settings.maxTemp != null && temp > settings.maxTemp!;

    if (!belowMin && !aboveMax) {
      _tempOutOfRangeSince = null;
      _tempAlertSent = false;
      return;
    }

    // Use the sensor's own timestamp (not wall-clock "now") so the sustained
    // duration reflects actual elapsed sensor time, not app processing time.
    _tempOutOfRangeSince ??= vitals.timestamp;
    final sustainedFor = vitals.timestamp.difference(_tempOutOfRangeSince!);

    if (!_tempAlertSent &&
        sustainedFor >= Duration(minutes: settings.sustainedMinutes)) {
      _tempAlertSent = true;
      final direction = aboveMax ? 'above' : 'below';
      final limit = aboveMax ? settings.maxTemp : settings.minTemp;

      debugPrint(
          '⚠️ Temperature $direction custom limit (${limit?.toStringAsFixed(1)}°C) '
          'for ${settings.sustainedMinutes}+ min — sending alert');

      NotificationService().showNotification(
        title: '⚠️ Temperature Out of Range',
        body: 'Temperature has stayed $direction your ${limit?.toStringAsFixed(1)}°C '
            'limit for ${settings.sustainedMinutes}+ min '
            '(currently ${temp.toStringAsFixed(1)}°C).',
      );
    }
  }
}