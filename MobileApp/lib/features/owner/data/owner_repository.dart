import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class OwnerRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Cloudinary config ────────────────────────────────
  static const _cloudName    = 'dnlqsxql3';
  static const _uploadPreset = 'pet_photos';
  // ─────────────────────────────────────────────────────

  // Fetch user profile data
  Future<Map<String, dynamic>?> fetchUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc = await _firestore.collection('users').doc(user.uid).get();
    return doc.data();
  }

  // Update user profile
  Future<void> updateProfile({
    required String name,
    required String phone,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).update({
      'name': name,
      'phone': phone,
    });
  }

  // Change user email address via Firebase Auth verifyBeforeUpdateEmail
  Future<void> changeEmailAddress(String newEmail) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No logged-in user found.');
    final email = newEmail.trim();
    if (email.isEmpty) throw Exception('Email cannot be empty.');

    await user.verifyBeforeUpdateEmail(email);

    await _firestore.collection('users').doc(user.uid).update({
      'email': email,
    });
  }

  // Change password
  // Send password reset email
  Future<void> sendPasswordResetEmail() async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (email == null) throw Exception('No logged-in user email found.');
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Fetch all user pets
  Future<List<Map<String, dynamic>>> fetchUserPets() async {
    final user = _auth.currentUser;
    if (user == null) return [];
    final snapshot = await _firestore
        .collection('pets')
        .where('ownerUid', isEqualTo: user.uid)
        .get();
    return snapshot.docs
        .map((doc) => {...doc.data(), '_docId': doc.id})
        .toList();
  }

  // Fetch single user pet
  Future<Map<String, dynamic>?> fetchUserPet() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final pets = await _firestore
        .collection('pets')
        .where('ownerUid', isEqualTo: user.uid)
        .limit(1)
        .get();
    if (pets.docs.isEmpty) return null;
    final petDoc = pets.docs.first;
    return {...petDoc.data(), '_docId': petDoc.id};
  }

  // Save pet profile
  Future<void> savePetProfile({
    required String petName,
    required String? size,
    required String? ageGroup,
    required String? coatType,
    required String? isFlatFaced,
    required String? activityLevel,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('You must be logged in to add a pet.');
    final petData = {
      'petName': petName,
      'size': size,
      'ageGroup': ageGroup,
      'coatType': coatType,
      'isFlatFaced': isFlatFaced,
      'activityLevel': activityLevel,
      'ownerUid': user.uid,
      'photoUrl': null,
      'createdAt': FieldValue.serverTimestamp(),
    };
    await _firestore.collection('pets').add(petData);
  }

  // Update pet
  Future<void> updatePet(String petId, Map<String, dynamic> data) async {
    await _firestore.collection('pets').doc(petId).update(data);
  }

  // Upload pet photo to Cloudinary
  Future<String?> uploadPetPhoto(File photoFile, String docId) async {
    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
      );

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..fields['public_id']     = 'pet_photos/${docId}_${DateTime.now().millisecondsSinceEpoch}'
        ..files.add(
          await http.MultipartFile.fromPath('file', photoFile.path),
        );

      final response     = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode != 200) {
        throw Exception('Cloudinary upload failed: $responseBody');
      }

      final json = jsonDecode(responseBody);
      final url  = json['secure_url'] as String;

      // *** NEW *** Cache-bust so the app always loads the fresh photo
      final cacheBustedUrl = '$url?v=${DateTime.now().millisecondsSinceEpoch}';

      // Save the cache-busted URL into Firestore
      await _firestore
          .collection('pets')
          .doc(docId)
          .update({'photoUrl': cacheBustedUrl}); // *** CHANGED from url ***

      return cacheBustedUrl; // *** CHANGED from url ***
    } catch (e) {
      throw Exception('Photo upload failed: $e');
    }
  }

  // Pick image from gallery and upload to Cloudinary
  Future<String?> pickAndUploadPhoto({
    required String docId,
    required Function(String) onError,
  }) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source:       ImageSource.gallery,
        imageQuality: 80,
        maxWidth:     800,
      );

      if (picked == null) return null;

      return await uploadPetPhoto(File(picked.path), docId);
    } catch (e) {
      onError(e.toString());
      return null;
    }
  }

  // Get current user's first name
  String getFirstName() {
    final display = _auth.currentUser?.displayName?.trim() ?? '';
    if (display.isEmpty) return 'there';
    return display.split(RegExp(r'\s+')).first;
  }

  // Fetch user pet with ID
  Future<Map<String, dynamic>?> fetchUserPetWithId() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final querySnap = await _firestore
        .collection('pets')
        .where('ownerUid', isEqualTo: user.uid)
        .limit(1)
        .get();
    if (querySnap.docs.isEmpty) return null;
    final petDoc = querySnap.docs.first;
    return <String, dynamic>{...petDoc.data(), '_docId': petDoc.id};
  }

  // Sign out user
  Future<void> signOut() async {
    await _auth.signOut();
  }
}