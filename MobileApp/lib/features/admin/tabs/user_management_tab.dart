import '../data/admin_repository.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/admin_cards.dart';
import 'user_pet_details_page.dart';

class UserManagementTab extends StatelessWidget {
  final AdminRepository _adminRepository = AdminRepository();
  UserManagementTab({super.key});

  void _deleteUser(DocumentSnapshot user, BuildContext context) {
    final data = user.data() as Map<String, dynamic>? ?? {};
    final name = data['name'] ?? 'this user';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete $name?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _adminRepository.deleteUser(user);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('User deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (error) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error deleting user: $error'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(
    DocumentSnapshot user,
    BuildContext context,
    String newStatus,
  ) async {
    try {
      await _adminRepository.updateUserStatus(user, newStatus);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User status changed to $newStatus'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating status: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _getStatusColor(String status) {
    final colorString = _adminRepository.getStatusColor(status);
    if (colorString == 'green') return Colors.green;
    if (colorString == 'orange') return Colors.orange;
    if (colorString == 'red') return Colors.red;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: _adminRepository.getUsersStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data!.docs;

          if (users.isEmpty) {
            return const Center(child: Text('No users found'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final u = users[index];
              final data = u.data() as Map<String, dynamic>? ?? {};

              final name = data['name'] ?? 'Unknown User';
              final email = data['email'] ?? 'N/A';
              final phone = data['phone'] ?? 'N/A';
              final pets = data['pets'] ?? 0;
              final status = (data['status'] ?? 'Pending').toString();

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    DashboardCard(
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.teal.withOpacity(0.1),
                        child: const Icon(Icons.person, color: Colors.teal),
                      ),
                      title: name,
                      subtitle: 'Email: $email',
                      subtitle2: 'Phone: $phone | Pets: $pets',
                      badge1: status,
                      badge1Color: _getStatusColor(status),
                      onDelete: () => _deleteUser(u, context),
                    ),

                    // ✅ ADD THIS BUTTON HERE
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserPetDetailsPage(userId: u.id),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Pet Detail'),
                    ),

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: status == 'Active'
                                ? null
                                : () => _updateStatus(u, context, 'Active'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Approve'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: status == 'Inactive'
                                ? null
                                : () => _updateStatus(u, context, 'Inactive'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Block'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}