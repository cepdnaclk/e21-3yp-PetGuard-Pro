import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/admin_cards.dart';
import '../dialogs/add_device_dialog.dart';
import '../dialogs/edit_device_dialog.dart';

class DeviceManagementTab extends StatelessWidget {
  const DeviceManagementTab({super.key});

  void _deleteDevice(DocumentSnapshot device, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Device'),
        content: Text('Are you sure you want to delete device for ${device['petName']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              device.reference.delete().then((_) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Device deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              }).catchError((error) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error deleting device: $error'),
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
        stream: FirebaseFirestore.instance.collection('devices').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final devices = snapshot.data!.docs;

          if (devices.isEmpty) {
            return const Center(child: Text('No devices found'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final d = devices[index];
              final connectivity = d['connectivity'] ?? 100;
              final isOffline = connectivity < 50;

              return DashboardCard(
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.teal.withOpacity(0.1),
                  child: const Icon(Icons.pets, color: Colors.teal),
                ),
                title: d['petName'] ?? 'Unknown Pet',
                subtitle: 'Device: ${d['deviceId'] ?? 'N/A'}',
                subtitle2: 'Owner: ${d['ownerId'] ?? 'N/A'}',
                badge1: isOffline ? 'Offline' : '$connectivity%',
                badge1Color: isOffline ? Colors.red : Colors.green,
                badge2: d['deviceId'] ?? 'DEVICE',
                badge2Color: Colors.blue,
                onEdit: () => showDialog(
                  context: context,
                  builder: (context) => EditDeviceDialog(device: d),
                ),
                onDelete: () => _deleteDevice(d, context),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(
          context: context,
          builder: (context) => const AddDeviceDialog(),
        ),
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}