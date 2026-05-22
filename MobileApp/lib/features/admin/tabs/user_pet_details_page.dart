import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/admin_repository.dart';
import '../../owner/activity/services/activity_notification_service.dart';

class UserPetDetailsPage extends StatelessWidget {
  final AdminRepository _adminRepository = AdminRepository();
  final String userId;

  UserPetDetailsPage({super.key, required this.userId});

  // ─────────────────────────────────────────────────────────────
  // 🔹 Show Assign Collar Dialog
  // ─────────────────────────────────────────────────────────────
  void _showAssignDialog(BuildContext context) {
    final TextEditingController petIdController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Assign Collar (PetID)"),
          content: TextField(
            controller: petIdController,
            decoration: const InputDecoration(
              labelText: "Enter Collar Device ID",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final petId = petIdController.text.trim();
                if (petId.isEmpty) return;
                try {
                  await _adminRepository.assignCollarToUser(userId, petId);
                  await ActivityNotificationService().refreshPetListener();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Collar assigned successfully"),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Error: $e"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text("Approve Assignment"),
            ),
          ],
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 🔹 Build UI
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pet Details"),
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          // ─── Assign Button ─────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton(
              onPressed: () => _showAssignDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              child: const Text("Assign Collar (PetID)"),
            ),
          ),

          // ─── Pet List ─────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _adminRepository.getUserPetsStream(userId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final pets = snapshot.data!.docs;

                if (pets.isEmpty) {
                  return const Center(
                      child: Text("No pets found for this user"));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: pets.length,
                  itemBuilder: (context, index) {
                    final data =
                        pets[index].data() as Map<String, dynamic>? ?? {};

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['petName'] ?? 'No Name',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text("Size: ${data['size'] ?? 'N/A'}"),
                            Text("Age: ${data['ageGroup'] ?? 'N/A'}"),
                            Text("Coat: ${data['coatType'] ?? 'N/A'}"),
                            Text("Flat Faced: ${data['isFlatFaced'] ?? 'N/A'}"),
                            Text(
                                "Activity Level: ${data['activityLevel'] ?? 'N/A'}"),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
