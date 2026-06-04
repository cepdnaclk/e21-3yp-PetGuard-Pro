import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/admin_repository.dart';

class UserPetDetailsPage extends StatefulWidget {
  final String userId;

  const UserPetDetailsPage({super.key, required this.userId});

  @override
  State<UserPetDetailsPage> createState() => _UserPetDetailsPageState();
}

class _UserPetDetailsPageState extends State<UserPetDetailsPage> {
  final AdminRepository _adminRepository = AdminRepository();
  String? _currentPetId;
  List<String> _availablePetIds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final petId = await _adminRepository.getUserSelectedPetId(widget.userId);
      final allPetIds = await _adminRepository.getAllPetIds();
      if (mounted) {
        setState(() {
          _currentPetId = petId;
          _availablePetIds = allPetIds;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAssignDialog(BuildContext context) {
    final TextEditingController petIdController = TextEditingController();
    String? errorMessage;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Assign Collar (PetID)"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Current Pet ID Display
                    if (_currentPetId != null) ...[  
                      const Text(
                        "Current Pet ID:",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        _currentPetId!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                    ],
                    // Input Field
                    TextField(
                      controller: petIdController,
                      decoration: InputDecoration(
                        labelText: "Enter New Pet ID",
                        hintText: "e.g., default_pet, savintrack",
                        errorText: errorMessage,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() => errorMessage = null),
                    ),
                    const SizedBox(height: 12),
                    // Show already assigned pet IDs
                    if (_availablePetIds.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Already Assigned Pet IDs:",
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _availablePetIds.map((id) {
                              return Chip(
                                label: Text(id),
                                backgroundColor: Colors.red.shade100,
                                labelStyle: TextStyle(color: Colors.red.shade900, fontSize: 12),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                  ],
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
                    
                    if (petId.isEmpty) {
                      setState(() => errorMessage = "Pet ID cannot be empty");
                      return;
                    }

                    if (_availablePetIds.contains(petId)) {
                      setState(() => errorMessage = "This Pet ID already exists. Choose a different one.");
                      return;
                    }

                    if (petId == _currentPetId) {
                      setState(() => errorMessage = "This is already the current Pet ID.");
                      return;
                    }

                    try {
                      await _adminRepository.assignCollarToUser(widget.userId, petId);
                      
                      if (mounted) Navigator.pop(context);
                      await _loadUserData();
                      
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Pet ID '$petId' assigned successfully! 🎉"),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    } catch (e) {
                      setState(() => errorMessage = e.toString().replaceFirst('Exception: ', ''));
                    }
                  },
                  child: const Text("Approve Assignment"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pet Details"),
        backgroundColor: Colors.teal,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : Column(
              children: [
                // ─── Current Pet ID Display ─────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.pets, color: Colors.teal),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Currently Assigned Pet ID",
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                Text(
                                  _currentPetId ?? "No Pet ID assigned",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _currentPetId != null ? Colors.teal : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // ─── Assign Button ─────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ElevatedButton(
                    onPressed: () => _showAssignDialog(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text("Assign/Update Collar (PetID)"),
                  ),
                ),
                const SizedBox(height: 16),
                // ─── Pet List ─────────────────────────────
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _adminRepository.getUserPetsStream(widget.userId),
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
