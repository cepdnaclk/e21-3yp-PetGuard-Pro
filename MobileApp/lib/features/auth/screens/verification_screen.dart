import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VerificationScreen extends StatefulWidget {
  final String email;
  const VerificationScreen({super.key, required this.email});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _timer;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    // Start verification check polling every 3 seconds
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _checkEmailVerified());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkEmailVerified() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.reload();
      final updatedUser = _auth.currentUser;
      if (updatedUser != null && updatedUser.emailVerified) {
        _timer?.cancel();
        // Update Firestore status to 'Inactive'
        await _firestore.collection('users').doc(updatedUser.uid).update({
          'status': 'Inactive',
        });
        // Sign out user
        await _auth.signOut();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Email verified successfully! Please wait for Admin approval."),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    setState(() => _isResending = true);
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.sendEmailVerification();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Verification email resent successfully!"),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${e.toString()}"),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  Future<void> _cancelVerification() async {
    _timer?.cancel();
    await _auth.signOut();
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color.fromARGB(255, 0, 150, 136);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Verify Email"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 1,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.mark_email_unread_outlined,
                size: 80,
                color: primaryColor,
              ),
              const SizedBox(height: 24),
              Text(
                "Verify your email address",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                "We have sent a verification link to:\n${widget.email}",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Please click the link in the email to verify your account. Once verified, this screen will automatically transition and notify you.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 40),
              const Center(
                child: CircularProgressIndicator(
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 40),
              _isResending
                  ? const Center(child: CircularProgressIndicator(color: primaryColor))
                  : ElevatedButton(
                      onPressed: _resendVerificationEmail,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Resend Verification Email",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _cancelVerification,
                child: const Text(
                  "Cancel and back to login",
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
