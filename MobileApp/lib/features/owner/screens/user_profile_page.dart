import 'dart:io';
import 'package:flutter/material.dart';
import '../data/owner_repository.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final OwnerRepository _ownerRepository = OwnerRepository();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final oldPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool loading = true;
  List<Map<String, dynamic>> pets = [];
  bool loadingPets = true;

  // *** NEW *** Track which pet is currently uploading a photo
  String? _uploadingPhotoForPetId;

  Future<void> loadUserData() async {
    final data = await _ownerRepository.fetchUserProfile();
    nameController.text = data?['name'] ?? '';
    emailController.text = data?['email'] ?? '';
    phoneController.text = data?['phone'] ?? '';
    setState(() => loading = false);
  }

  Future<void> updateProfile() async {
    await _ownerRepository.updateProfile(
      name: nameController.text,
      email: emailController.text,
      phone: phoneController.text,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Profile updated successfully")),
    );
  }

  Future<void> changePassword() async {
    final oldPassword = oldPasswordController.text;
    final newPassword = newPasswordController.text;
    final confirmPassword = confirmPasswordController.text;
    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("New passwords do not match")),
      );
      return;
    }
    try {
      await _ownerRepository.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
      oldPasswordController.clear();
      newPasswordController.clear();
      confirmPasswordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password updated successfully")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  Future<void> loadUserPets() async {
    setState(() => loadingPets = true);
    final petsList = await _ownerRepository.fetchUserPets();
    setState(() {
      pets = petsList;
      loadingPets = false;
    });
  }

  Future<void> updatePet(String petId, Map<String, dynamic> data) async {
    await _ownerRepository.updatePet(petId, data);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Pet updated successfully")),
    );
  }

  // *** NEW *** Pick and upload pet photo, then refresh pets list
  Future<void> _handlePetPhotoUpload(String docId) async {
    setState(() => _uploadingPhotoForPetId = docId);
    try {
      final url = await _ownerRepository.pickAndUploadPhoto(
        docId: docId,
        onError: (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Upload failed: $e'),
                backgroundColor: Colors.red.shade700,
              ),
            );
          }
        },
      );
      if (url != null && mounted) {
        await loadUserPets(); // *** NEW *** Refresh to show new photo
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pet photo updated!'),
            backgroundColor: Color.fromARGB(255, 0, 150, 136),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhotoForPetId = null);
    }
  }

  @override
  void initState() {
    super.initState();
    loadUserData();
    loadUserPets();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // PROFILE CARD
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 35,
                          backgroundColor: Color.fromARGB(255, 0, 150, 136),
                          child:
                              Icon(Icons.person, color: Colors.white, size: 35),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nameController.text,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              emailController.text,
                              style: TextStyle(
                                  color: colorScheme.onSurfaceVariant),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // EDIT PROFILE (EXPANDABLE)
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ExpansionTile(
                      leading: const Icon(Icons.edit,
                          color: Color.fromARGB(255, 0, 150, 136)),
                      title: const Text("Edit My Details"),
                      childrenPadding: const EdgeInsets.all(16),
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(labelText: "Name"),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: emailController,
                          decoration: const InputDecoration(labelText: "Email"),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: phoneController,
                          decoration: const InputDecoration(labelText: "Phone"),
                        ),
                        const SizedBox(height: 15),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color.fromARGB(255, 0, 150, 136),
                          ),
                          onPressed: updateProfile,
                          child: const Text("Save Changes"),
                        )
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // CHANGE PASSWORD (EXPANDABLE)
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ExpansionTile(
                      leading: const Icon(Icons.lock,
                          color: Color.fromARGB(255, 0, 150, 136)),
                      title: const Text("Change Password"),
                      childrenPadding: const EdgeInsets.all(16),
                      children: [
                        TextField(
                          controller: oldPasswordController,
                          obscureText: true,
                          decoration:
                              const InputDecoration(labelText: "Old Password"),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: newPasswordController,
                          obscureText: true,
                          decoration:
                              const InputDecoration(labelText: "New Password"),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: confirmPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                              labelText: "Confirm New Password"),
                        ),
                        const SizedBox(height: 15),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color.fromARGB(255, 0, 150, 136),
                          ),
                          onPressed: changePassword,
                          child: const Text("Update Password"),
                        )
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const SizedBox(height: 24),

                  Text(
                    "Your Pet",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),

                  const SizedBox(height: 12),

                  loadingPets
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          children: pets.map((petDoc) {
                            String petName = petDoc['petName'] ?? '';
                            String size = petDoc['size'] ?? '';
                            String ageGroup = petDoc['ageGroup'] ?? '';
                            String coatType = petDoc['coatType'] ?? '';
                            String isFlatFaced =
                                petDoc['isFlatFaced']?.toString() ?? '';
                            String activityLevel =
                                petDoc['activityLevel'] ?? '';
                            String docId = petDoc['_docId'] ?? '';
                            // *** NEW ***
                            String? photoUrl = petDoc['photoUrl'];

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ExpansionTile(
                                // *** NEW *** Show pet photo as leading avatar
                                leading: CircleAvatar(
                                  radius: 20,
                                  backgroundColor:
                                      const Color.fromARGB(255, 0, 150, 136),
                                  backgroundImage: photoUrl != null
                                      ? NetworkImage(photoUrl)
                                      : null,
                                  child: photoUrl == null
                                      ? const Icon(Icons.pets,
                                          color: Colors.white, size: 20)
                                      : null,
                                ),
                                title: Text(petDoc['petName'] ?? "Pet"),
                                childrenPadding: const EdgeInsets.all(16),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      children: [
                                        // *** NEW START *** — Pet photo picker
                                        Center(
                                          child: GestureDetector(
                                            onTap: _uploadingPhotoForPetId ==
                                                    docId
                                                ? null
                                                : () => _handlePetPhotoUpload(
                                                    docId),
                                            child: Stack(
                                              alignment: Alignment.bottomRight,
                                              children: [
                                                CircleAvatar(
                                                  radius: 50,
                                                  backgroundColor:
                                                      Theme.of(context)
                                                          .colorScheme
                                                          .surfaceVariant,
                                                  backgroundImage: photoUrl !=
                                                          null
                                                      ? NetworkImage(photoUrl)
                                                      : null,
                                                  child: photoUrl == null
                                                      ? Icon(Icons.pets,
                                                          size: 45,
                                                          color: colorScheme
                                                              .onSurfaceVariant)
                                                      : null,
                                                ),
                                                if (_uploadingPhotoForPetId ==
                                                    docId)
                                                  const Positioned.fill(
                                                    child: CircleAvatar(
                                                      backgroundColor:
                                                          Colors.black38,
                                                      child:
                                                          CircularProgressIndicator(
                                                        color: Colors.white,
                                                        strokeWidth: 2.5,
                                                      ),
                                                    ),
                                                  )
                                                else
                                                  CircleAvatar(
                                                    radius: 16,
                                                    backgroundColor:
                                                        const Color.fromARGB(
                                                            255, 0, 150, 136),
                                                    child: const Icon(
                                                        Icons.camera_alt,
                                                        size: 16,
                                                        color: Colors.white),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Tap photo to change',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        // *** NEW END ***

                                        const SizedBox(height: 16),

                                        TextField(
                                          decoration: const InputDecoration(
                                              labelText: "Pet Name"),
                                          controller: TextEditingController(
                                              text: petName),
                                          onChanged: (val) => petName = val,
                                        ),
                                        const SizedBox(height: 10),
                                        TextField(
                                          decoration: const InputDecoration(
                                              labelText: "Size"),
                                          controller:
                                              TextEditingController(text: size),
                                          onChanged: (val) => size = val,
                                        ),
                                        const SizedBox(height: 10),
                                        TextField(
                                          decoration: const InputDecoration(
                                              labelText: "Age Group"),
                                          controller: TextEditingController(
                                              text: ageGroup),
                                          onChanged: (val) => ageGroup = val,
                                        ),
                                        const SizedBox(height: 10),
                                        TextField(
                                          decoration: const InputDecoration(
                                              labelText: "Coat Type"),
                                          controller: TextEditingController(
                                              text: coatType),
                                          onChanged: (val) => coatType = val,
                                        ),
                                        const SizedBox(height: 10),
                                        TextField(
                                          decoration: const InputDecoration(
                                              labelText: "Flat Faced"),
                                          controller: TextEditingController(
                                              text: isFlatFaced),
                                          onChanged: (val) => isFlatFaced = val,
                                        ),
                                        const SizedBox(height: 10),
                                        TextField(
                                          decoration: const InputDecoration(
                                              labelText: "Activity Level"),
                                          controller: TextEditingController(
                                              text: activityLevel),
                                          onChanged: (val) =>
                                              activityLevel = val,
                                        ),

                                        const SizedBox(height: 15),

                                        ElevatedButton(
                                          onPressed: () {
                                            updatePet(docId, {
                                              'petName': petName,
                                              'size': size,
                                              'ageGroup': ageGroup,
                                              'coatType': coatType,
                                              'isFlatFaced': isFlatFaced,
                                              'activityLevel': activityLevel,
                                            });
                                          },
                                          child: const Text("Save Pet Changes"),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),

                  Text(
                    "Account Info",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      "Name: ${nameController.text}\n"
                      "Email: ${emailController.text}\n"
                      "Phone: ${phoneController.text}",
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
