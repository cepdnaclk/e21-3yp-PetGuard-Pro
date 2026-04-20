import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../location/screens/dashboard_screen.dart' show LocationDashboard;
import '../health/screens/health_dashboard_screen.dart';
import '../activity/screens/activity_dashboard_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Replace this with your actual login screen import
import '../../auth/screens/login_screen.dart';

class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({super.key});

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    UserHomeTab(),
    UserPetsTab(),
    UserAlertsTab(),
    UserReportsTab(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color.fromARGB(255, 0, 150, 136),
        unselectedItemColor: Colors.grey[600],
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.pets), label: 'Pets'),
          BottomNavigationBarItem(
              icon: Icon(Icons.notifications), label: 'Alerts'),
          BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart), label: 'Reports'),
        ],
      ),
    );
  }
}

//////////////////////////////////////////////////////////////
// COMMON APP BAR WITH PROFILE + ALERTS
//////////////////////////////////////////////////////////////

class DashboardAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const DashboardAppBar({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 1,
      actions: [
        // Bell icon with alerts
        PopupMenuButton<String>(
          icon: const Icon(Icons.notifications, color: Colors.black),
          onSelected: (value) {},
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'alert1',
              child: ListTile(
                leading: Icon(Icons.warning, color: Colors.orange),
                title: Text("Pet left safe zone"),
              ),
            ),
            const PopupMenuItem(
              value: 'alert2',
              child: ListTile(
                leading: Icon(Icons.medical_services, color: Colors.blue),
                title: Text("Medication reminder"),
              ),
            ),
            const PopupMenuItem(
              value: 'alert3',
              child: ListTile(
                leading: Icon(Icons.local_hospital, color: Colors.red),
                title: Text("Vet appointment tomorrow"),
              ),
            ),
          ],
        ),

        // Profile menu
        PopupMenuButton<String>(
          icon: const CircleAvatar(
            backgroundColor: Color.fromARGB(255, 0, 150, 136),
            child: Icon(Icons.person, color: Colors.white),
          ),
          onSelected: (value) {
            switch (value) {
              case 'profile':
                showDialog(
                  context: context,
                  builder: (context) => const AlertDialog(
                    title: Text('My Profile'),
                    content: Text('User profile details go here.'),
                  ),
                );
                break;
              case 'settings':
                showDialog(
                  context: context,
                  builder: (context) => const AlertDialog(
                    title: Text('Settings'),
                    content: Text('App settings go here.'),
                  ),
                );
                break;
              case 'notifications':
                showDialog(
                  context: context,
                  builder: (context) => const AlertDialog(
                    title: Text('System Notifications'),
                    content: Text('Notifications list goes here.'),
                  ),
                );
                break;
              case 'help':
                showDialog(
                  context: context,
                  builder: (context) => const AlertDialog(
                    title: Text('Help & Support'),
                    content: Text('Help content goes here.'),
                  ),
                );
                break;
              case 'about':
                showDialog(
                  context: context,
                  builder: (context) => const AlertDialog(
                    title: Text('About'),
                    content: Text('App information goes here.'),
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
                        onPressed: () async {
                          Navigator.pop(context);

                          await FirebaseAuth.instance.signOut();

                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
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
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'profile',
              child: ListTile(
                leading: Icon(Icons.person),
                title: Text('My Profile'),
              ),
            ),
            const PopupMenuItem(
              value: 'settings',
              child: ListTile(
                leading: Icon(Icons.settings),
                title: Text('Settings'),
              ),
            ),
            const PopupMenuItem(
              value: 'notifications',
              child: ListTile(
                leading: Icon(Icons.notifications),
                title: Text('System Notifications'),
              ),
            ),
            const PopupMenuItem(
              value: 'help',
              child: ListTile(
                leading: Icon(Icons.help_outline),
                title: Text('Help & Support'),
              ),
            ),
            const PopupMenuItem(
              value: 'about',
              child: ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('About'),
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'logout',
              child: ListTile(
                leading: Icon(Icons.logout, color: Colors.red),
                title: Text('Logout'),
              ),
            ),
          ],
        ),
        const SizedBox(width: 10),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

//////////////////////////////////////////////////////////////
// COMMON GRADIENT CARD
//////////////////////////////////////////////////////////////

class GradientCard extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final String trailing;
  final List<Color> colors;

  const GradientCard({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold)),
                Text(subtitle, style: const TextStyle(color: Colors.black87)),
              ],
            ),
          ),
          Text(trailing,
              style: const TextStyle(
                  color: Colors.black, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

//////////////////////////////////////////////////////////////
// HOME TAB - WITH GPS NAVIGATION
//////////////////////////////////////////////////////////////

class UserHomeTab extends StatelessWidget {
  const UserHomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = [
      {
        "title": "GPS Tracking & Geofencing",
        "subtitle": "Monitor pet location",
        "value": "Active",
        "icon": Icons.gps_fixed,
        "route": "gps", // ← Add route identifier
      },
      {
        "title": "Alerts",
        "subtitle": "Pending notifications",
        "value": "2",
        "icon": Icons.notifications,
        "route": null,
      },
      {
        "title": "Health Monitoring",
        "subtitle": "Pet health stats",
        "value": "92%",
        "icon": Icons.favorite,
        "route": "health",
      },
      {
        "title": "Collar Status",
        "subtitle": "Connected",
        "value": "Online",
        "icon": Icons.watch,
        "route": null,
      },
      {
        "title": "Activity Monitoring",
        "subtitle": "Track daily pet activity",
        "value": "Normal",
        "icon": Icons.directions_run,
        "route": "activity",
      },
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const DashboardAppBar(title: "Home"),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: stats.map((s) {
            // Make GPS card tappable
            Widget card = GradientCard(
              leading: Icon(
                s["icon"] as IconData,
                color: const Color.fromARGB(255, 0, 150, 136),
                size: 30,
              ),
              title: s["title"] as String,
              subtitle: s["subtitle"] as String,
              trailing: s["value"] as String,
              colors: [Colors.blueGrey.shade50, Colors.blueGrey.shade100],
            );

            // Wrap with InkWell if it has a route
            if (s["route"] != null) {
  return InkWell(
    onTap: () {
      if (s["route"] == "gps") {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const LocationDashboard(),
          ),
        );
      } 
      else if (s["route"] == "health") {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const HealthDashboardScreen(),
          ),
        );
      }
      else if (s["route"] == "activity") {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ActivityDashboardScreen(),
          ),
        );
      }
    },
    child: card,
  );
}

            return card;
          }).toList(),
        ),
      ),
    );
  }
}

// PETS TAB
class UserPetsTab extends StatefulWidget {
  const UserPetsTab({super.key});

  @override
  State<UserPetsTab> createState() => _UserPetsTabState();
}

class _UserPetsTabState extends State<UserPetsTab> {
  final user = FirebaseAuth.instance.currentUser;

  Future<Map<String, dynamic>?> fetchSelectedPet() async {
    if (user == null) return null;

    final firestore = FirebaseFirestore.instance;

    // 1. Get user document
    final userDoc =
        await firestore.collection('users').doc(user!.uid).get();

    if (!userDoc.exists) return null;

    final userData = userDoc.data();

    if (userData == null) return null;

    // 2. Get selectedPetId ONLY
    final String? selectedPetId = userData['selectedPetId'];

    if (selectedPetId == null || selectedPetId.isEmpty) {
      return null;
    }

    // 3. Fetch pet document
    final petDoc =
        await firestore.collection('pets').doc(selectedPetId).get();

    if (!petDoc.exists) return null;

    return petDoc.data();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const DashboardAppBar(title: "Pets"),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: fetchSelectedPet(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(
              child: Text("No pet assigned to this user"),
            );
          }

          final p = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: GradientCard(
              leading: const Icon(
                Icons.pets,
                color: Color.fromARGB(255, 0, 150, 136),
                size: 30,
              ),
              title: p['petName'] ?? 'Unnamed Pet',
              subtitle:
                  "Type: ${p['type'] ?? 'Unknown'} | Age: ${p['age'] ?? '-'}",
              trailing: p['petId'] ?? '',
              colors: [
                Colors.blueGrey.shade50,
                Colors.blueGrey.shade100
              ],
            ),
          );
        },
      ),
    );
  }
}


// class UserPetsTab extends StatefulWidget {
//   const UserPetsTab({super.key});

//   @override
//   State<UserPetsTab> createState() => _UserPetsTabState();
// }

// class _UserPetsTabState extends State<UserPetsTab> {
//   final user = FirebaseAuth.instance.currentUser;

//   Future<List<Map<String, dynamic>>> fetchUserPets() async {
//     if (user == null) return [];

//     final firestore = FirebaseFirestore.instance;

//     // 1. Get user document
//     final userDoc =
//         await firestore.collection('users').doc(user!.uid).get();

//     if (!userDoc.exists) return [];

//     final data = userDoc.data()!;

//     // SUPPORT BOTH single petId and list petIds
//     List<String> petIds = [];

//     // if (data.containsKey('petIds')) {
//     //   petIds = List<String>.from(data['petIds']);
//     // } else if (data.containsKey('petId') && data['petId'] != "") {
//     //   petIds = [data['petId']];
//     // }

//     if (data.containsKey('petIds')) {
//       petIds = List<String>.from(data['petIds']);
//     } 
//     else if (data.containsKey('petId') && data['petId'] != "") {
//       petIds = [data['petId']];
//     }
//     else if (data.containsKey('selectedPetId') && data['selectedPetId'] != "") {
//       petIds = [data['selectedPetId']]; // 🔥 THIS FIX
//     }

//     if (petIds.isEmpty) return [];

//     // 2. Fetch pet documents
//     List<Map<String, dynamic>> pets = [];

//     for (String petId in petIds) {
//       final petDoc =
//           await firestore.collection('pets').doc(petId).get();

//       if (petDoc.exists) {
//         pets.add(petDoc.data()!);
//       }
//     }

//     return pets;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: const DashboardAppBar(title: "Pets"),
//       body: FutureBuilder<List<Map<String, dynamic>>>(
//         future: fetchUserPets(),
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Center(child: CircularProgressIndicator());
//           }

//           if (!snapshot.hasData || snapshot.data!.isEmpty) {
//             return const Center(
//               child: Text("No pets assigned yet"),
//             );
//           }

//           final pets = snapshot.data!;

//           return Padding(
//             padding: const EdgeInsets.all(16),
//             child: ListView.builder(
//               itemCount: pets.length,
//               itemBuilder: (context, index) {
//                 final p = pets[index];

//                 return GradientCard(
//                   leading: const Icon(
//                     Icons.pets,
//                     color: Color.fromARGB(255, 0, 150, 136),
//                     size: 30,
//                   ),
//                   title: p['petName'] ?? 'Unnamed Pet',
//                   subtitle:
//                       "Type: ${p['type'] ?? 'Unknown'} | Age: ${p['age'] ?? '-'}",
//                   trailing: p['petId'] ?? '',
//                   colors: [
//                     Colors.blueGrey.shade50,
//                     Colors.blueGrey.shade100
//                   ],
//                 );
//               },
//             ),
//           );
//         },
//       ),
//     );
//   }
// }




// class UserPetsTab extends StatelessWidget {
//   const UserPetsTab({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final pets = [
//       {"name": "Buddy", "type": "Dog", "age": "3 years"},
//       {"name": "Max", "type": "Cat", "age": "2 years"},
//     ];

//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: const DashboardAppBar(title: "Pets"),
//       body: Padding(
//         padding: const EdgeInsets.all(16),
//         child: ListView.builder(
//           itemCount: pets.length,
//           itemBuilder: (context, index) {
//             final p = pets[index];
//             return GradientCard(
//               leading: const Icon(Icons.pets,
//                   color: Color.fromARGB(255, 0, 150, 136), size: 30),
//               title: p["name"]!,
//               subtitle: "${p["type"]} | Age: ${p["age"]}",
//               trailing: "",
//               colors: [Colors.blueGrey.shade50, Colors.blueGrey.shade100],
//             );
//           },
//         ),
//       ),
//     );
//   }
// }

// ALERTS TAB
class UserAlertsTab extends StatelessWidget {
  const UserAlertsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final alerts = [
      {"text": "Vet Appointment", "icon": Icons.local_hospital},
      {"text": "Medication Reminder", "icon": Icons.medical_services},
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const DashboardAppBar(title: "Alerts"),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: alerts.map((a) {
            return GradientCard(
              leading: Icon(a["icon"] as IconData,
                  color: const Color.fromARGB(255, 0, 150, 136), size: 30),
              title: a["text"] as String,
              subtitle: "",
              trailing: "",
              colors: [Colors.blueGrey.shade50, Colors.blueGrey.shade100],
            );
          }).toList(),
        ),
      ),
    );
  }
}

// REPORTS TAB
class UserReportsTab extends StatelessWidget {
  const UserReportsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final reports = [
      {"title": "Total Walks", "value": "12"},
      {"title": "Total Alerts", "value": "5"},
      {"title": "Health Index", "value": "92%"},
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const DashboardAppBar(title: "Reports"),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: reports.map((r) {
            return GradientCard(
              leading: const Icon(Icons.bar_chart,
                  color: Color.fromARGB(255, 0, 150, 136), size: 30),
              title: r["title"]!,
              subtitle: "",
              trailing: r["value"]!,
              colors: [Colors.blueGrey.shade50, Colors.blueGrey.shade100],
            );
          }).toList(),
        ),
      ),
    );
  }
}
