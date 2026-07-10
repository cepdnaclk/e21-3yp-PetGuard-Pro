import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// ===========================================================
/// PET AUTHORIZATION MODULE
/// ===========================================================
///
/// FLOW:
/// 1. Check logged-in Firebase user
/// 2. Go to Firestore users collection
/// 3. Read selectedPetId
/// 4. Return correct RTDB collection path
///
/// Example:
///
/// Firestore:
/// users/{uid}
///    selectedPetId: "collar_001"
///
/// Returned:
/// "collar_001"
///
/// RTDB usage:
/// pets/collar_001/...
///
/// ===========================================================

class PetAuthorizationModule {
  PetAuthorizationModule._();

  static final PetAuthorizationModule instance =
      PetAuthorizationModule._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// -----------------------------------------------------------
  /// Returns currently authenticated Firebase user
  /// -----------------------------------------------------------
  User get currentUser {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No authenticated user found.');
    }

    return user;
  }

  /// -----------------------------------------------------------
  /// Returns Firebase UID
  /// -----------------------------------------------------------
  String get currentUserId {
    return currentUser.uid;
  }

  /// -----------------------------------------------------------
  /// Checks whether a user is logged in
  /// -----------------------------------------------------------
  bool get isLoggedIn {
    return _auth.currentUser != null;
  }

  /// -----------------------------------------------------------
  /// Gets Firestore user document
  /// users/{uid}
  /// -----------------------------------------------------------
  Future<DocumentSnapshot<Map<String, dynamic>>> getUserDocument() async {
    return await _firestore
        .collection('users')
        .doc(currentUserId)
        .get();
  }

  /// -----------------------------------------------------------
  /// Returns selectedPetId from Firestore
  /// -----------------------------------------------------------
  Future<String> getSelectedPetId() async {
    final doc = await getUserDocument();

    if (!doc.exists) {
      throw Exception('User document does not exist.');
    }

    final data = doc.data();

    if (data == null) {
      throw Exception('User document data is empty.');
    }

    final selectedPetId = data['selectedPetId'];

    if (selectedPetId == null) {
      throw Exception('selectedPetId not found.');
    }

    if (selectedPetId.toString().trim().isEmpty) {
      throw Exception('selectedPetId is empty.');
    }

    return selectedPetId.toString();
  }

  /// -----------------------------------------------------------
  /// Returns full RTDB pet path
  ///
  /// Example:
  /// pets/default_pet
  /// pets/collar_001
  /// -----------------------------------------------------------
  Future<String> getPetDatabasePath() async {
    final petId = await getSelectedPetId();

    return 'pets/$petId';
  }

  /// -----------------------------------------------------------
  /// Optional helper:
  /// Returns raw Firestore user data
  /// -----------------------------------------------------------
  Future<Map<String, dynamic>> getUserData() async {
    final doc = await getUserDocument();

    final data = doc.data();

    if (data == null) {
      throw Exception('User data is null.');
    }

    return data;
  }
}