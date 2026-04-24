// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';

// class AdminDashboardScreen extends StatefulWidget {
//   const AdminDashboardScreen({super.key});

//   @override
//   State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
// }

// class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
//   int _selectedIndex = 0;

//   final List<Widget> _screens = [
//     const AdminHomeTab(),
//     const UserManagementTab(),
//     const DeviceManagementTab(),
//     const AlertsTab(),
//     const ReportsTab(),
//   ];

//   void _onItemTapped(int index) {
//     setState(() {
//       _selectedIndex = index;
//     });
//   }

//   void _onMenuSelected(String value) {
//     switch (value) {
//       case 'profile':
//         showDialog(
//           context: context,
//           builder: (context) => const AlertDialog(
//             title: Text("Admin Profile"),
//             content: Text("Admin profile details go here."),
//           ),
//         );
//         break;
//       case 'settings':
//         showDialog(
//           context: context,
//           builder: (context) => const AlertDialog(
//             title: Text("Settings"),
//             content: Text("App settings go here."),
//           ),
//         );
//         break;
//       case 'logout':
//         showDialog(
//           context: context,
//           builder: (context) => AlertDialog(
//             title: const Text("Logout"),
//             content: const Text("Are you sure you want to logout?"),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(context),
//                 child: const Text("Cancel"),
//               ),
//               TextButton(
//                 onPressed: () async {
//                   Navigator.pop(context);

//                   await FirebaseAuth.instance.signOut();

//                   if (mounted) {
//                     Navigator.of(context).pushNamedAndRemoveUntil(
//                       '/',
//                       (route) => false,
//                     );
//                   }
//                 },
//                 child: const Text("Logout"),
//               ),
//             ],
//           ),
//         );
//         break;
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Admin Dashboard"),
//         backgroundColor: Colors.white,
//         foregroundColor: Colors.black,
//         elevation: 1,
//         actions: [
//           PopupMenuButton<String>(
//             icon: const CircleAvatar(
//               radius: 18,
//               backgroundColor: Colors.teal,
//               child: Icon(Icons.person, color: Colors.white, size: 20),
//             ),
//             onSelected: _onMenuSelected,
//             itemBuilder: (context) => const [
//               PopupMenuItem(
//                 value: 'profile',
//                 child: ListTile(
//                   leading: Icon(Icons.person),
//                   title: Text("Admin Profile"),
//                 ),
//               ),
//               PopupMenuItem(
//                 value: 'settings',
//                 child: ListTile(
//                   leading: Icon(Icons.settings),
//                   title: Text("Settings"),
//                 ),
//               ),
//               PopupMenuDivider(),
//               PopupMenuItem(
//                 value: 'logout',
//                 child: ListTile(
//                   leading: Icon(Icons.logout),
//                   title: Text("Logout"),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//       body: _screens[_selectedIndex],
//       bottomNavigationBar: BottomNavigationBar(
//         backgroundColor: Colors.white,
//         currentIndex: _selectedIndex,
//         onTap: _onItemTapped,
//         type: BottomNavigationBarType.fixed,
//         selectedItemColor: Colors.teal,
//         unselectedItemColor: Colors.grey[600],
//         showUnselectedLabels: true,
//         items: const [
//           BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
//           BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Users'),
//           BottomNavigationBarItem(icon: Icon(Icons.pets), label: 'Devices'),
//           BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Alerts'),
//           BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Reports'),
//         ],
//       ),
//     );
//   }
// }

// //////////////////////////////////////////////////////////////
// // COMMON GRADIENT CARD (PRESERVED)
// //////////////////////////////////////////////////////////////

// class GradientCard extends StatelessWidget {
//   final Widget leading;
//   final String title;
//   final String subtitle;
//   final String trailing;

//   const GradientCard({
//     super.key,
//     required this.leading,
//     required this.title,
//     required this.subtitle,
//     required this.trailing,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 12),
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           colors: [Colors.blueGrey.shade50, Colors.blueGrey.shade100],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.blueGrey.shade200.withOpacity(0.4),
//             blurRadius: 6,
//             offset: const Offset(0, 4),
//           ),
//         ],
//       ),
//       child: Row(
//         children: [
//           leading,
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   title,
//                   style: const TextStyle(
//                     color: Colors.black, 
//                     fontWeight: FontWeight.bold
//                   ),
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//                 if (subtitle.isNotEmpty)
//                   Text(
//                     subtitle, 
//                     style: const TextStyle(color: Colors.black),
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                   ),
//               ],
//             ),
//           ),
//           if (trailing.isNotEmpty)
//             Text(
//               trailing,
//               style: const TextStyle(
//                 color: Colors.black, 
//                 fontWeight: FontWeight.bold
//               ),
//               maxLines: 1,
//               overflow: TextOverflow.ellipsis,
//             ),
//         ],
//       ),
//     );
//   }
// }

// //////////////////////////////////////////////////////////////
// // IMPROVED CARD WITH BETTER STRUCTURE
// //////////////////////////////////////////////////////////////

// class DashboardCard extends StatelessWidget {
//   final Widget leading;
//   final String title;
//   final String? subtitle;
//   final String? subtitle2;
//   final String? badge1;
//   final String? badge2;
//   final Color? badge1Color;
//   final Color? badge2Color;
//   final VoidCallback? onEdit;
//   final VoidCallback? onDelete;

//   const DashboardCard({
//     super.key,
//     required this.leading,
//     required this.title,
//     this.subtitle,
//     this.subtitle2,
//     this.badge1,
//     this.badge2,
//     this.badge1Color,
//     this.badge2Color,
//     this.onEdit,
//     this.onDelete,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 12),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.grey.withOpacity(0.1),
//             spreadRadius: 1,
//             blurRadius: 4,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Row(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Leading icon
//             leading,
//             const SizedBox(width: 16),
            
//             // Content
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   // Title - always visible
//                   Text(
//                     title,
//                     style: const TextStyle(
//                       fontWeight: FontWeight.bold,
//                       fontSize: 16,
//                     ),
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                   ),
                  
//                   // First subtitle
//                   if (subtitle != null && subtitle!.isNotEmpty) ...[
//                     const SizedBox(height: 4),
//                     Text(
//                       subtitle!,
//                       style: TextStyle(
//                         color: Colors.grey[600],
//                         fontSize: 14,
//                       ),
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                   ],
                  
//                   // Second subtitle
//                   if (subtitle2 != null && subtitle2!.isNotEmpty) ...[
//                     const SizedBox(height: 2),
//                     Text(
//                       subtitle2!,
//                       style: TextStyle(
//                         color: Colors.grey[500],
//                         fontSize: 13,
//                       ),
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                   ],
                  
//                   // Badges row - only show if at least one badge exists
//                   if ((badge1 != null && badge1!.isNotEmpty) || 
//                       (badge2 != null && badge2!.isNotEmpty)) ...[
//                     const SizedBox(height: 8),
//                     Wrap(
//                       spacing: 8,
//                       runSpacing: 4,
//                       children: [
//                         if (badge1 != null && badge1!.isNotEmpty)
//                           Container(
//                             padding: const EdgeInsets.symmetric(
//                               horizontal: 10,
//                               vertical: 4,
//                             ),
//                             decoration: BoxDecoration(
//                               color: (badge1Color ?? Colors.grey).withOpacity(0.1),
//                               borderRadius: BorderRadius.circular(16),
//                               border: Border.all(
//                                 color: (badge1Color ?? Colors.grey).withOpacity(0.2),
//                               ),
//                             ),
//                             child: Text(
//                               badge1!,
//                               style: TextStyle(
//                                 color: badge1Color ?? Colors.grey,
//                                 fontSize: 12,
//                                 fontWeight: FontWeight.w500,
//                               ),
//                               maxLines: 1,
//                             ),
//                           ),
//                         if (badge2 != null && badge2!.isNotEmpty)
//                           Container(
//                             padding: const EdgeInsets.symmetric(
//                               horizontal: 10,
//                               vertical: 4,
//                             ),
//                             decoration: BoxDecoration(
//                               color: (badge2Color ?? Colors.grey).withOpacity(0.1),
//                               borderRadius: BorderRadius.circular(16),
//                               border: Border.all(
//                                 color: (badge2Color ?? Colors.grey).withOpacity(0.2),
//                               ),
//                             ),
//                             child: Text(
//                               badge2!,
//                               style: TextStyle(
//                                 color: badge2Color ?? Colors.grey,
//                                 fontSize: 12,
//                                 fontWeight: FontWeight.w500,
//                               ),
//                               maxLines: 1,
//                             ),
//                           ),
//                       ],
//                     ),
//                   ],
//                 ],
//               ),
//             ),
            
//             // 3-dot menu
//             if (onEdit != null || onDelete != null)
//               PopupMenuButton<String>(
//                 icon: const Icon(Icons.more_vert, color: Colors.grey),
//                 onSelected: (value) {
//                   if (value == 'edit' && onEdit != null) {
//                     onEdit!();
//                   } else if (value == 'delete' && onDelete != null) {
//                     onDelete!();
//                   }
//                 },
//                 itemBuilder: (context) => [
//                   if (onEdit != null)
//                     const PopupMenuItem(
//                       value: 'edit',
//                       child: Row(
//                         children: [
//                           Icon(Icons.edit, size: 20, color: Colors.blue),
//                           SizedBox(width: 8),
//                           Text('Edit'),
//                         ],
//                       ),
//                     ),
//                   if (onDelete != null)
//                     const PopupMenuItem(
//                       value: 'delete',
//                       child: Row(
//                         children: [
//                           Icon(Icons.delete, size: 20, color: Colors.red),
//                           SizedBox(width: 8),
//                           Text('Delete'),
//                         ],
//                       ),
//                     ),
//                 ],
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// //////////////////////////////////////////////////////////////
// // ADD DIALOGS (for creating new items)
// //////////////////////////////////////////////////////////////

// class AddUserDialog extends StatefulWidget {
//   const AddUserDialog({super.key});

//   @override
//   State<AddUserDialog> createState() => _AddUserDialogState();
// }

// class _AddUserDialogState extends State<AddUserDialog> {
//   late TextEditingController _nameController;
//   late TextEditingController _emailController;
//   late TextEditingController _petsController;
//   String _selectedStatus = 'Active';

//   @override
//   void initState() {
//     super.initState();
//     _nameController = TextEditingController();
//     _emailController = TextEditingController();
//     _petsController = TextEditingController(text: '0');
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Dialog(
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//       child: Container(
//         width: 400,
//         constraints: BoxConstraints(
//           maxHeight: MediaQuery.of(context).size.height * 0.9,
//         ),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             // Header
//             Padding(
//               padding: const EdgeInsets.all(24),
//               child: Row(
//                 children: [
//                   Expanded(
//                     child: Text(
//                       'Add New User',
//                       style: const TextStyle(
//                         fontSize: 24,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                   IconButton(
//                     icon: const Icon(Icons.close),
//                     onPressed: () => Navigator.pop(context),
//                   ),
//                 ],
//               ),
//             ),
            
//             // Scrollable Content
//             Expanded(
//               child: SingleChildScrollView(
//                 padding: const EdgeInsets.symmetric(horizontal: 24),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     _buildField('Name', _nameController),
//                     const SizedBox(height: 16),
//                     _buildField('Email', _emailController),
//                     const SizedBox(height: 16),
//                     _buildField('Number of Pets', _petsController, isNumber: true),
//                     const SizedBox(height: 16),
                    
//                     // Status Field
//                     Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         const Text(
//                           'Status',
//                           style: TextStyle(
//                             fontSize: 14,
//                             fontWeight: FontWeight.w500,
//                             color: Colors.grey,
//                           ),
//                         ),
//                         const SizedBox(height: 4),
//                         Container(
//                           padding: const EdgeInsets.symmetric(horizontal: 12),
//                           decoration: BoxDecoration(
//                             border: Border.all(color: Colors.grey.shade300),
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                           child: DropdownButton<String>(
//                             value: _selectedStatus,
//                             isExpanded: true,
//                             underline: const SizedBox(),
//                             items: ['Active', 'Inactive'].map((String value) {
//                               return DropdownMenuItem<String>(
//                                 value: value,
//                                 child: Text(value),
//                               );
//                             }).toList(),
//                             onChanged: (String? newValue) {
//                               setState(() {
//                                 _selectedStatus = newValue!;
//                               });
//                             },
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 24),
//                   ],
//                 ),
//               ),
//             ),
            
//             // Footer with Actions
//             Padding(
//               padding: const EdgeInsets.all(24),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.end,
//                 children: [
//                   TextButton(
//                     onPressed: () => Navigator.pop(context),
//                     child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
//                   ),
//                   const SizedBox(width: 12),
//                   ElevatedButton(
//                     onPressed: _saveUser,
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.teal,
//                       foregroundColor: Colors.white,
//                       padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                     ),
//                     child: const Text('Add User'),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildField(String label, TextEditingController controller, {bool isNumber = false}) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           label,
//           style: const TextStyle(
//             fontSize: 14,
//             fontWeight: FontWeight.w500,
//             color: Colors.grey,
//           ),
//         ),
//         const SizedBox(height: 4),
//         Container(
//           decoration: BoxDecoration(
//             border: Border.all(color: Colors.grey.shade300),
//             borderRadius: BorderRadius.circular(8),
//           ),
//           child: TextField(
//             controller: controller,
//             keyboardType: isNumber ? TextInputType.number : TextInputType.text,
//             decoration: InputDecoration(
//               contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
//               border: InputBorder.none,
//               hintText: 'Enter $label',
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   void _saveUser() {
//     if (_nameController.text.isEmpty || _emailController.text.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Please fill all required fields'),
//           backgroundColor: Colors.red,
//         ),
//       );
//       return;
//     }

//     final data = {
//       'name': _nameController.text,
//       'email': _emailController.text,
//       'pets': int.tryParse(_petsController.text) ?? 0,
//       'status': _selectedStatus,
//       'createdAt': FieldValue.serverTimestamp(),
//     };
    
//     FirebaseFirestore.instance.collection('users').add(data).then((_) {
//       Navigator.pop(context);
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('User added successfully'),
//           backgroundColor: Colors.green,
//         ),
//       );
//     }).catchError((error) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error adding user: $error'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     });
//   }

//   @override
//   void dispose() {
//     _nameController.dispose();
//     _emailController.dispose();
//     _petsController.dispose();
//     super.dispose();
//   }
// }

// class AddDeviceDialog extends StatefulWidget {
//   const AddDeviceDialog({super.key});

//   @override
//   State<AddDeviceDialog> createState() => _AddDeviceDialogState();
// }

// class _AddDeviceDialogState extends State<AddDeviceDialog> {
//   late TextEditingController _petNameController;
//   late TextEditingController _ownerIdController;
//   late TextEditingController _deviceIdController;
//   late TextEditingController _connectivityController;

//   @override
//   void initState() {
//     super.initState();
//     _petNameController = TextEditingController();
//     _ownerIdController = TextEditingController();
//     _deviceIdController = TextEditingController();
//     _connectivityController = TextEditingController(text: '100');
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Dialog(
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//       child: Container(
//         width: 400,
//         constraints: BoxConstraints(
//           maxHeight: MediaQuery.of(context).size.height * 0.9,
//         ),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             // Header
//             Padding(
//               padding: const EdgeInsets.all(24),
//               child: Row(
//                 children: [
//                   Expanded(
//                     child: Text(
//                       'Add New Device',
//                       style: const TextStyle(
//                         fontSize: 24,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                   IconButton(
//                     icon: const Icon(Icons.close),
//                     onPressed: () => Navigator.pop(context),
//                   ),
//                 ],
//               ),
//             ),
            
//             // Scrollable Content
//             Expanded(
//               child: SingleChildScrollView(
//                 padding: const EdgeInsets.symmetric(horizontal: 24),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     _buildField('Pet Name', _petNameController),
//                     const SizedBox(height: 16),
//                     _buildField('Owner ID', _ownerIdController),
//                     const SizedBox(height: 16),
//                     _buildField('Device ID', _deviceIdController),
//                     const SizedBox(height: 16),
//                     _buildField('Connectivity (%)', _connectivityController, isNumber: true),
//                     const SizedBox(height: 24),
//                   ],
//                 ),
//               ),
//             ),
            
//             // Footer with Actions
//             Padding(
//               padding: const EdgeInsets.all(24),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.end,
//                 children: [
//                   TextButton(
//                     onPressed: () => Navigator.pop(context),
//                     child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
//                   ),
//                   const SizedBox(width: 12),
//                   ElevatedButton(
//                     onPressed: _saveDevice,
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.teal,
//                       foregroundColor: Colors.white,
//                       padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                     ),
//                     child: const Text('Add Device'),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildField(String label, TextEditingController controller, {bool isNumber = false}) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           label,
//           style: const TextStyle(
//             fontSize: 14,
//             fontWeight: FontWeight.w500,
//             color: Colors.grey,
//           ),
//         ),
//         const SizedBox(height: 4),
//         Container(
//           decoration: BoxDecoration(
//             border: Border.all(color: Colors.grey.shade300),
//             borderRadius: BorderRadius.circular(8),
//           ),
//           child: TextField(
//             controller: controller,
//             keyboardType: isNumber ? TextInputType.number : TextInputType.text,
//             decoration: InputDecoration(
//               contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
//               border: InputBorder.none,
//               hintText: 'Enter $label',
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   void _saveDevice() {
//     if (_petNameController.text.isEmpty || 
//         _ownerIdController.text.isEmpty || 
//         _deviceIdController.text.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Please fill all required fields'),
//           backgroundColor: Colors.red,
//         ),
//       );
//       return;
//     }

//     final data = {
//       'petName': _petNameController.text,
//       'ownerId': _ownerIdController.text,
//       'deviceId': _deviceIdController.text,
//       'connectivity': int.tryParse(_connectivityController.text) ?? 100,
//       'createdAt': FieldValue.serverTimestamp(),
//     };
    
//     FirebaseFirestore.instance.collection('devices').add(data).then((_) {
//       Navigator.pop(context);
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Device added successfully'),
//           backgroundColor: Colors.green,
//         ),
//       );
//     }).catchError((error) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error adding device: $error'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     });
//   }

//   @override
//   void dispose() {
//     _petNameController.dispose();
//     _ownerIdController.dispose();
//     _deviceIdController.dispose();
//     _connectivityController.dispose();
//     super.dispose();
//   }
// }

// class AddAlertDialog extends StatefulWidget {
//   const AddAlertDialog({super.key});

//   @override
//   State<AddAlertDialog> createState() => _AddAlertDialogState();
// }

// class _AddAlertDialogState extends State<AddAlertDialog> {
//   late TextEditingController _titleController;
//   late TextEditingController _descriptionController;
//   String _selectedType = 'Maintenance';
//   String _selectedStatus = 'Pending';

//   final List<String> _typeOptions = ['Maintenance', 'Safety', 'Campaign'];
//   final List<String> _statusOptions = ['Pending', 'Resolved'];

//   @override
//   void initState() {
//     super.initState();
//     _titleController = TextEditingController();
//     _descriptionController = TextEditingController();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Dialog(
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//       child: Container(
//         width: 400,
//         constraints: BoxConstraints(
//           maxHeight: MediaQuery.of(context).size.height * 0.9,
//         ),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             // Header
//             Padding(
//               padding: const EdgeInsets.all(24),
//               child: Row(
//                 children: [
//                   Expanded(
//                     child: Text(
//                       'Add New Alert',
//                       style: const TextStyle(
//                         fontSize: 24,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                   IconButton(
//                     icon: const Icon(Icons.close),
//                     onPressed: () => Navigator.pop(context),
//                   ),
//                 ],
//               ),
//             ),
            
//             // Scrollable Content
//             Expanded(
//               child: SingleChildScrollView(
//                 padding: const EdgeInsets.symmetric(horizontal: 24),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     _buildField('Title', _titleController),
//                     const SizedBox(height: 16),
//                     _buildField('Description', _descriptionController, maxLines: 3),
//                     const SizedBox(height: 16),
                    
//                     // Type Dropdown
//                     Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         const Text(
//                           'Type',
//                           style: TextStyle(
//                             fontSize: 14,
//                             fontWeight: FontWeight.w500,
//                             color: Colors.grey,
//                           ),
//                         ),
//                         const SizedBox(height: 4),
//                         Container(
//                           padding: const EdgeInsets.symmetric(horizontal: 12),
//                           decoration: BoxDecoration(
//                             border: Border.all(color: Colors.grey.shade300),
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                           child: DropdownButton<String>(
//                             value: _selectedType,
//                             isExpanded: true,
//                             underline: const SizedBox(),
//                             items: _typeOptions.map((String value) {
//                               return DropdownMenuItem<String>(
//                                 value: value,
//                                 child: Text(value),
//                               );
//                             }).toList(),
//                             onChanged: (String? newValue) {
//                               setState(() {
//                                 _selectedType = newValue!;
//                               });
//                             },
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 16),
                    
//                     // Status Dropdown
//                     Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         const Text(
//                           'Status',
//                           style: TextStyle(
//                             fontSize: 14,
//                             fontWeight: FontWeight.w500,
//                             color: Colors.grey,
//                           ),
//                         ),
//                         const SizedBox(height: 4),
//                         Container(
//                           padding: const EdgeInsets.symmetric(horizontal: 12),
//                           decoration: BoxDecoration(
//                             border: Border.all(color: Colors.grey.shade300),
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                           child: DropdownButton<String>(
//                             value: _selectedStatus,
//                             isExpanded: true,
//                             underline: const SizedBox(),
//                             items: _statusOptions.map((String value) {
//                               return DropdownMenuItem<String>(
//                                 value: value,
//                                 child: Text(value),
//                               );
//                             }).toList(),
//                             onChanged: (String? newValue) {
//                               setState(() {
//                                 _selectedStatus = newValue!;
//                               });
//                             },
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 24),
//                   ],
//                 ),
//               ),
//             ),
            
//             // Footer with Actions
//             Padding(
//               padding: const EdgeInsets.all(24),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.end,
//                 children: [
//                   TextButton(
//                     onPressed: () => Navigator.pop(context),
//                     child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
//                   ),
//                   const SizedBox(width: 12),
//                   ElevatedButton(
//                     onPressed: _saveAlert,
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.teal,
//                       foregroundColor: Colors.white,
//                       padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                     ),
//                     child: const Text('Add Alert'),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildField(String label, TextEditingController controller, {int maxLines = 1}) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           label,
//           style: const TextStyle(
//             fontSize: 14,
//             fontWeight: FontWeight.w500,
//             color: Colors.grey,
//           ),
//         ),
//         const SizedBox(height: 4),
//         Container(
//           decoration: BoxDecoration(
//             border: Border.all(color: Colors.grey.shade300),
//             borderRadius: BorderRadius.circular(8),
//           ),
//           child: TextField(
//             controller: controller,
//             maxLines: maxLines,
//             decoration: InputDecoration(
//               contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
//               border: InputBorder.none,
//               hintText: 'Enter $label',
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   void _saveAlert() {
//     if (_titleController.text.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Please enter alert title'),
//           backgroundColor: Colors.red,
//         ),
//       );
//       return;
//     }

//     final data = {
//       'title': _titleController.text,
//       'description': _descriptionController.text,
//       'type': _selectedType,
//       'status': _selectedStatus,
//       'timestamp': FieldValue.serverTimestamp(),
//     };
    
//     FirebaseFirestore.instance.collection('alerts').add(data).then((_) {
//       Navigator.pop(context);
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Alert added successfully'),
//           backgroundColor: Colors.green,
//         ),
//       );
//     }).catchError((error) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error adding alert: $error'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     });
//   }

//   @override
//   void dispose() {
//     _titleController.dispose();
//     _descriptionController.dispose();
//     super.dispose();
//   }
// }

// class AddReportDialog extends StatefulWidget {
//   const AddReportDialog({super.key});

//   @override
//   State<AddReportDialog> createState() => _AddReportDialogState();
// }

// class _AddReportDialogState extends State<AddReportDialog> {
//   late TextEditingController _dailyActiveUsersController;
//   late TextEditingController _alertsTodayController;
//   late TextEditingController _connectivityRateController;

//   @override
//   void initState() {
//     super.initState();
//     _dailyActiveUsersController = TextEditingController(text: '0');
//     _alertsTodayController = TextEditingController(text: '0');
//     _connectivityRateController = TextEditingController(text: '100');
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Dialog(
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//       child: Container(
//         width: 400,
//         constraints: BoxConstraints(
//           maxHeight: MediaQuery.of(context).size.height * 0.9,
//         ),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             // Header
//             Padding(
//               padding: const EdgeInsets.all(24),
//               child: Row(
//                 children: [
//                   Expanded(
//                     child: Text(
//                       'Add New Report',
//                       style: const TextStyle(
//                         fontSize: 24,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                   IconButton(
//                     icon: const Icon(Icons.close),
//                     onPressed: () => Navigator.pop(context),
//                   ),
//                 ],
//               ),
//             ),
            
//             // Scrollable Content
//             Expanded(
//               child: SingleChildScrollView(
//                 padding: const EdgeInsets.symmetric(horizontal: 24),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     _buildField('Daily Active Users', _dailyActiveUsersController, isNumber: true),
//                     const SizedBox(height: 16),
//                     _buildField('Alerts Today', _alertsTodayController, isNumber: true),
//                     const SizedBox(height: 16),
//                     _buildField('Connectivity Rate (%)', _connectivityRateController, isNumber: true),
//                     const SizedBox(height: 24),
//                   ],
//                 ),
//               ),
//             ),
            
//             // Footer with Actions
//             Padding(
//               padding: const EdgeInsets.all(24),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.end,
//                 children: [
//                   TextButton(
//                     onPressed: () => Navigator.pop(context),
//                     child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
//                   ),
//                   const SizedBox(width: 12),
//                   ElevatedButton(
//                     onPressed: _saveReport,
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.teal,
//                       foregroundColor: Colors.white,
//                       padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                     ),
//                     child: const Text('Add Report'),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildField(String label, TextEditingController controller, {bool isNumber = false}) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           label,
//           style: const TextStyle(
//             fontSize: 14,
//             fontWeight: FontWeight.w500,
//             color: Colors.grey,
//           ),
//         ),
//         const SizedBox(height: 4),
//         Container(
//           decoration: BoxDecoration(
//             border: Border.all(color: Colors.grey.shade300),
//             borderRadius: BorderRadius.circular(8),
//           ),
//           child: TextField(
//             controller: controller,
//             keyboardType: isNumber ? TextInputType.number : TextInputType.text,
//             decoration: InputDecoration(
//               contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
//               border: InputBorder.none,
//               hintText: 'Enter $label',
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   void _saveReport() {
//     final data = {
//       'dailyActiveUsers': int.tryParse(_dailyActiveUsersController.text) ?? 0,
//       'alertsToday': int.tryParse(_alertsTodayController.text) ?? 0,
//       'connectivityRate': int.tryParse(_connectivityRateController.text) ?? 100,
//       'date': FieldValue.serverTimestamp(),
//     };
    
//     FirebaseFirestore.instance.collection('reports').add(data).then((_) {
//       Navigator.pop(context);
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Report added successfully'),
//           backgroundColor: Colors.green,
//         ),
//       );
//     }).catchError((error) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error adding report: $error'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     });
//   }

//   @override
//   void dispose() {
//     _dailyActiveUsersController.dispose();
//     _alertsTodayController.dispose();
//     _connectivityRateController.dispose();
//     super.dispose();
//   }
// }

// //////////////////////////////////////////////////////////////
// // EDIT DIALOGS (with proper push method style)
// //////////////////////////////////////////////////////////////

// class EditUserDialog extends StatefulWidget {
//   final DocumentSnapshot user;

//   const EditUserDialog({super.key, required this.user});

//   @override
//   State<EditUserDialog> createState() => _EditUserDialogState();
// }

// class _EditUserDialogState extends State<EditUserDialog> {
//   late TextEditingController _nameController;
//   late TextEditingController _emailController;
//   late TextEditingController _petsController;
//   String _selectedStatus = 'Active';

//   @override
//   void initState() {
//     super.initState();
//     _nameController = TextEditingController(text: widget.user['name'] ?? '');
//     _emailController = TextEditingController(text: widget.user['email'] ?? '');
//     _petsController = TextEditingController(text: widget.user['pets']?.toString() ?? '0');
//     _selectedStatus = widget.user['status'] ?? 'Active';
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Dialog(
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//       child: Container(
//         width: 400,
//         constraints: BoxConstraints(
//           maxHeight: MediaQuery.of(context).size.height * 0.9,
//         ),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             // Header
//             Padding(
//               padding: const EdgeInsets.all(24),
//               child: Row(
//                 children: [
//                   Expanded(
//                     child: Text(
//                       'Edit User',
//                       style: const TextStyle(
//                         fontSize: 24,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                   IconButton(
//                     icon: const Icon(Icons.close),
//                     onPressed: () => Navigator.pop(context),
//                   ),
//                 ],
//               ),
//             ),
            
//             // Scrollable Content
//             Expanded(
//               child: SingleChildScrollView(
//                 padding: const EdgeInsets.symmetric(horizontal: 24),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     _buildField('Name', _nameController),
//                     const SizedBox(height: 16),
//                     _buildField('Email', _emailController),
//                     const SizedBox(height: 16),
//                     _buildField('Number of Pets', _petsController, isNumber: true),
//                     const SizedBox(height: 16),
                    
//                     // Status Field
//                     Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         const Text(
//                           'Status',
//                           style: TextStyle(
//                             fontSize: 14,
//                             fontWeight: FontWeight.w500,
//                             color: Colors.grey,
//                           ),
//                         ),
//                         const SizedBox(height: 4),
//                         Container(
//                           padding: const EdgeInsets.symmetric(horizontal: 12),
//                           decoration: BoxDecoration(
//                             border: Border.all(color: Colors.grey.shade300),
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                           child: DropdownButton<String>(
//                             value: _selectedStatus,
//                             isExpanded: true,
//                             underline: const SizedBox(),
//                             items: ['Active', 'Inactive'].map((String value) {
//                               return DropdownMenuItem<String>(
//                                 value: value,
//                                 child: Text(value),
//                               );
//                             }).toList(),
//                             onChanged: (String? newValue) {
//                               setState(() {
//                                 _selectedStatus = newValue!;
//                               });
//                             },
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 24),
//                   ],
//                 ),
//               ),
//             ),
            
//             // Footer with Actions
//             Padding(
//               padding: const EdgeInsets.all(24),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.end,
//                 children: [
//                   TextButton(
//                     onPressed: () => Navigator.pop(context),
//                     child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
//                   ),
//                   const SizedBox(width: 12),
//                   ElevatedButton(
//                     onPressed: _updateUser,
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.teal,
//                       foregroundColor: Colors.white,
//                       padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                     ),
//                     child: const Text('Update User'),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildField(String label, TextEditingController controller, {bool isNumber = false}) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           label,
//           style: const TextStyle(
//             fontSize: 14,
//             fontWeight: FontWeight.w500,
//             color: Colors.grey,
//           ),
//         ),
//         const SizedBox(height: 4),
//         Container(
//           decoration: BoxDecoration(
//             border: Border.all(color: Colors.grey.shade300),
//             borderRadius: BorderRadius.circular(8),
//           ),
//           child: TextField(
//             controller: controller,
//             keyboardType: isNumber ? TextInputType.number : TextInputType.text,
//             decoration: const InputDecoration(
//               contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
//               border: InputBorder.none,
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   void _updateUser() {
//     final data = {
//       'name': _nameController.text,
//       'email': _emailController.text,
//       'pets': int.tryParse(_petsController.text) ?? 0,
//       'status': _selectedStatus,
//     };
    
//     widget.user.reference.update(data).then((_) {
//       Navigator.pop(context);
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('User updated successfully'),
//           backgroundColor: Colors.green,
//         ),
//       );
//     }).catchError((error) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error updating user: $error'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     });
//   }

//   @override
//   void dispose() {
//     _nameController.dispose();
//     _emailController.dispose();
//     _petsController.dispose();
//     super.dispose();
//   }
// }

// class EditDeviceDialog extends StatefulWidget {
//   final DocumentSnapshot device;

//   const EditDeviceDialog({super.key, required this.device});

//   @override
//   State<EditDeviceDialog> createState() => _EditDeviceDialogState();
// }

// class _EditDeviceDialogState extends State<EditDeviceDialog> {
//   late TextEditingController _petNameController;
//   late TextEditingController _ownerIdController;
//   late TextEditingController _deviceIdController;
//   late TextEditingController _connectivityController;

//   @override
//   void initState() {
//     super.initState();
//     _petNameController = TextEditingController(text: widget.device['petName'] ?? '');
//     _ownerIdController = TextEditingController(text: widget.device['ownerId'] ?? '');
//     _deviceIdController = TextEditingController(text: widget.device['deviceId'] ?? '');
//     _connectivityController = TextEditingController(
//         text: widget.device['connectivity']?.toString() ?? '100');
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Dialog(
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//       child: Container(
//         width: 400,
//         constraints: BoxConstraints(
//           maxHeight: MediaQuery.of(context).size.height * 0.9,
//         ),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             // Header
//             Padding(
//               padding: const EdgeInsets.all(24),
//               child: Row(
//                 children: [
//                   Expanded(
//                     child: Text(
//                       'Edit Device',
//                       style: const TextStyle(
//                         fontSize: 24,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                   IconButton(
//                     icon: const Icon(Icons.close),
//                     onPressed: () => Navigator.pop(context),
//                   ),
//                 ],
//               ),
//             ),
            
//             // Scrollable Content
//             Expanded(
//               child: SingleChildScrollView(
//                 padding: const EdgeInsets.symmetric(horizontal: 24),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     _buildField('Pet Name', _petNameController),
//                     const SizedBox(height: 16),
//                     _buildField('Owner ID', _ownerIdController),
//                     const SizedBox(height: 16),
//                     _buildField('Device ID', _deviceIdController),
//                     const SizedBox(height: 16),
//                     _buildField('Connectivity (%)', _connectivityController, isNumber: true),
//                     const SizedBox(height: 24),
//                   ],
//                 ),
//               ),
//             ),
            
//             // Footer with Actions
//             Padding(
//               padding: const EdgeInsets.all(24),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.end,
//                 children: [
//                   TextButton(
//                     onPressed: () => Navigator.pop(context),
//                     child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
//                   ),
//                   const SizedBox(width: 12),
//                   ElevatedButton(
//                     onPressed: _updateDevice,
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.teal,
//                       foregroundColor: Colors.white,
//                       padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                     ),
//                     child: const Text('Update Device'),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildField(String label, TextEditingController controller, {bool isNumber = false}) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           label,
//           style: const TextStyle(
//             fontSize: 14,
//             fontWeight: FontWeight.w500,
//             color: Colors.grey,
//           ),
//         ),
//         const SizedBox(height: 4),
//         Container(
//           decoration: BoxDecoration(
//             border: Border.all(color: Colors.grey.shade300),
//             borderRadius: BorderRadius.circular(8),
//           ),
//           child: TextField(
//             controller: controller,
//             keyboardType: isNumber ? TextInputType.number : TextInputType.text,
//             decoration: const InputDecoration(
//               contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
//               border: InputBorder.none,
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   void _updateDevice() {
//     final data = {
//       'petName': _petNameController.text,
//       'ownerId': _ownerIdController.text,
//       'deviceId': _deviceIdController.text,
//       'connectivity': int.tryParse(_connectivityController.text) ?? 100,
//     };
    
//     widget.device.reference.update(data).then((_) {
//       Navigator.pop(context);
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Device updated successfully'),
//           backgroundColor: Colors.green,
//         ),
//       );
//     }).catchError((error) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error updating device: $error'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     });
//   }

//   @override
//   void dispose() {
//     _petNameController.dispose();
//     _ownerIdController.dispose();
//     _deviceIdController.dispose();
//     _connectivityController.dispose();
//     super.dispose();
//   }
// }

// class EditAlertDialog extends StatefulWidget {
//   final DocumentSnapshot alert;

//   const EditAlertDialog({super.key, required this.alert});

//   @override
//   State<EditAlertDialog> createState() => _EditAlertDialogState();
// }

// class _EditAlertDialogState extends State<EditAlertDialog> {
//   late TextEditingController _titleController;
//   late TextEditingController _descriptionController;
//   String? _selectedType;
//   String? _selectedStatus;

//   final List<String> _typeOptions = ['Maintenance', 'Safety', 'Campaign'];
//   final List<String> _statusOptions = ['Pending', 'Resolved'];

//   @override
//   void initState() {
//     super.initState();
//     _titleController = TextEditingController(text: widget.alert['title'] ?? '');
//     _descriptionController = TextEditingController(text: widget.alert['description'] ?? '');
    
//     // Safely initialize dropdown values
//     String alertType = widget.alert['type'] ?? 'Maintenance';
//     _selectedType = _typeOptions.contains(alertType) ? alertType : 'Maintenance';
    
//     String alertStatus = widget.alert['status'] ?? 'Pending';
//     _selectedStatus = _statusOptions.contains(alertStatus) ? alertStatus : 'Pending';
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Dialog(
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//       child: Container(
//         width: 400,
//         constraints: BoxConstraints(
//           maxHeight: MediaQuery.of(context).size.height * 0.9,
//         ),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             // Header
//             Padding(
//               padding: const EdgeInsets.all(24),
//               child: Row(
//                 children: [
//                   Expanded(
//                     child: Text(
//                       'Edit Alert',
//                       style: const TextStyle(
//                         fontSize: 24,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                   IconButton(
//                     icon: const Icon(Icons.close),
//                     onPressed: () => Navigator.pop(context),
//                   ),
//                 ],
//               ),
//             ),
            
//             // Scrollable Content
//             Expanded(
//               child: SingleChildScrollView(
//                 padding: const EdgeInsets.symmetric(horizontal: 24),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     _buildField('Title', _titleController),
//                     const SizedBox(height: 16),
//                     _buildField('Description', _descriptionController, maxLines: 3),
//                     const SizedBox(height: 16),
                    
//                     // Type Dropdown
//                     Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         const Text(
//                           'Type',
//                           style: TextStyle(
//                             fontSize: 14,
//                             fontWeight: FontWeight.w500,
//                             color: Colors.grey,
//                           ),
//                         ),
//                         const SizedBox(height: 4),
//                         Container(
//                           padding: const EdgeInsets.symmetric(horizontal: 12),
//                           decoration: BoxDecoration(
//                             border: Border.all(color: Colors.grey.shade300),
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                           child: DropdownButton<String>(
//                             value: _selectedType,
//                             isExpanded: true,
//                             underline: const SizedBox(),
//                             items: _typeOptions.map((String value) {
//                               return DropdownMenuItem<String>(
//                                 value: value,
//                                 child: Text(value),
//                               );
//                             }).toList(),
//                             onChanged: (String? newValue) {
//                               setState(() {
//                                 _selectedType = newValue;
//                               });
//                             },
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 16),
                    
//                     // Status Dropdown
//                     Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         const Text(
//                           'Status',
//                           style: TextStyle(
//                             fontSize: 14,
//                             fontWeight: FontWeight.w500,
//                             color: Colors.grey,
//                           ),
//                         ),
//                         const SizedBox(height: 4),
//                         Container(
//                           padding: const EdgeInsets.symmetric(horizontal: 12),
//                           decoration: BoxDecoration(
//                             border: Border.all(color: Colors.grey.shade300),
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                           child: DropdownButton<String>(
//                             value: _selectedStatus,
//                             isExpanded: true,
//                             underline: const SizedBox(),
//                             items: _statusOptions.map((String value) {
//                               return DropdownMenuItem<String>(
//                                 value: value,
//                                 child: Text(value),
//                               );
//                             }).toList(),
//                             onChanged: (String? newValue) {
//                               setState(() {
//                                 _selectedStatus = newValue;
//                               });
//                             },
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 24),
//                   ],
//                 ),
//               ),
//             ),
            
//             // Footer with Actions
//             Padding(
//               padding: const EdgeInsets.all(24),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.end,
//                 children: [
//                   TextButton(
//                     onPressed: () => Navigator.pop(context),
//                     child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
//                   ),
//                   const SizedBox(width: 12),
//                   ElevatedButton(
//                     onPressed: _updateAlert,
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.teal,
//                       foregroundColor: Colors.white,
//                       padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                     ),
//                     child: const Text('Update Alert'),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildField(String label, TextEditingController controller, {int maxLines = 1}) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           label,
//           style: const TextStyle(
//             fontSize: 14,
//             fontWeight: FontWeight.w500,
//             color: Colors.grey,
//           ),
//         ),
//         const SizedBox(height: 4),
//         Container(
//           decoration: BoxDecoration(
//             border: Border.all(color: Colors.grey.shade300),
//             borderRadius: BorderRadius.circular(8),
//           ),
//           child: TextField(
//             controller: controller,
//             maxLines: maxLines,
//             decoration: const InputDecoration(
//               contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
//               border: InputBorder.none,
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   void _updateAlert() {
//     final data = {
//       'title': _titleController.text,
//       'description': _descriptionController.text,
//       'type': _selectedType ?? 'Maintenance',
//       'status': _selectedStatus ?? 'Pending',
//       'timestamp': FieldValue.serverTimestamp(),
//     };
    
//     widget.alert.reference.update(data).then((_) {
//       Navigator.pop(context);
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Alert updated successfully'),
//           backgroundColor: Colors.green,
//         ),
//       );
//     }).catchError((error) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error updating alert: $error'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     });
//   }

//   @override
//   void dispose() {
//     _titleController.dispose();
//     _descriptionController.dispose();
//     super.dispose();
//   }
// }

// class EditReportDialog extends StatefulWidget {
//   final DocumentSnapshot report;

//   const EditReportDialog({super.key, required this.report});

//   @override
//   State<EditReportDialog> createState() => _EditReportDialogState();
// }

// class _EditReportDialogState extends State<EditReportDialog> {
//   late TextEditingController _dailyActiveUsersController;
//   late TextEditingController _alertsTodayController;
//   late TextEditingController _connectivityRateController;

//   @override
//   void initState() {
//     super.initState();
//     _dailyActiveUsersController = TextEditingController(
//         text: widget.report['dailyActiveUsers']?.toString() ?? '0');
//     _alertsTodayController = TextEditingController(
//         text: widget.report['alertsToday']?.toString() ?? '0');
//     _connectivityRateController = TextEditingController(
//         text: widget.report['connectivityRate']?.toString() ?? '100');
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Dialog(
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//       child: Container(
//         width: 400,
//         constraints: BoxConstraints(
//           maxHeight: MediaQuery.of(context).size.height * 0.9,
//         ),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             // Header
//             Padding(
//               padding: const EdgeInsets.all(24),
//               child: Row(
//                 children: [
//                   Expanded(
//                     child: Text(
//                       'Edit Report',
//                       style: const TextStyle(
//                         fontSize: 24,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                   IconButton(
//                     icon: const Icon(Icons.close),
//                     onPressed: () => Navigator.pop(context),
//                   ),
//                 ],
//               ),
//             ),
            
//             // Scrollable Content
//             Expanded(
//               child: SingleChildScrollView(
//                 padding: const EdgeInsets.symmetric(horizontal: 24),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     _buildField('Daily Active Users', _dailyActiveUsersController, isNumber: true),
//                     const SizedBox(height: 16),
//                     _buildField('Alerts Today', _alertsTodayController, isNumber: true),
//                     const SizedBox(height: 16),
//                     _buildField('Connectivity Rate (%)', _connectivityRateController, isNumber: true),
//                     const SizedBox(height: 24),
//                   ],
//                 ),
//               ),
//             ),
            
//             // Footer with Actions
//             Padding(
//               padding: const EdgeInsets.all(24),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.end,
//                 children: [
//                   TextButton(
//                     onPressed: () => Navigator.pop(context),
//                     child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
//                   ),
//                   const SizedBox(width: 12),
//                   ElevatedButton(
//                     onPressed: _updateReport,
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.teal,
//                       foregroundColor: Colors.white,
//                       padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                     ),
//                     child: const Text('Update Report'),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildField(String label, TextEditingController controller, {bool isNumber = false}) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           label,
//           style: const TextStyle(
//             fontSize: 14,
//             fontWeight: FontWeight.w500,
//             color: Colors.grey,
//           ),
//         ),
//         const SizedBox(height: 4),
//         Container(
//           decoration: BoxDecoration(
//             border: Border.all(color: Colors.grey.shade300),
//             borderRadius: BorderRadius.circular(8),
//           ),
//           child: TextField(
//             controller: controller,
//             keyboardType: isNumber ? TextInputType.number : TextInputType.text,
//             decoration: const InputDecoration(
//               contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
//               border: InputBorder.none,
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   void _updateReport() {
//     final data = {
//       'dailyActiveUsers': int.tryParse(_dailyActiveUsersController.text) ?? 0,
//       'alertsToday': int.tryParse(_alertsTodayController.text) ?? 0,
//       'connectivityRate': int.tryParse(_connectivityRateController.text) ?? 100,
//       'date': FieldValue.serverTimestamp(),
//     };
    
//     widget.report.reference.update(data).then((_) {
//       Navigator.pop(context);
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Report updated successfully'),
//           backgroundColor: Colors.green,
//         ),
//       );
//     }).catchError((error) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error updating report: $error'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     });
//   }

//   @override
//   void dispose() {
//     _dailyActiveUsersController.dispose();
//     _alertsTodayController.dispose();
//     _connectivityRateController.dispose();
//     super.dispose();
//   }
// }

// //////////////////////////////////////////////////////////////
// // 1. HOME TAB (ORIGINAL - PRESERVED)
// //////////////////////////////////////////////////////////////

// class AdminHomeTab extends StatelessWidget {
//   const AdminHomeTab({super.key});

//   Future<Map<String, String>> _fetchStats() async {
//     final usersSnap = await FirebaseFirestore.instance.collection('users').get();
//     final devicesSnap = await FirebaseFirestore.instance.collection('devices').get();
//     final alertsSnap = await FirebaseFirestore.instance
//         .collection('alerts')
//         .where('status', isEqualTo: 'Pending')
//         .get();

//     final devices = devicesSnap.docs;
//     double totalConnectivity = 0;
//     for (var d in devices) {
//       totalConnectivity += (d['connectivity'] ?? 0);
//     }
//     String connectivity = devices.isNotEmpty ? "${(totalConnectivity / devices.length).round()}%" : "0%";

//     return {
//       'users': usersSnap.size.toString(),
//       'devices': devicesSnap.size.toString(),
//       'alerts': alertsSnap.size.toString(),
//       'connectivity': connectivity,
//     };
//   }

//   @override
//   Widget build(BuildContext context) {
//     return FutureBuilder<Map<String, String>>(
//       future: _fetchStats(),
//       builder: (context, snapshot) {
//         if (!snapshot.hasData) {
//           return const Center(child: CircularProgressIndicator());
//         }
//         final statsValues = snapshot.data!;
//         final stats = [
//           {"title": "Users", "subtitle": "Total Registered", "value": statsValues['users'], "icon": Icons.people},
//           {"title": "Devices", "subtitle": "Active Devices", "value": statsValues['devices'], "icon": Icons.pets},
//           {"title": "Alerts", "subtitle": "Pending Alerts", "value": statsValues['alerts'], "icon": Icons.warning},
//           {"title": "Connectivity", "subtitle": "Average", "value": statsValues['connectivity'], "icon": Icons.wifi},
//         ];

//         return Padding(
//           padding: const EdgeInsets.all(16),
//           child: ListView.builder(
//             itemCount: stats.length,
//             itemBuilder: (context, index) {
//               final s = stats[index];
//               return GradientCard(
//                 leading: Icon(s["icon"] as IconData, color: Colors.teal, size: 30),
//                 title: s["title"] as String,
//                 subtitle: s["subtitle"] as String,
//                 trailing: s["value"] as String,
//               );
//             },
//           ),
//         );
//       },
//     );
//   }
// }

// //////////////////////////////////////////////////////////////
// // 2. USER TAB WITH PUSH METHOD (FIXED - REMOVED setState)
// //////////////////////////////////////////////////////////////

// class UserManagementTab extends StatelessWidget {
//   const UserManagementTab({super.key});

//   void _deleteUser(DocumentSnapshot user, BuildContext context) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Delete User'),
//         content: Text('Are you sure you want to delete ${user['name']}?'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () {
//               user.reference.delete().then((_) {
//                 Navigator.pop(context);
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(
//                     content: Text('User deleted successfully'),
//                     backgroundColor: Colors.green,
//                   ),
//                 );
//               }).catchError((error) {
//                 Navigator.pop(context);
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(
//                     content: Text('Error deleting user: $error'),
//                     backgroundColor: Colors.red,
//                   ),
//                 );
//               });
//             },
//             style: TextButton.styleFrom(foregroundColor: Colors.red),
//             child: const Text('Delete'),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: StreamBuilder<QuerySnapshot>(
//         stream: FirebaseFirestore.instance.collection('users').snapshots(),
//         builder: (context, snapshot) {
//           if (snapshot.hasError) {
//             return Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   const Icon(Icons.error_outline, color: Colors.red, size: 60),
//                   const SizedBox(height: 16),
//                   Text('Error: ${snapshot.error}'),
//                   const SizedBox(height: 16),
//                   ElevatedButton(
//                     onPressed: () {
//                       // Just refresh by rebuilding the StreamBuilder
//                     },
//                     child: const Text('Retry'),
//                   ),
//                 ],
//               ),
//             );
//           }
          
//           if (!snapshot.hasData) {
//             return const Center(child: CircularProgressIndicator());
//           }
          
//           final users = snapshot.data!.docs;
          
//           if (users.isEmpty) {
//             return Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
//                   const SizedBox(height: 16),
//                   Text(
//                     'No users found',
//                     style: TextStyle(fontSize: 18, color: Colors.grey[600]),
//                   ),
//                   const SizedBox(height: 8),
//                   Text(
//                     'Tap the + button to add a user',
//                     style: TextStyle(fontSize: 14, color: Colors.grey[500]),
//                   ),
//                 ],
//               ),
//             );
//           }
          
//           return ListView.builder(
//             padding: const EdgeInsets.all(16),
//             itemCount: users.length,
//             itemBuilder: (context, index) {
//               final u = users[index];
//               return DashboardCard(
//                 leading: CircleAvatar(
//                   radius: 24,
//                   backgroundColor: Colors.teal.withOpacity(0.1),
//                   child: const Icon(Icons.person, color: Colors.teal),
//                 ),
//                 title: u['name'] ?? 'Unknown User',
//                 subtitle: 'Email: ${u['email'] ?? 'N/A'}',
//                 subtitle2: 'Pets: ${u['pets'] ?? 0}',
//                 badge1: u['status'] ?? 'Active',
//                 badge1Color: u['status'] == 'Active' ? Colors.green : Colors.orange,
//                 onEdit: () => showDialog(
//                   context: context,
//                   builder: (context) => EditUserDialog(user: u),
//                 ),
//                 onDelete: () => _deleteUser(u, context),
//               );
//             },
//           );
//         },
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () => showDialog(
//           context: context,
//           builder: (context) => const AddUserDialog(),
//         ),
//         backgroundColor: Colors.teal,
//         child: const Icon(Icons.add, color: Colors.white),
//       ),
//     );
//   }
// }

// //////////////////////////////////////////////////////////////
// // 3. DEVICES TAB WITH PUSH METHOD (FIXED - REMOVED setState)
// //////////////////////////////////////////////////////////////

// class DeviceManagementTab extends StatelessWidget {
//   const DeviceManagementTab({super.key});

//   void _deleteDevice(DocumentSnapshot device, BuildContext context) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Delete Device'),
//         content: Text('Are you sure you want to delete device for ${device['petName']}?'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () {
//               device.reference.delete().then((_) {
//                 Navigator.pop(context);
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(
//                     content: Text('Device deleted successfully'),
//                     backgroundColor: Colors.green,
//                   ),
//                 );
//               }).catchError((error) {
//                 Navigator.pop(context);
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(
//                     content: Text('Error deleting device: $error'),
//                     backgroundColor: Colors.red,
//                   ),
//                 );
//               });
//             },
//             style: TextButton.styleFrom(foregroundColor: Colors.red),
//             child: const Text('Delete'),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: StreamBuilder<QuerySnapshot>(
//         stream: FirebaseFirestore.instance.collection('devices').snapshots(),
//         builder: (context, snapshot) {
//           if (snapshot.hasError) {
//             return Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   const Icon(Icons.error_outline, color: Colors.red, size: 60),
//                   const SizedBox(height: 16),
//                   Text('Error: ${snapshot.error}'),
//                   const SizedBox(height: 16),
//                   ElevatedButton(
//                     onPressed: () {
//                       // Just refresh by rebuilding the StreamBuilder
//                     },
//                     child: const Text('Retry'),
//                   ),
//                 ],
//               ),
//             );
//           }
          
//           if (!snapshot.hasData) {
//             return const Center(child: CircularProgressIndicator());
//           }
          
//           final devices = snapshot.data!.docs;
          
//           if (devices.isEmpty) {
//             return Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Icon(Icons.pets_outlined, size: 80, color: Colors.grey[400]),
//                   const SizedBox(height: 16),
//                   Text(
//                     'No devices found',
//                     style: TextStyle(fontSize: 18, color: Colors.grey[600]),
//                   ),
//                   const SizedBox(height: 8),
//                   Text(
//                     'Tap the + button to add a device',
//                     style: TextStyle(fontSize: 14, color: Colors.grey[500]),
//                   ),
//                 ],
//               ),
//             );
//           }
          
//           return ListView.builder(
//             padding: const EdgeInsets.all(16),
//             itemCount: devices.length,
//             itemBuilder: (context, index) {
//               final d = devices[index];
//               final connectivity = d['connectivity'] ?? 100;
//               final isOffline = connectivity < 50;
              
//               return DashboardCard(
//                 leading: CircleAvatar(
//                   radius: 24,
//                   backgroundColor: Colors.teal.withOpacity(0.1),
//                   child: const Icon(Icons.pets, color: Colors.teal),
//                 ),
//                 title: d['petName'] ?? 'Unknown Pet',
//                 subtitle: 'Device: ${d['deviceId'] ?? 'N/A'}',
//                 subtitle2: 'Owner: ${d['ownerId'] ?? 'N/A'}',
//                 badge1: isOffline ? 'Offline' : '$connectivity%',
//                 badge1Color: isOffline ? Colors.red : Colors.green,
//                 badge2: d['deviceId'] ?? 'DEVICE',
//                 badge2Color: Colors.blue,
//                 onEdit: () => showDialog(
//                   context: context,
//                   builder: (context) => EditDeviceDialog(device: d),
//                 ),
//                 onDelete: () => _deleteDevice(d, context),
//               );
//             },
//           );
//         },
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () => showDialog(
//           context: context,
//           builder: (context) => const AddDeviceDialog(),
//         ),
//         backgroundColor: Colors.teal,
//         child: const Icon(Icons.add, color: Colors.white),
//       ),
//     );
//   }
// }

// //////////////////////////////////////////////////////////////
// // 4. ALERTS TAB WITH PUSH METHOD (FIXED - REMOVED setState)
// //////////////////////////////////////////////////////////////

// class AlertsTab extends StatelessWidget {
//   const AlertsTab({super.key});

//   void _deleteAlert(DocumentSnapshot alert, BuildContext context) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Delete Alert'),
//         content: Text('Are you sure you want to delete "${alert['title']}"?'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () {
//               alert.reference.delete().then((_) {
//                 Navigator.pop(context);
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(
//                     content: Text('Alert deleted successfully'),
//                     backgroundColor: Colors.green,
//                   ),
//                 );
//               }).catchError((error) {
//                 Navigator.pop(context);
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(
//                     content: Text('Error deleting alert: $error'),
//                     backgroundColor: Colors.red,
//                   ),
//                 );
//               });
//             },
//             style: TextButton.styleFrom(foregroundColor: Colors.red),
//             child: const Text('Delete'),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: StreamBuilder<QuerySnapshot>(
//         stream: FirebaseFirestore.instance.collection('alerts').snapshots(),
//         builder: (context, snapshot) {
//           if (snapshot.hasError) {
//             return Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   const Icon(Icons.error_outline, color: Colors.red, size: 60),
//                   const SizedBox(height: 16),
//                   Text('Error: ${snapshot.error}'),
//                   const SizedBox(height: 16),
//                   ElevatedButton(
//                     onPressed: () {
//                       // Just refresh by rebuilding the StreamBuilder
//                     },
//                     child: const Text('Retry'),
//                   ),
//                 ],
//               ),
//             );
//           }
          
//           if (!snapshot.hasData) {
//             return const Center(child: CircularProgressIndicator());
//           }
          
//           final alerts = snapshot.data!.docs;
          
//           if (alerts.isEmpty) {
//             return Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Icon(Icons.notifications_none, size: 80, color: Colors.grey[400]),
//                   const SizedBox(height: 16),
//                   Text(
//                     'No alerts found',
//                     style: TextStyle(fontSize: 18, color: Colors.grey[600]),
//                   ),
//                   const SizedBox(height: 8),
//                   Text(
//                     'Tap the + button to add an alert',
//                     style: TextStyle(fontSize: 14, color: Colors.grey[500]),
//                   ),
//                 ],
//               ),
//             );
//           }
          
//           return ListView.builder(
//             padding: const EdgeInsets.all(16),
//             itemCount: alerts.length,
//             itemBuilder: (context, index) {
//               final a = alerts[index];
//               final isPending = a['status'] == 'Pending';
              
//               return DashboardCard(
//                 leading: CircleAvatar(
//                   radius: 24,
//                   backgroundColor: (a['type'] == 'Maintenance' ? Colors.orange : Colors.blue).withOpacity(0.1),
//                   child: Icon(
//                     a['type'] == 'Maintenance' ? Icons.build : Icons.campaign,
//                     color: a['type'] == 'Maintenance' ? Colors.orange : Colors.blue,
//                   ),
//                 ),
//                 title: a['title'] ?? 'No Title',
//                 subtitle: a['description'] ?? '',
//                 badge1: a['type'] ?? 'System',
//                 badge1Color: a['type'] == 'Maintenance' ? Colors.orange : Colors.blue,
//                 badge2: a['status'] ?? 'Pending',
//                 badge2Color: isPending ? Colors.orange : Colors.green,
//                 onEdit: () => showDialog(
//                   context: context,
//                   builder: (context) => EditAlertDialog(alert: a),
//                 ),
//                 onDelete: () => _deleteAlert(a, context),
//               );
//             },
//           );
//         },
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () => showDialog(
//           context: context,
//           builder: (context) => const AddAlertDialog(),
//         ),
//         backgroundColor: Colors.teal,
//         child: const Icon(Icons.add, color: Colors.white),
//       ),
//     );
//   }
// }

// //////////////////////////////////////////////////////////////
// // 5. REPORTS TAB WITH PUSH METHOD (FIXED - REMOVED setState)
// //////////////////////////////////////////////////////////////

// class ReportsTab extends StatelessWidget {
//   const ReportsTab({super.key});

//   void _deleteReport(DocumentSnapshot report, BuildContext context) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Delete Report'),
//         content: const Text('Are you sure you want to delete this report?'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () {
//               report.reference.delete().then((_) {
//                 Navigator.pop(context);
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(
//                     content: Text('Report deleted successfully'),
//                     backgroundColor: Colors.green,
//                   ),
//                 );
//               }).catchError((error) {
//                 Navigator.pop(context);
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(
//                     content: Text('Error deleting report: $error'),
//                     backgroundColor: Colors.red,
//                   ),
//                 );
//               });
//             },
//             style: TextButton.styleFrom(foregroundColor: Colors.red),
//             child: const Text('Delete'),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: StreamBuilder<QuerySnapshot>(
//         stream: FirebaseFirestore.instance
//             .collection('reports')
//             .orderBy('date', descending: true)
//             .snapshots(),
//         builder: (context, snapshot) {
//           if (snapshot.hasError) {
//             return Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   const Icon(Icons.error_outline, color: Colors.red, size: 60),
//                   const SizedBox(height: 16),
//                   Text('Error: ${snapshot.error}'),
//                   const SizedBox(height: 16),
//                   ElevatedButton(
//                     onPressed: () {
//                       // Just refresh by rebuilding the StreamBuilder
//                     },
//                     child: const Text('Retry'),
//                   ),
//                 ],
//               ),
//             );
//           }
          
//           if (!snapshot.hasData) {
//             return const Center(child: CircularProgressIndicator());
//           }
          
//           final reports = snapshot.data!.docs;
          
//           if (reports.isEmpty) {
//             return Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Icon(Icons.insert_chart_outlined, size: 80, color: Colors.grey[400]),
//                   const SizedBox(height: 16),
//                   Text(
//                     'No reports found',
//                     style: TextStyle(fontSize: 18, color: Colors.grey[600]),
//                   ),
//                   const SizedBox(height: 8),
//                   Text(
//                     'Tap the + button to add a report',
//                     style: TextStyle(fontSize: 14, color: Colors.grey[500]),
//                   ),
//                 ],
//               ),
//             );
//           }
          
//           return ListView.builder(
//             padding: const EdgeInsets.all(16),
//             itemCount: reports.length,
//             itemBuilder: (context, index) {
//               final r = reports[index];
              
//               return DashboardCard(
//                 leading: CircleAvatar(
//                   radius: 24,
//                   backgroundColor: Colors.teal.withOpacity(0.1),
//                   child: const Icon(Icons.bar_chart, color: Colors.teal),
//                 ),
//                 title: 'Daily Users: ${r['dailyActiveUsers'] ?? 0}',
//                 subtitle: 'Alerts: ${r['alertsToday'] ?? 0}',
//                 subtitle2: 'Connectivity: ${r['connectivityRate'] ?? 100}%',
//                 badge1: 'Report ${index + 1}',
//                 badge1Color: Colors.teal,
//                 onEdit: () => showDialog(
//                   context: context,
//                   builder: (context) => EditReportDialog(report: r),
//                 ),
//                 onDelete: () => _deleteReport(r, context),
//               );
//             },
//           );
//         },
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () => showDialog(
//           context: context,
//           builder: (context) => const AddReportDialog(),
//         ),
//         backgroundColor: Colors.teal,
//         child: const Icon(Icons.add, color: Colors.white),
//       ),
//     );
//   }
// }