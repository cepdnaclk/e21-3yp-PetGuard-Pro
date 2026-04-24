// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// import '../../../core/widgets/custom_button.dart';
// import '../../admin/screens/admin_dashboard_screen.dart';
// import '../../owner/screens/user_dashboard.dart';
// import 'signup_screen.dart';

// class LoginScreen extends StatefulWidget {
//   const LoginScreen({super.key});

//   @override
//   State<LoginScreen> createState() => _LoginScreenState();
// }

// class _LoginScreenState extends State<LoginScreen> {
//   String? selectedRole; // "admin" or "user"
//   final TextEditingController emailController = TextEditingController();
//   final TextEditingController passwordController = TextEditingController();

//   bool isLoading = false;
//   List<String> savedEmails = [];

//   @override
//   void initState() {
//     super.initState();
//     _loadSavedPreferences();
//   }

//   @override
//   void dispose() {
//     emailController.dispose();
//     passwordController.dispose();
//     super.dispose();
//   }

//   Future<void> _loadSavedPreferences() async {
//     final prefs = await SharedPreferences.getInstance();

//     if (!mounted) return;

//     setState(() {
//       savedEmails = prefs.getStringList('savedEmails') ?? [];
//       selectedRole = prefs.getString('lastSelectedRole');
//       emailController.text = prefs.getString('lastUsedEmail') ?? '';
//     });
//   }

//   Future<void> _saveEmail(String email) async {
//     final prefs = await SharedPreferences.getInstance();

//     final updatedEmails = List<String>.from(savedEmails);
//     if (!updatedEmails.contains(email)) {
//       updatedEmails.add(email);
//     }

//     await prefs.setStringList('savedEmails', updatedEmails);
//     await prefs.setString('lastUsedEmail', email);

//     if (mounted) {
//       setState(() {
//         savedEmails = updatedEmails;
//       });
//     }
//   }

//   Future<void> _saveSelectedRole(String role) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString('lastSelectedRole', role);
//   }

//   Future<UserCredential> _signIn() async {
//     final email = emailController.text.trim();
//     final password = passwordController.text.trim();

//     if (email.isEmpty || password.isEmpty) {
//       throw FirebaseAuthException(
//         code: 'empty-fields',
//         message: 'Please enter email and password',
//       );
//     }

//     return FirebaseAuth.instance.signInWithEmailAndPassword(
//       email: email,
//       password: password,
//     );
//   }

//   Future<void> _loginAdmin() async {
//     setState(() {
//       isLoading = true;
//     });

//     try {
//       final credential = await _signIn();
//       final uid = credential.user!.uid;
//       final email = emailController.text.trim();

//       final adminDoc =
//           await FirebaseFirestore.instance.collection('admins').doc(uid).get();

//       if (!mounted) return;

//       if (adminDoc.exists) {
//         await _saveEmail(email);
//         await _saveSelectedRole('admin');

//         if (!mounted) return;
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(
//             builder: (_) => const AdminDashboardScreen(),
//           ),
//         );
//       } else {
//         await FirebaseAuth.instance.signOut();

//         if (!mounted) return;
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('This is not an admin account')),
//         );
//       }
//     } on FirebaseAuthException catch (e) {
//       _showAuthError(e, isAdmin: true);
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error: $e')),
//       );
//     } finally {
//       if (mounted) {
//         setState(() {
//           isLoading = false;
//         });
//       }
//     }
//   }

//   Future<void> _loginUser() async {
//     setState(() {
//       isLoading = true;
//     });

//     try {
//       final credential = await _signIn();
//       final uid = credential.user!.uid;
//       final email = emailController.text.trim();

//       final userDoc =
//           await FirebaseFirestore.instance.collection('users').doc(uid).get();

//       if (!mounted) return;

//       if (!userDoc.exists) {
//         await FirebaseAuth.instance.signOut();

//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('This is not a user account'),
//           ),
//         );
//         return;
//       }

//       final data = userDoc.data()!;
//       final status = (data['status'] ?? 'Pending').toString();

//       if (status == 'Pending') {
//         await FirebaseAuth.instance.signOut();

//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Your account is waiting for admin approval'),
//           ),
//         );
//         return;
//       }

//       if (status == 'Inactive') {
//         await FirebaseAuth.instance.signOut();

//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Your account has been blocked'),
//           ),
//         );
//         return;
//       }

//       await _saveEmail(email);
//       await _saveSelectedRole('user');

//       if (!mounted) return;
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(
//           builder: (_) => const UserDashboardScreen(),
//         ),
//       );
//     } on FirebaseAuthException catch (e) {
//       _showAuthError(e, isAdmin: false);
//     } catch (e) {
//       if (!mounted) return;

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error: $e')),
//       );
//     } finally {
//       if (mounted) {
//         setState(() {
//           isLoading = false;
//         });
//       }
//     }
//   }

//   void _showAuthError(FirebaseAuthException e, {required bool isAdmin}) {
//     String msg = isAdmin ? 'Admin login failed' : 'User login failed';

//     if (e.code == 'empty-fields') {
//       msg = 'Please enter email and password';
//     } else if (e.code == 'user-not-found') {
//       msg = 'No account found for this email';
//     } else if (e.code == 'wrong-password') {
//       msg = 'Wrong password';
//     } else if (e.code == 'invalid-email') {
//       msg = 'Invalid email';
//     } else if (e.code == 'invalid-credential') {
//       msg = 'Invalid email or password';
//     } else if (e.code == 'too-many-requests') {
//       msg = 'Too many attempts. Try again later';
//     }

//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text(msg)),
//     );
//   }

//   void _handleLogin() {
//     if (selectedRole == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Please select a role')),
//       );
//       return;
//     }

//     if (selectedRole == "admin") {
//       _loginAdmin();
//     } else if (selectedRole == "user") {
//       _loginUser();
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     const dashboardGreen = Color.fromARGB(255, 0, 150, 136);

//     final roleSelected = selectedRole != null;

//     return Scaffold(
//       resizeToAvoidBottomInset: true,
//       body: SafeArea(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.all(24),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               const SizedBox(height: 50),
//               Text(
//                 'PetGuard Pro',
//                 textAlign: TextAlign.center,
//                 style: Theme.of(context).textTheme.headlineMedium,
//               ),
//               const SizedBox(height: 12),
//               const Text(
//                 'Login to continue',
//                 textAlign: TextAlign.center,
//                 style: TextStyle(fontSize: 16, color: Colors.black54),
//               ),
//               const SizedBox(height: 32),
//               const Text(
//                 "Select Role",
//                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//               ),
//               const SizedBox(height: 12),
//               Row(
//                 children: [
//                   Expanded(
//                     child: GestureDetector(
//                       onTap: isLoading
//                           ? null
//                           : () {
//                               setState(() {
//                                 selectedRole =
//                                     selectedRole == "admin" ? null : "admin";
//                               });
//                             },
//                       child: Container(
//                         height: 60,
//                         decoration: BoxDecoration(
//                           color: selectedRole == "admin"
//                               ? dashboardGreen
//                               : Colors.grey[200],
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                         child: Center(
//                           child: Text(
//                             "Admin",
//                             style: TextStyle(
//                               color: selectedRole == "admin"
//                                   ? Colors.white
//                                   : Colors.black87,
//                               fontWeight: FontWeight.bold,
//                               fontSize: 16,
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(width: 16),
//                   Expanded(
//                     child: GestureDetector(
//                       onTap: isLoading
//                           ? null
//                           : () {
//                               setState(() {
//                                 selectedRole =
//                                     selectedRole == "user" ? null : "user";
//                               });
//                             },
//                       child: Container(
//                         height: 60,
//                         decoration: BoxDecoration(
//                           color: selectedRole == "user"
//                               ? dashboardGreen
//                               : Colors.grey[200],
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                         child: Center(
//                           child: Text(
//                             "User",
//                             style: TextStyle(
//                               color: selectedRole == "user"
//                                   ? Colors.white
//                                   : Colors.black87,
//                               fontWeight: FontWeight.bold,
//                               fontSize: 16,
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 32),
//               Autocomplete<String>(
//                 optionsBuilder: (TextEditingValue textEditingValue) {
//                   if (savedEmails.isEmpty) {
//                     return const Iterable<String>.empty();
//                   }

//                   if (textEditingValue.text.isEmpty) {
//                     return savedEmails;
//                   }

//                   return savedEmails.where(
//                     (email) => email.toLowerCase().contains(
//                           textEditingValue.text.toLowerCase(),
//                         ),
//                   );
//                 },
//                 onSelected: (String selection) {
//                   emailController.text = selection;
//                 },
//                 fieldViewBuilder:
//                     (context, controller, focusNode, onEditingComplete) {
//                   controller.value = TextEditingValue(
//                     text: emailController.text,
//                     selection: TextSelection.collapsed(
//                       offset: emailController.text.length,
//                     ),
//                   );

//                   return TextField(
//                     controller: controller,
//                     focusNode: focusNode,
//                     enabled: roleSelected && !isLoading,
//                     keyboardType: TextInputType.emailAddress,
//                     onChanged: (value) {
//                       emailController.text = value;
//                     },
//                     decoration: InputDecoration(
//                       labelText: 'Email',
//                       hintText: savedEmails.isNotEmpty
//                           ? 'Type or select previous email'
//                           : 'Email',
//                       border: const OutlineInputBorder(),
//                       fillColor: roleSelected ? null : Colors.grey[200],
//                       filled: !roleSelected,
//                     ),
//                   );
//                 },
//               ),
//               const SizedBox(height: 16),
//               TextField(
//                 controller: passwordController,
//                 enabled: roleSelected && !isLoading,
//                 obscureText: true,
//                 decoration: InputDecoration(
//                   labelText: 'Password',
//                   border: const OutlineInputBorder(),
//                   fillColor: roleSelected ? null : Colors.grey[200],
//                   filled: !roleSelected,
//                 ),
//               ),
//               const SizedBox(height: 32),
//               if (isLoading)
//                 const Center(
//                   child: Padding(
//                     padding: EdgeInsets.only(bottom: 16),
//                     child: CircularProgressIndicator(
//                       color: Color.fromARGB(255, 0, 150, 136),
//                     ),
//                   ),
//                 ),
//               CustomButton(
//                 text: isLoading ? 'Logging in...' : 'Login',
//                 color: dashboardGreen,
//                 onTap: isLoading ? () {} : _handleLogin,
//               ),
//               const SizedBox(height: 16),
//               TextButton(
//                 onPressed: isLoading
//                     ? null
//                     : () {
//                         Navigator.push(
//                           context,
//                           MaterialPageRoute(
//                             builder: (_) => const SignupScreen(),
//                           ),
//                         );
//                       },
//                 child: const Text("Create new account"),
//               ),
//               const SizedBox(height: 50),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/widgets/custom_button.dart';
import '../../admin/screens/admin_dashboard_screen.dart';
import '../../owner/screens/user_dashboard.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String? selectedRole; // "admin" or "user"
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;
  List<String> savedEmails = [];

  @override
  void initState() {
    super.initState();
    _loadSavedPreferences();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      savedEmails = prefs.getStringList('savedEmails') ?? [];
      selectedRole = prefs.getString('lastSelectedRole');
      emailController.text = prefs.getString('lastUsedEmail') ?? '';
    });
  }

  Future<void> _saveEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();

    final updatedEmails = List<String>.from(savedEmails);
    if (!updatedEmails.contains(email)) {
      updatedEmails.add(email);
    }

    await prefs.setStringList('savedEmails', updatedEmails);
    await prefs.setString('lastUsedEmail', email);

    if (mounted) {
      setState(() {
        savedEmails = updatedEmails;
      });
    }
  }

  Future<void> _saveSelectedRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastSelectedRole', role);
  }

  Future<UserCredential> _signIn() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      throw FirebaseAuthException(
        code: 'empty-fields',
        message: 'Please enter email and password',
      );
    }

    return FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> _loginAdmin() async {
    setState(() {
      isLoading = true;
    });

    try {
      final credential = await _signIn();
      final uid = credential.user!.uid;
      final email = emailController.text.trim();

      final adminDoc =
          await FirebaseFirestore.instance.collection('admins').doc(uid).get();

      if (!mounted) return;

      if (adminDoc.exists) {
        await _saveEmail(email);
        await _saveSelectedRole('admin');

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const AdminDashboardScreen(),
          ),
        );
      } else {
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This is not an admin account')),
        );
      }
    } on FirebaseAuthException catch (e) {
      _showAuthError(e, isAdmin: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loginUser() async {
    setState(() {
      isLoading = true;
    });

    try {
      final credential = await _signIn();
      final uid = credential.user!.uid;
      final email = emailController.text.trim();

      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (!mounted) return;

      if (!userDoc.exists) {
        await FirebaseAuth.instance.signOut();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This is not a user account'),
          ),
        );
        return;
      }

      final data = userDoc.data()!;
      final status = (data['status'] ?? 'Pending').toString();

      if (status == 'Pending') {
        await FirebaseAuth.instance.signOut();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your account is waiting for admin approval'),
          ),
        );
        return;
      }

      if (status == 'Inactive') {
        await FirebaseAuth.instance.signOut();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your account has been blocked'),
          ),
        );
        return;
      }

      await _saveEmail(email);
      await _saveSelectedRole('user');

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const UserDashboardScreen(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      _showAuthError(e, isAdmin: false);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _showAuthError(FirebaseAuthException e, {required bool isAdmin}) {
    String msg = isAdmin ? 'Admin login failed' : 'User login failed';

    if (e.code == 'empty-fields') {
      msg = 'Please enter email and password';
    } else if (e.code == 'user-not-found') {
      msg = 'No account found for this email';
    } else if (e.code == 'wrong-password') {
      msg = 'Wrong password';
    } else if (e.code == 'invalid-email') {
      msg = 'Invalid email';
    } else if (e.code == 'invalid-credential') {
      msg = 'Invalid email or password';
    } else if (e.code == 'too-many-requests') {
      msg = 'Too many attempts. Try again later';
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  void _handleLogin() {
    if (selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a role')),
      );
      return;
    }

    if (selectedRole == "admin") {
      _loginAdmin();
    } else if (selectedRole == "user") {
      _loginUser();
    }
  }

  @override
  Widget build(BuildContext context) {
    const dashboardGreen = Color.fromARGB(255, 0, 150, 136);

    final roleSelected = selectedRole != null;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 50),
              Text(
                'PetGuard Pro',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              const Text(
                'Login to continue',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 32),
              const Text(
                "Select Role",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: isLoading
                          ? null
                          : () {
                              setState(() {
                                selectedRole =
                                    selectedRole == "admin" ? null : "admin";
                              });
                            },
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                          color: selectedRole == "admin"
                              ? dashboardGreen
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            "Admin",
                            style: TextStyle(
                              color: selectedRole == "admin"
                                  ? Colors.white
                                  : Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: isLoading
                          ? null
                          : () {
                              setState(() {
                                selectedRole =
                                    selectedRole == "user" ? null : "user";
                              });
                            },
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                          color: selectedRole == "user"
                              ? dashboardGreen
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            "User",
                            style: TextStyle(
                              color: selectedRole == "user"
                                  ? Colors.white
                                  : Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (savedEmails.isEmpty) {
                    return const Iterable<String>.empty();
                  }

                  if (textEditingValue.text.isEmpty) {
                    return savedEmails;
                  }

                  return savedEmails.where(
                    (email) => email.toLowerCase().contains(
                          textEditingValue.text.toLowerCase(),
                        ),
                  );
                },
                onSelected: (String selection) {
                  emailController.text = selection;
                },
                fieldViewBuilder:
                    (context, controller, focusNode, onEditingComplete) {
                  controller.value = TextEditingValue(
                    text: emailController.text,
                    selection: TextSelection.collapsed(
                      offset: emailController.text.length,
                    ),
                  );

                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    enabled: roleSelected && !isLoading,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (value) {
                      emailController.text = value;
                    },
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: savedEmails.isNotEmpty
                          ? 'Type or select previous email'
                          : 'Email',
                      border: const OutlineInputBorder(),
                      fillColor: roleSelected ? null : Colors.grey[200],
                      filled: !roleSelected,
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                enabled: roleSelected && !isLoading,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  fillColor: roleSelected ? null : Colors.grey[200],
                  filled: !roleSelected,
                ),
              ),
              const SizedBox(height: 32),
              if (isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: CircularProgressIndicator(
                      color: Color.fromARGB(255, 0, 150, 136),
                    ),
                  ),
                ),
              CustomButton(
                text: isLoading ? 'Logging in...' : 'Login',
                color: dashboardGreen,
                onTap: isLoading ? () {} : _handleLogin,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: isLoading
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SignupScreen(),
                          ),
                        );
                      },
                child: const Text("Create new account"),
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }
}