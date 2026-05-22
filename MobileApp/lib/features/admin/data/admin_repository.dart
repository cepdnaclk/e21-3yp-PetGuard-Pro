import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    await _firestore.collection('users').doc(userId).update({
      'selectedPetId': petId,
    });
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
