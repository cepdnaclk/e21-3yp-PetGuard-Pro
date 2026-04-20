import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EditDeviceDialog extends StatefulWidget {
  final DocumentSnapshot device;

  const EditDeviceDialog({super.key, required this.device});

  @override
  State<EditDeviceDialog> createState() => _EditDeviceDialogState();
}

class _EditDeviceDialogState extends State<EditDeviceDialog> {
  late TextEditingController _petNameController;
  late TextEditingController _ownerIdController;
  late TextEditingController _deviceIdController;
  late TextEditingController _connectivityController;

  @override
  void initState() {
    super.initState();
    _petNameController = TextEditingController(text: widget.device['petName'] ?? '');
    _ownerIdController = TextEditingController(text: widget.device['ownerId'] ?? '');
    _deviceIdController = TextEditingController(text: widget.device['deviceId'] ?? '');
    _connectivityController =
        TextEditingController(text: widget.device['connectivity']?.toString() ?? '100');
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
                      'Edit Device',
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
                    _buildField('Pet Name', _petNameController),
                    const SizedBox(height: 16),
                    _buildField('Owner ID', _ownerIdController),
                    const SizedBox(height: 16),
                    _buildField('Device ID', _deviceIdController),
                    const SizedBox(height: 16),
                    _buildField('Connectivity (%)', _connectivityController, isNumber: true),
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
                    child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _updateDevice,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Update Device'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {bool isNumber = false}) {
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

  void _updateDevice() {
    final data = {
      'petName': _petNameController.text,
      'ownerId': _ownerIdController.text,
      'deviceId': _deviceIdController.text,
      'connectivity': int.tryParse(_connectivityController.text) ?? 100,
    };

    widget.device.reference.update(data).then((_) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Device updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating device: $error'),
          backgroundColor: Colors.red,
        ),
      );
    });
  }

  @override
  void dispose() {
    _petNameController.dispose();
    _ownerIdController.dispose();
    _deviceIdController.dispose();
    _connectivityController.dispose();
    super.dispose();
  }
}