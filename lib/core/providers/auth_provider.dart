import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum AuthStatus { authenticated, unauthenticated, loading, error }

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? error;
  final String? userRole;

  const AuthState({
    this.status = AuthStatus.unauthenticated,
    this.user,
    this.error,
    this.userRole,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? error,
    String? userRole,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error ?? this.error,
      userRole: userRole ?? this.userRole,
    );
  }
}

class AuthProvider extends StateNotifier<AuthState> {
  AuthProvider() : super(const AuthState()) {
    // Initialize auth listener
    _initializeAuthListener();
  }

  void _initializeAuthListener() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user == null) {
        state = const AuthState(status: AuthStatus.unauthenticated);
      } else {
        state = AuthState(
          status: AuthStatus.authenticated,
          user: user,
          userRole: 'customer', // Default role, you can customize this
        );
      }
    });
  }

  // Enhanced logout with context for navigation
  Future<void> logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      print("✅ User logged out successfully");

      // Navigate to login screen
      Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      print("❌ Logout error: $e");
      // Even on error, navigate to login
      Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamedAndRemoveUntil('/login', (route) => false);
      throw e;
    }
  }

  // Simple logout without navigation
  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      print("✅ User signed out successfully");
    } catch (e) {
      print("❌ Sign out error: $e");
      throw e;
    }
  }

  Future<void> registerWithEmail({
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      state = state.copyWith(status: AuthStatus.loading);
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        error: _getErrorMessage(e.code),
      );
    }
  }

  Future<void> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      state = state.copyWith(status: AuthStatus.loading);
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        error: _getErrorMessage(e.code),
      );
    }
  }

  Future<void> resetPassword(String email) async {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  String _getErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'weak-password':
        return 'Password is too weak.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This user has been disabled.';
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      default:
        return 'An error occurred. Please try again.';
    }
  }
}

// PROVIDER
final authProvider = StateNotifierProvider<AuthProvider, AuthState>((ref) {
  return AuthProvider();
});
