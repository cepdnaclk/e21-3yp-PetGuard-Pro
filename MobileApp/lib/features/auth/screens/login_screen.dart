import 'package:flutter/material.dart';
import '../data/auth_repository.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/custom_button.dart';
import '../../admin/screens/admin_dashboard_screen.dart';
import '../../owner/screens/user_dashboard_screen.dart';
import '../../owner/activity/services/activity_notification_service.dart';
import '../../owner/location/providers/location_provider.dart';
import 'signup_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool isLoading = false;
  List<String> savedEmails = [];

  final AuthRepository _authRepository = AuthRepository();

  @override
  void initState() {
    super.initState();
    _loadSavedEmails();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // Load saved emails from repository
  Future<void> _loadSavedEmails() async {
    final prefs = await _authRepository.loadSavedPreferences();
    if (!mounted) return;
    setState(() {
      savedEmails = prefs.savedEmails;
      emailController.text = prefs.lastUsedEmail;
    });
  }

  Future<void> _login() async {
    setState(() => isLoading = true);

    try {
      final email = emailController.text.trim();
      final password = passwordController.text.trim();

      // ── COMPLETE LOGIN FLOW IN REPOSITORY ──────────────────────────
      final result = await _authRepository.handleLogin(email, password);

      if (!mounted) return;

      // Handle error case
      if (result.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.errorMessage!)),
        );
        return;
      }

      // Navigate based on user role
      if (result.shouldNavigate && result.userRole == 'admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
        );
        return;
      }

      if (result.shouldNavigate && result.userRole == 'user') {
        // ── REFRESH ALL LISTENERS FOR NEW ACCOUNT ────────
        ref.invalidate(locationPetIdProvider);
        await ActivityNotificationService().refreshPetListener();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const UserDashboardScreen()),
        );
        return;
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _handleLogin() {
    _login();
  }

  void _showForgotPasswordDialog() {
    final TextEditingController resetEmailController = TextEditingController(text: emailController.text);
    const dashboardGreen = Color.fromARGB(255, 0, 150, 136);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Enter your registered email address to receive a password reset link:'),
              const SizedBox(height: 16),
              TextField(
                controller: resetEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(),
                  hintText: 'email@example.com',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = resetEmailController.text.trim();
                if (email.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter your email address')),
                  );
                  return;
                }

                final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                if (!emailRegex.hasMatch(email)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid email address')),
                  );
                  return;
                }

                Navigator.pop(context);
                setState(() => isLoading = true);

                try {
                  await _authRepository.sendPasswordResetEmail(email);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password reset link sent! Check your inbox.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  String msg = 'Failed to send reset link';
                  final errStr = e.toString();
                  if (errStr.contains('user-not-found')) {
                    msg = 'No account found for this email';
                  } else if (errStr.contains('invalid-email')) {
                    msg = 'Invalid email address';
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(msg),
                      backgroundColor: Colors.red,
                    ),
                  );
                } finally {
                  if (mounted) {
                    setState(() => isLoading = false);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: dashboardGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('Send Link'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const dashboardGreen = Color.fromARGB(255, 0, 150, 136);
    final colorScheme = Theme.of(context).colorScheme;

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
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Login to continue',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
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
                    enabled: !isLoading,
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
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                enabled: !isLoading,
                obscureText: !_isPasswordVisible,
                keyboardType: TextInputType.visiblePassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _handleLogin(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: isLoading ? null : _showForgotPasswordDialog,
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      color: dashboardGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
