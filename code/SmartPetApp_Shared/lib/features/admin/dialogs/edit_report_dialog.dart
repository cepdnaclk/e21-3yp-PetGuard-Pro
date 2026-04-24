import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EditReportDialog extends StatefulWidget {
  final DocumentSnapshot report;

  const EditReportDialog({super.key, required this.report});

  @override
  State<EditReportDialog> createState() => _EditReportDialogState();
}

class _EditReportDialogState extends State<EditReportDialog> {
  late TextEditingController _dailyActiveUsersController;
  late TextEditingController _alertsTodayController;
  late TextEditingController _connectivityRateController;

  @override
  void initState() {
    super.initState();
    _dailyActiveUsersController =
        TextEditingController(text: widget.report['dailyActiveUsers']?.toString() ?? '0');
    _alertsTodayController =
        TextEditingController(text: widget.report['alertsToday']?.toString() ?? '0');
    _connectivityRateController =
        TextEditingController(text: widget.report['connectivityRate']?.toString() ?? '100');
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
                      'Edit Report',
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
                    _buildField('Daily Active Users', _dailyActiveUsersController, isNumber: true),
                    const SizedBox(height: 16),
                    _buildField('Alerts Today', _alertsTodayController, isNumber: true),
                    const SizedBox(height: 16),
                    _buildField('Connectivity Rate (%)', _connectivityRateController, isNumber: true),
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
                    onPressed: _updateReport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Update Report'),
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

  void _updateReport() {
    final data = {
      'dailyActiveUsers': int.tryParse(_dailyActiveUsersController.text) ?? 0,
      'alertsToday': int.tryParse(_alertsTodayController.text) ?? 0,
      'connectivityRate': int.tryParse(_connectivityRateController.text) ?? 100,
      'date': FieldValue.serverTimestamp(),
    };

    widget.report.reference.update(data).then((_) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating report: $error'),
          backgroundColor: Colors.red,
        ),
      );
    });
  }

  @override
  void dispose() {
    _dailyActiveUsersController.dispose();
    _alertsTodayController.dispose();
    _connectivityRateController.dispose();
    super.dispose();
  }
}