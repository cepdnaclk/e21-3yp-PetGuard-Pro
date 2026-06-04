// ─────────────────────────────────────────────────────────────────────────────
// DogProfile — parsed from the Firestore pet document.
// The string values match exactly what PetDetailsFormPage saves.
// ─────────────────────────────────────────────────────────────────────────────

enum DogSize        { small, medium, large, giant }
enum DogAge         { puppy, adult, senior }
enum CoatType       { shortOrHairless, medium, longAndThick }
enum BreedFaceType  { flatFaced, normal, unsure }
enum ActivityLevel  { low, moderate, high }

class DogProfile {
  final DogSize size;
  final DogAge age;
  final CoatType coat;
  final BreedFaceType breed;
  final ActivityLevel activity;

  const DogProfile({
    required this.size,
    required this.age,
    required this.coat,
    required this.breed,
    required this.activity,
  });

  static const DogProfile defaults = DogProfile(
    size:     DogSize.medium,
    age:      DogAge.adult,
    coat:     CoatType.medium,
    breed:    BreedFaceType.normal,
    activity: ActivityLevel.moderate,
  );

  /// Parse from a Firestore pet document map.
  /// Falls back to [defaults] for any unrecognised / null value.
  factory DogProfile.fromFirestore(Map<String, dynamic> data) {
    return DogProfile(
      size:     _parseSize(data['size']         as String?),
      age:      _parseAge(data['ageGroup']       as String?),
      coat:     _parseCoat(data['coatType']      as String?),
      breed:    _parseBreed(data['isFlatFaced']  as String?),
      activity: _parseActivity(data['activityLevel'] as String?),
    );
  }

  static DogSize _parseSize(String? v) {
    if (v == null) return DogSize.medium;
    if (v.startsWith('Small'))  return DogSize.small;
    if (v.startsWith('Medium')) return DogSize.medium;
    if (v.startsWith('Large'))  return DogSize.large;
    if (v.startsWith('Giant'))  return DogSize.giant;
    return DogSize.medium;
  }

  static DogAge _parseAge(String? v) {
    if (v == null) return DogAge.adult;
    if (v.startsWith('Puppy'))  return DogAge.puppy;
    if (v.startsWith('Adult'))  return DogAge.adult;
    if (v.startsWith('Senior')) return DogAge.senior;
    return DogAge.adult;
  }

  static CoatType _parseCoat(String? v) {
    if (v == null) return CoatType.medium;
    if (v.startsWith('Short'))  return CoatType.shortOrHairless;
    if (v.startsWith('Medium')) return CoatType.medium;
    if (v.startsWith('Long'))   return CoatType.longAndThick;
    return CoatType.medium;
  }

  static BreedFaceType _parseBreed(String? v) {
    if (v == null) return BreedFaceType.unsure;
    if (v == 'Yes')      return BreedFaceType.flatFaced;
    if (v == 'No')       return BreedFaceType.normal;
    return BreedFaceType.unsure;
  }

  static ActivityLevel _parseActivity(String? v) {
    if (v == null) return ActivityLevel.moderate;
    if (v.startsWith('Low'))      return ActivityLevel.low;
    if (v.startsWith('Moderate')) return ActivityLevel.moderate;
    if (v.startsWith('High'))     return ActivityLevel.high;
    return ActivityLevel.moderate;
  }
}
