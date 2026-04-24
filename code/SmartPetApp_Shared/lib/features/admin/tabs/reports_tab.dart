import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/admin_cards.dart';
import '../dialogs/add_report_dialog.dart';
import '../dialogs/edit_report_dialog.dart';

class ReportsTab extends StatelessWidget {
  const ReportsTab({super.key});

  void _deleteReport(DocumentSnapshot report, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Report'),
        content: const Text('Are you sure you want to delete this report?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              report.reference.delete().then((_) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Report deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              }).catchError((error) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error deleting report: $error'),
                    backgroundColor: Colors.red,
                  ),
                );
              });
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reports')
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final reports = snapshot.data!.docs;

          if (reports.isEmpty) {
            return const Center(child: Text('No reports found'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final r = reports[index];
              return DashboardCard(
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.teal.withOpacity(0.1),
                  child: const Icon(Icons.bar_chart, color: Colors.teal),
                ),
                title: 'Daily Active Users: ${r['dailyActiveUsers'] ?? 0}',
                subtitle: 'Alerts Today: ${r['alertsToday'] ?? 0}',
                subtitle2: 'Connectivity Rate: ${r['connectivityRate'] ?? 0}%',
                onEdit: () => showDialog(
                  context: context,
                  builder: (context) => EditReportDialog(report: r),
                ),
                onDelete: () => _deleteReport(r, context),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(
          context: context,
          builder: (context) => const AddReportDialog(),
        ),
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}