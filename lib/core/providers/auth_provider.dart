import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/account_deletion_service.dart';

enum AuthStatus { authenticated, unauthenticated, loading, error }

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? error;
  final String? userRole;
  final bool? needsVerification;

  const AuthState({
    this.status = AuthStatus.unauthenticated,
    this.user,
    this.error,
    this.userRole,
    this.needsVerification = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? error,
    String? userRole,
    bool? needsVerification,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error ?? this.error,
      userRole: userRole ?? this.userRole,
      needsVerification: needsVerification ?? this.needsVerification,
    );
  }
}

class AuthProvider extends StateNotifier<AuthState> {
  AuthProvider() : super(const AuthState()) {
    _initializeAuthListener();
  }

  void _initializeAuthListener() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user == null) {
        state = const AuthState(status: AuthStatus.unauthenticated);
      } else {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

          if (userDoc.exists) {
            final userData = userDoc.data()!;
            final userRole = userData['role'] as String? ?? 'customer';
            final needsVerification =
                userData['needsVerification'] as bool? ?? false;
            final userStatus = userData['status'] as String? ?? 'active';

            state = AuthState(
              status: AuthStatus.authenticated,
              user: user,
              userRole: userRole,
              needsVerification: needsVerification,
            );
          } else {
            await _createUserDocument(user.uid, user.email ?? '');
            state = AuthState(
              status: AuthStatus.authenticated,
              user: user,
              userRole: 'customer',
              needsVerification: false,
            );
          }
        } catch (e) {
          print("❌ Error fetching user data: $e");
          state = AuthState(
            status: AuthStatus.authenticated,
            user: user,
            userRole: 'customer',
            needsVerification: false,
          );
        }
      }
    });
  }

  Future<void> _createUserDocument(String userId, String email) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).set({
      'email': email,
      'role': 'customer',
      'status': 'active',
      'needsVerification': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> registerWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      state = state.copyWith(status: AuthStatus.loading);

      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
            'email': email,
            'role': 'customer',
            'status': 'active',
            'needsVerification': false,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: userCredential.user,
        userRole: 'customer',
        needsVerification: false,
      );
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        error: _getErrorMessage(e.code),
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        error: 'An unexpected error occurred: $e',
      );
    }
  }

  Future<void> requestRoleUpgrade({
    required String requestedRole,
    required String userId,
    String? reason,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('role_requests').add({
        'userId': userId,
        'requestedRole': requestedRole,
        'status': 'pending',
        'reason': reason,
        'requestedAt': FieldValue.serverTimestamp(),
        'reviewedAt': null,
        'reviewedBy': null,
      });

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'needsVerification': true,
        'requestedRole': requestedRole,
        'status': 'pending',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print("✅ Role upgrade requested successfully");
    } catch (e) {
      print("❌ Error requesting role upgrade: $e");
      throw e;
    }
  }

  Future<void> approveRoleChange({
    required String userId,
    required String newRole,
    required String adminId,
    String? notes,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'role': newRole,
        'needsVerification': false,
        'requestedRole': null,
        'status': 'active',
        'approvedBy': adminId,
        'approvedAt': FieldValue.serverTimestamp(),
        'approvalNotes': notes,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final requests = await FirebaseFirestore.instance
          .collection('role_requests')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .get();

      for (var doc in requests.docs) {
        await doc.reference.update({
          'status': 'approved',
          'reviewedAt': FieldValue.serverTimestamp(),
          'reviewedBy': adminId,
          'notes': notes,
        });
      }

      print("✅ Role approved successfully");
    } catch (e) {
      print("❌ Error approving role: $e");
      throw e;
    }
  }

  Future<void> rejectRoleChange({
    required String userId,
    required String adminId,
    String? reason,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'needsVerification': false,
        'requestedRole': null,
        'status': 'active',
        'rejectedBy': adminId,
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectionReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final requests = await FirebaseFirestore.instance
          .collection('role_requests')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .get();

      for (var doc in requests.docs) {
        await doc.reference.update({
          'status': 'rejected',
          'reviewedAt': FieldValue.serverTimestamp(),
          'reviewedBy': adminId,
          'rejectionReason': reason,
        });
      }

      print("✅ Role rejected successfully");
    } catch (e) {
      print("❌ Error rejecting role: $e");
      throw e;
    }
  }

  void updateUserRole(String role) {
    state = state.copyWith(userRole: role);
  }

  Future<void> logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      print("✅ User logged out successfully");
    } catch (e) {
      print("❌ Logout error: $e");
      throw e;
    }
  }

  Future<void> signOut() async {
    return logout();
  }

  /// Permanently deletes the signed-in user's account and all associated data.
  ///
  /// Firestore data is removed first (while the user is still authenticated and
  /// owner security rules apply), then the Firebase Authentication account is
  /// deleted so the user can never sign back in.
  ///
  /// Throws [FirebaseAuthException] with code `requires-recent-login` when the
  /// caller must re-authenticate (see [reauthenticateWithPassword]) before the
  /// auth account can be deleted. The data deletion step is idempotent, so it
  /// is safe to call this method again after re-authenticating.
  Future<void> deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No signed-in user to delete.',
      );
    }

    // 1. Remove all Firestore data owned by the user.
    await AccountDeletionService.deleteUserData(user.uid);

    // 2. Delete the authentication account. May throw requires-recent-login.
    await AccountDeletionService.deleteAuthAccount();

    // authStateChanges() will also fire with null, but update eagerly so the
    // UI reflects the signed-out state immediately.
    state = const AuthState(status: AuthStatus.unauthenticated);
    print("✅ Account deleted successfully");
  }

  /// Re-authenticates the current user with their [password] so that a
  /// `requires-recent-login` error can be resolved before account deletion.
  Future<void> reauthenticateWithPassword(String password) async {
    try {
      await AccountDeletionService.reauthenticateWithPassword(password);
    } on FirebaseAuthException catch (e) {
      throw Exception(_getErrorMessage(e.code));
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
      case 'invalid-credential':
        return 'Incorrect password. Please try again.';
      case 'requires-recent-login':
        return 'Please re-enter your password to continue.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      default:
        return 'An error occurred. Please try again.';
    }
  }
}

final authProvider = StateNotifierProvider<AuthProvider, AuthState>((ref) {
  return AuthProvider();
});
