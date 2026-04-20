import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AdminAppBar({super.key});

  void _onMenuSelected(BuildContext context, String value) {
    switch (value) {
      case 'profile':
        showDialog(
          context: context,
          builder: (context) => const AlertDialog(
            title: Text("Admin Profile"),
            content: Text("Admin profile details go here."),
          ),
        );
        break;

      case 'settings':
        showDialog(
          context: context,
          builder: (context) => const AlertDialog(
            title: Text("Settings"),
            content: Text("App settings go here."),
          ),
        );
        break;

      case 'logout':
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Logout"),
            content: const Text("Are you sure you want to logout?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await FirebaseAuth.instance.signOut();

                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/',
                    (route) => false,
                  );
                },
                child: const Text("Logout"),
              ),
            ],
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text("Admin Dashboard"),
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 1,
      actions: [
        PopupMenuButton<String>(
          icon: const CircleAvatar(
            radius: 18,
            backgroundColor: Colors.teal,
            child: Icon(Icons.person, color: Colors.white, size: 20),
          ),
          onSelected: (value) => _onMenuSelected(context, value),
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'profile',
              child: ListTile(
                leading: Icon(Icons.person),
                title: Text("Admin Profile"),
              ),
            ),
            PopupMenuItem(
              value: 'settings',
              child: ListTile(
                leading: Icon(Icons.settings),
                title: Text("Settings"),
              ),
            ),
            PopupMenuDivider(),
            PopupMenuItem(
              value: 'logout',
              child: ListTile(
                leading: Icon(Icons.logout),
                title: Text("Logout"),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}