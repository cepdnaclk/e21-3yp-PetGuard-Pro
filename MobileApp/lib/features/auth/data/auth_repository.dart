import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign in and return user UID (non-Firebase type)
  Future<String> signInWithEmailAndPassword(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
    return credential.user!.uid;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<String> createUserWithEmailAndPassword(String email, String password) async {
    final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    await credential.user?.sendEmailVerification();
    return credential.user!.uid;
  }

  Future<void> createUserDocument({
    required String uid,
    required String fullName,
    required String email,
    required String phone,
  }) async {
    await _firestore.collection("users").doc(uid).set({
      "name": fullName,
      "email": email,
      "phone": phone,
      "status": "not_varified",
      "role": "user",
      "selectedPetId": null,
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  // Get admin document and return as Map (non-Firebase type)
  Future<Map<String, dynamic>?> getAdminDocument(String uid) async {
    final doc = await _firestore.collection('admins').doc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  // Get user document and return as Map (non-Firebase type)
  Future<Map<String, dynamic>?> getUserDocument(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  // ─── Determine user role and return status ─────────────────────────────────
  /// Checks if user is admin or regular user after login.
  /// Returns: 'admin', 'pending', 'inactive', 'active', or 'not_found'
  Future<String> determineUserRole(String uid) async {
    // Check admin first
    final adminDoc = await getAdminDocument(uid);
    if (adminDoc != null) {
      return 'admin';
    }

    // Check user
    final userDoc = await getUserDocument(uid);
    if (userDoc == null) {
      return 'not_found';
    }

    final status = (userDoc['status'] as String? ?? '').toLowerCase().trim();
    if (status == 'pending') {
      return 'pending';
    } else if (status == 'inactive') {
      return 'inactive';
    } else if (status == 'blocked') {
      return 'blocked';
    } else if (status == 'not_varified') {
      return 'not_varified';
    } else if (status == 'active' || status == 'approved') {
      return 'active';
    } else {
      return 'active';
    }
  }

  // ─── SharedPreferences helpers ─────────────────────────────────────────────
  /// Load saved emails and last used email from preferences
  Future<({List<String> savedEmails, String lastUsedEmail})> loadSavedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmails = prefs.getStringList('savedEmails') ?? [];
    final lastUsedEmail = prefs.getString('lastUsedEmail') ?? '';
    return (savedEmails: savedEmails, lastUsedEmail: lastUsedEmail);
  }

  /// Save email to preferences
  Future<void> saveEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();

    final savedEmails = prefs.getStringList('savedEmails') ?? [];
    if (!savedEmails.contains(email)) {
      savedEmails.add(email);
    }

    await prefs.setStringList('savedEmails', savedEmails);
    await prefs.setString('lastUsedEmail', email);
  }

  // ─── Validation helpers ───────────────────────────────────────────────────
  /// Validates signup form fields
  /// Returns null if valid, otherwise returns error message
  String? validateSignupFields({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String confirmPassword,
  }) {
    if (fullName.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      return "Please fill in all fields.";
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      return "Please enter a valid email address.";
    }
    if (password.length < 8) {
      return "Password must be at least 8 characters.";
    }
    if (password != confirmPassword) {
      return "Passwords do not match.";
    }
    return null;
  }

  /// Validates login form fields
  /// Returns null if valid, otherwise returns error message
  String? validateLoginFields(String email, String password) {
    if (email.isEmpty || password.isEmpty) {
      return 'Please enter email and password';
    }
    return null;
  }

  /// Maps Firebase error to user-friendly error message (for login)
  String mapLoginError(Object error) {
    String msg = 'Login failed';
    if (error is Exception) {
      final errorStr = error.toString();
      if (errorStr.contains('empty-fields')) {
        msg = 'Please enter email and password';
      } else if (errorStr.contains('user-not-found')) {
        msg = 'No account found for this email';
      } else if (errorStr.contains('wrong-password')) {
        msg = 'Wrong password';
      } else if (errorStr.contains('invalid-email')) {
        msg = 'Invalid email';
      } else if (errorStr.contains('invalid-credential')) {
        msg = 'Invalid email or password';
      } else if (errorStr.contains('too-many-requests')) {
        msg = 'Too many attempts. Try again later';
      } else if (errorStr.contains('Please enter email and password')) {
        msg = 'Please enter email and password';
      }
    }
    return msg;
  }

  /// Maps Firebase error to user-friendly error message (for signup)
  String mapSignupError(Object error) {
    String errorMessage = "Sign up failed";
    final errorStr = error.toString();
    if (errorStr.contains('email-already-in-use')) {
      errorMessage = "This email is already registered.";
    } else if (errorStr.contains('invalid-email')) {
      errorMessage = "The email address is not valid.";
    } else if (errorStr.contains('weak-password')) {
      errorMessage = "Password must be at least 8 characters.";
    }
    return errorMessage;
  }

  // ─── Complete login flow orchestration ──────────────────────────────────────
  /// Handles complete login flow: validation → signin → role determination → email save
  /// Returns LoginResult with userRole ('admin' or 'user') for navigation, or errorMessage for UI
  Future<LoginResult> handleLogin(String email, String password) async {
    // 1. Validate input
    final validationError = validateLoginFields(email, password);
    if (validationError != null) {
      return LoginResult(errorMessage: validationError);
    }

    try {
      // 2. Sign in and get UID
      final uid = await signInWithEmailAndPassword(email, password);

      // Reload user from Firebase to get the latest emailVerified status
      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        await firebaseUser.reload();
      }

      // Check user document status
      final userDoc = await getUserDocument(uid);
      if (userDoc != null) {
        final status = userDoc['status'] as String? ?? '';
        if (status == 'not_varified') {
          final reloadedUser = _auth.currentUser;
          if (reloadedUser != null && reloadedUser.emailVerified) {
            // User clicked the email verification link! Update status to 'Inactive' in Firestore
            await _firestore.collection('users').doc(uid).update({'status': 'Inactive'});
            await signOut();
            return LoginResult(errorMessage: 'Email verified. Please wait for admin approval.');
          } else {
            // User has not verified their email address yet
            await signOut();
            return LoginResult(errorMessage: 'Please verify your email first. A verification link has been sent to your email.');
          }
        }
      }

      // 3. Determine user role/status
      final userRole = await determineUserRole(uid);

      // 4. Handle different role statuses
      if (userRole == 'admin') {
        await saveEmail(email);
        return LoginResult(userRole: 'admin', shouldNavigate: true);
      }

      if (userRole == 'not_found') {
        await signOut();
        return LoginResult(errorMessage: 'No account found');
      }

      if (userRole == 'pending') {
        await signOut();
        return LoginResult(errorMessage: 'Account waiting for approval');
      }

      if (userRole == 'inactive') {
        await signOut();
        return LoginResult(errorMessage: 'Account waiting for admin approval');
      }

      if (userRole == 'blocked') {
        await signOut();
        return LoginResult(errorMessage: 'Account blocked');
      }

      if (userRole == 'not_varified') {
        await signOut();
        return LoginResult(errorMessage: 'Please verify your email first.');
      }

      // userRole == 'active' → proceed to user dashboard
      await saveEmail(email);
      return LoginResult(userRole: 'user', shouldNavigate: true);
    } catch (e) {
      final errorMsg = mapLoginError(e);
      return LoginResult(errorMessage: errorMsg);
    }
  }
}

// ─── Login Result class ────────────────────────────────────────────────────────
class LoginResult {
  final String? userRole; // 'admin', 'user', or null if error
  final String? errorMessage; // error message to display to user
  final bool shouldNavigate; // true if login successful and should navigate

  LoginResult({
    this.userRole,
    this.errorMessage,
    this.shouldNavigate = false,
  });
}
