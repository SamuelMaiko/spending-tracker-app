import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;

import '../../../../core/services/firebase_auth_service.dart';
import '../../../../core/services/sync_settings_service.dart';
import '../../../../core/services/data_sync_service.dart';
import '../../../../dependency_injector.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// BLoC for managing authentication state
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  late final StreamSubscription<User?> _authStateSubscription;

  AuthBloc() : super(const AuthInitial()) {
    // Listen to authentication state changes
    _authStateSubscription = FirebaseAuthService.authStateChanges.listen(
      (user) => add(AuthStateChanged(userId: user?.uid)),
    );

    // Register event handlers
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthSignInRequested>(_onAuthSignInRequested);
    on<AuthSignUpRequested>(_onAuthSignUpRequested);
    on<AuthGoogleSignInRequested>(_onGoogleSignInRequested);
    on<AuthSignOutRequested>(_onAuthSignOutRequested);
    on<AuthPasswordResetRequested>(_onAuthPasswordResetRequested);
    on<AuthStateChanged>(_onAuthStateChanged);
  }

  /// Handle authentication check
  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    developer.log('🔍 Checking authentication status');

    final user = FirebaseAuthService.currentUser;
    if (user != null) {
      developer.log('✅ User is authenticated: ${user.uid}');
      emit(AuthAuthenticated(userId: user.uid, email: user.email));
    } else {
      developer.log('❌ User is not authenticated');
      emit(const AuthUnauthenticated());
    }
  }

  /// Handle sign in request
  Future<void> _onAuthSignInRequested(
    AuthSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      final credential = await FirebaseAuthService.signInWithEmailAndPassword(
        email: event.email,
        password: event.password,
      );

      if (credential?.user != null) {
        emit(
          AuthAuthenticated(
            userId: credential!.user!.uid,
            email: credential.user!.email,
          ),
        );

        // Initialize sync settings and perform initial sync
        _initializeSyncOnSignIn();
      }
    } on FirebaseAuthException catch (e) {
      emit(AuthError(message: FirebaseAuthService.getErrorMessage(e)));
    } catch (e) {
      emit(AuthError(message: 'An unexpected error occurred: $e'));
    }
  }

  /// Handle sign up request
  Future<void> _onAuthSignUpRequested(
    AuthSignUpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      final credential =
          await FirebaseAuthService.createUserWithEmailAndPassword(
            email: event.email,
            password: event.password,
          );

      if (credential?.user != null) {
        emit(
          AuthAuthenticated(
            userId: credential!.user!.uid,
            email: credential.user!.email,
          ),
        );

        // Initialize sync settings and perform initial sync
        _initializeSyncOnSignIn();
      }
    } on FirebaseAuthException catch (e) {
      emit(AuthError(message: FirebaseAuthService.getErrorMessage(e)));
    } catch (e) {
      emit(AuthError(message: 'An unexpected error occurred: $e'));
    }
  }

  /// Handle Google Sign-In request
  Future<void> _onGoogleSignInRequested(
    AuthGoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      developer.log('🔐 Attempting Google Sign-In');

      final credential = await FirebaseAuthService.signInWithGoogle();

      if (credential?.user != null) {
        emit(
          AuthAuthenticated(
            userId: credential!.user!.uid,
            email: credential.user!.email,
          ),
        );

        // Initialize sync settings and perform initial sync
        _initializeSyncOnSignIn();

        developer.log('✅ Google Sign-In successful');
      } else {
        emit(const AuthUnauthenticated());
        developer.log('❌ Google Sign-In was cancelled');
      }
    } on FirebaseAuthException catch (e) {
      emit(AuthError(message: FirebaseAuthService.getErrorMessage(e)));
    } catch (e) {
      emit(AuthError(message: 'Google Sign-In failed: $e'));
    }
  }

  /// Handle sign out request
  Future<void> _onAuthSignOutRequested(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      // Clear sync settings before signing out
      await SyncSettingsService.clearSyncSettings();
      await FirebaseAuthService.signOut();
      emit(const AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(message: 'Failed to sign out: $e'));
    }
  }

  /// Handle password reset request
  Future<void> _onAuthPasswordResetRequested(
    AuthPasswordResetRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      await FirebaseAuthService.sendPasswordResetEmail(email: event.email);
      emit(AuthPasswordResetSent(email: event.email));
    } on FirebaseAuthException catch (e) {
      emit(AuthError(message: FirebaseAuthService.getErrorMessage(e)));
    } catch (e) {
      emit(AuthError(message: 'Failed to send password reset email: $e'));
    }
  }

  /// Handle authentication state changes
  void _onAuthStateChanged(AuthStateChanged event, Emitter<AuthState> emit) {
    if (event.userId != null) {
      final user = FirebaseAuthService.currentUser;
      emit(AuthAuthenticated(userId: event.userId!, email: user?.email));
    } else {
      emit(const AuthUnauthenticated());
    }
  }

  /// Initialize sync settings and perform initial sync on sign in
  void _initializeSyncOnSignIn() async {
    try {
      developer.log('🔧 Initializing sync on sign in');

      // Initialize sync settings
      await SyncSettingsService.initializeSyncSettings();

      // Enable sync by default for new sign-ins
      await SyncSettingsService.setSyncEnabled(true);

      // Perform initial sync
      final syncService = sl<DataSyncService>();
      await syncService.performInitialSync();

      developer.log('✅ Sync initialization completed');
    } catch (e) {
      developer.log('❌ Error initializing sync: $e');
      // Don't throw error - authentication should still succeed
    }
  }

  @override
  Future<void> close() {
    _authStateSubscription.cancel();
    return super.close();
  }
}
