import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class EditUserDialog extends StatefulWidget {
  final DocumentSnapshot user;

  const EditUserDialog({super.key, required this.user});

  @override
  State<EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<EditUserDialog> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _petsController;
  late TextEditingController _selectedPetIdController;
  String _selectedStatus = 'Active';

  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();

    final data = widget.user.data() as Map<String, dynamic>? ?? {};

    _nameController = TextEditingController(text: data['name'] ?? '');
    _emailController = TextEditingController(text: data['email'] ?? '');
    _petsController =
        TextEditingController(text: (data['pets'] ?? 0).toString());
    _selectedPetIdController =
        TextEditingController(text: data['selectedPetId'] ?? '');
    _selectedStatus = data['status'] ?? 'Active';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 400,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Edit User',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildField('Name', _nameController),
                    const SizedBox(height: 16),
                    _buildField('Email', _emailController),
                    const SizedBox(height: 16),
                    _buildField(
                      'Number of Pets',
                      _petsController,
                      isNumber: true,
                    ),
                    const SizedBox(height: 16),
                    _buildField('Selected Pet ID', _selectedPetIdController),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Status',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedStatus,
                            isExpanded: true,
                            underline: const SizedBox(),
                            items: ['Active', 'Inactive', 'Pending']
                                .map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedStatus = newValue!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _updateUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Update User'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: controller,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _createInitialPetStructureIfNeeded(String petId) async {
    final petRef = _db.child('pets/$petId');

    final Map<String, dynamic> defaultStructure = {
      'activity': {
        'current': {
          'accelerometer': {
            'x': 0.0,
            'y': 0.0,
            'z': 0.0,
          },
          'gyroscope': {
            'x': 0.0,
            'y': 0.0,
            'z': 0.0,
          },
          'active_minutes': 0.0,
          'activity_type': 'resting',
          'impact_detected': false,
          'impact_severity': 0.0,
          'magnitude': 0.0,
          'step_count': 0,
          'timestamp': 0,
        },
        'history': {},
        'daily_summary': {},
      },
      'health': {
        'heartRate': 0,
        'temperature': 0.0,
        'timestamp': '',
      },
      'health_history': {},
      'current_location': {
        'latitude': 0.0,
        'longitude': 0.0,
        'timestamp': '',
      },
      'location_history': {},
    };

    final snapshot = await petRef.get();

    if (!snapshot.exists) {
      await petRef.set(defaultStructure);
      return;
    }

    final existingData =
        Map<String, dynamic>.from(snapshot.value as Map<dynamic, dynamic>);

    if (!existingData.containsKey('activity')) {
      await petRef.child('activity').set(defaultStructure['activity']);
    } else {
      final activityData =
          Map<String, dynamic>.from(existingData['activity'] ?? {});

      if (!activityData.containsKey('current')) {
        await petRef.child('activity/current').set(
          (defaultStructure['activity'] as Map<String, dynamic>)['current'],
        );
      }

      if (!activityData.containsKey('history')) {
        await petRef.child('activity/history').set({});
      }

      if (!activityData.containsKey('daily_summary')) {
        await petRef.child('activity/daily_summary').set({});
      }
    }

    if (!existingData.containsKey('health')) {
      await petRef.child('health').set(defaultStructure['health']);
    }

    if (!existingData.containsKey('health_history')) {
      await petRef.child('health_history').set({});
    }

    if (!existingData.containsKey('current_location')) {
      await petRef.child('current_location').set(defaultStructure['current_location']);
    }

    if (!existingData.containsKey('location_history')) {
      await petRef.child('location_history').set({});
    }
  }

  Future<void> _updateUser() async {
    final selectedPetId = _selectedPetIdController.text.trim();
    final petsCount = int.tryParse(_petsController.text) ?? 0;

    try {
      final Map<String, dynamic> data = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'pets': petsCount,
        'status': _selectedStatus,
      };

      if (selectedPetId.isNotEmpty) {
        data['selectedPetId'] = selectedPetId;
        data['petIds'] = [selectedPetId];
      } else {
        data['selectedPetId'] = null;
        data['petIds'] = [];
      }

      await widget.user.reference.update(data);

      if (selectedPetId.isNotEmpty) {
        await _createInitialPetStructureIfNeeded(selectedPetId);
      }

      if (!mounted) return;

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating user: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _petsController.dispose();
    _selectedPetIdController.dispose();
    super.dispose();
  }
}