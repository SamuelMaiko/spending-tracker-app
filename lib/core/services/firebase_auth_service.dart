import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:developer' as developer;

import 'user_preferences_service.dart';

/// Service for handling Firebase Authentication
class FirebaseAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  /// Get current user
  static User? get currentUser => _auth.currentUser;

  /// Get current user UID
  static String? get currentUserUid => _auth.currentUser?.uid;

  /// Check if user is signed in
  static bool get isSignedIn => _auth.currentUser != null;

  /// Stream of authentication state changes
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with email and password
  static Future<UserCredential?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      developer.log('🔐 Attempting to sign in with email: $email');

      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      developer.log('✅ Successfully signed in: ${credential.user?.uid}');
      return credential;
    } on FirebaseAuthException catch (e) {
      developer.log('❌ Firebase Auth Error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      developer.log('❌ Unexpected error during sign in: $e');
      rethrow;
    }
  }

  /// Create account with email and password
  static Future<UserCredential?> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      developer.log('📝 Attempting to create account with email: $email');

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      developer.log('✅ Successfully created account: ${credential.user?.uid}');
      return credential;
    } on FirebaseAuthException catch (e) {
      developer.log('❌ Firebase Auth Error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      developer.log('❌ Unexpected error during account creation: $e');
      rethrow;
    }
  }

  /// Sign in with Google
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      developer.log('🔐 Attempting to sign in with Google');

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        developer.log('❌ Google sign in was cancelled by user');
        return null;
      }

      developer.log('✅ Google account selected: ${googleUser.email}');

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      developer.log('✅ Google authentication obtained');

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      developer.log('✅ Firebase credential created');

      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);

      developer.log('✅ Firebase sign in completed');

      // Store user information locally
      if (userCredential.user != null) {
        final user = userCredential.user!;
        await UserPreferencesService.setUserName(user.displayName ?? '');
        await UserPreferencesService.setUserEmail(user.email ?? '');
        developer.log('✅ Successfully signed in with Google: ${user.uid}');
        developer.log('👤 User name: ${user.displayName}');
        developer.log('📧 User email: ${user.email}');
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      developer.log('❌ Firebase Auth Error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      developer.log('❌ Unexpected error during Google sign in: $e');
      rethrow;
    }
  }

  /// Sign out
  static Future<void> signOut() async {
    try {
      developer.log('🚪 Signing out user: ${_auth.currentUser?.uid}');

      // Sign out from Firebase
      await _auth.signOut();

      // Sign out from Google
      await _googleSignIn.signOut();

      // Clear local user data
      await UserPreferencesService.clearUserData();

      developer.log('✅ Successfully signed out');
    } catch (e) {
      developer.log('❌ Error during sign out: $e');
      rethrow;
    }
  }

  /// Disconnect Google account (revokes access)
  static Future<void> disconnect() async {
    try {
      developer.log('🔐 Disconnecting Google account');

      // Disconnect from Google Sign-In (revokes access)
      await _googleSignIn.disconnect();

      // Sign out from Firebase
      await _auth.signOut();

      // Clear local user data
      await UserPreferencesService.clearUserData();

      developer.log('✅ Successfully disconnected');
    } catch (e) {
      developer.log('❌ Error during disconnect: $e');
      rethrow;
    }
  }

  /// Send password reset email
  static Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      developer.log('📧 Sending password reset email to: $email');
      await _auth.sendPasswordResetEmail(email: email);
      developer.log('✅ Password reset email sent');
    } on FirebaseAuthException catch (e) {
      developer.log('❌ Firebase Auth Error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      developer.log('❌ Unexpected error sending password reset: $e');
      rethrow;
    }
  }

  /// Get user-friendly error message from FirebaseAuthException
  static String getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'weak-password':
        return 'Password is too weak. Please choose a stronger password.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return e.message ?? 'An unexpected error occurred.';
    }
  }
}
