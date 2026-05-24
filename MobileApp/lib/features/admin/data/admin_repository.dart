import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class AdminRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, String>> fetchStats() async {
    final usersSnap = await _firestore.collection('users').get();
    final devicesSnap = await _firestore.collection('devices').get();
    final alertsSnap = await _firestore
        .collection('alerts')
        .where('status', isEqualTo: 'Pending')
        .get();

    final devices = devicesSnap.docs;
    double totalConnectivity = 0;
    for (var d in devices) {
      totalConnectivity += (d['connectivity'] ?? 0);
    }

    final connectivity =
        devices.isNotEmpty ? "${(totalConnectivity / devices.length).round()}%" : "0%";

    return {
      'users': usersSnap.size.toString(),
      'devices': devicesSnap.size.toString(),
      'alerts': alertsSnap.size.toString(),
      'connectivity': connectivity,
    };
  }

  Future<void> deleteUser(DocumentSnapshot user) async {
    await user.reference.delete();
  }

  Future<void> updateUserStatus(DocumentSnapshot user, String newStatus) async {
    await user.reference.update({'status': newStatus});
  }

  Future<void> assignCollarToUser(String userId, String petId) async {
    final rtdb = FirebaseDatabase.instance;
    
    // Check if the pet path already exists in RTDB
    final petRef = rtdb.ref('pets/$petId');
    final snapshot = await petRef.get();
    
    if (snapshot.exists) {
      throw Exception('Pet ID "$petId" already exists in the database. Choose a different ID.');
    }
    
    // Create the pet structure in RTDB
    await petRef.set({
      'activity': {
        'current': {
          'accelerometer': {'x': 0, 'y': 0, 'z': 0},
          'active_minutes': 0,
          'activity_type': 'idle',
          'gyroscope': {'x': 0, 'y': 0, 'z': 0},
          'impact_detected': false,
          'impact_severity': 0,
          'magnitude': 0,
          'step_count': 0,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
        'history': {},
      },
      'health': {},
      'location': {},
    });
    
    // Update Firestore with the selected pet ID
    await _firestore.collection('users').doc(userId).update({
      'selectedPetId': petId,
    });
  }
  
  // ─── Check if pet exists in RTDB ─────────────────────────────────────────
  Future<bool> petExistsInRtdb(String petId) async {
    final rtdb = FirebaseDatabase.instance;
    final snapshot = await rtdb.ref('pets/$petId').get();
    return snapshot.exists;
  }
  
  // ─── Get all pet IDs from RTDB ──────────────────────────────────────────
  Future<List<String>> getAllPetIds() async {
    try {
      final rtdb = FirebaseDatabase.instance;
      final snapshot = await rtdb.ref('pets').get();
      if (!snapshot.exists) return [];
      final data = snapshot.value as Map<dynamic, dynamic>? ?? {};
      return data.keys.cast<String>().toList();
    } catch (e) {
      debugPrint('Error fetching pet IDs from RTDB: $e');
      return [];
    }
  }
  
  // ─── Get user's current selected pet ID ──────────────────────────────────
  Future<String?> getUserSelectedPetId(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      return doc.data()?['selectedPetId'] as String?;
    } catch (e) {
      debugPrint('Error fetching user selected pet ID: $e');
      return null;
    }
  }

  // ─── Stream: Get all users ─────────────────────────────────────────────────
  Stream<QuerySnapshot> getUsersStream() {
    return _firestore.collection('users').snapshots();
  }

  // ─── Stream: Get pets for a specific user ──────────────────────────────────
  Stream<QuerySnapshot> getUserPetsStream(String userId) {
    return _firestore
        .collection('pets')
        .where('ownerUid', isEqualTo: userId)
        .snapshots();
  }

  // ─── Sign out ────────────────────────────────────────────────────────────── 
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ─── Helper: Get status color ──────────────────────────────────────────────
  /// Returns color based on user status
  String getStatusColor(String status) {
    if (status == 'Active') return 'green';
    if (status == 'Pending') return 'orange';
    if (status == 'Inactive') return 'red';
    return 'grey';
  }
}
