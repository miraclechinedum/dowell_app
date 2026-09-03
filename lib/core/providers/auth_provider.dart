import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  final Set<String> _claimRefreshAttempted = <String>{};

  void _initializeAuthListener() {
    FirebaseAuth.instance.idTokenChanges().listen((User? user) async {
      if (user == null) {
        _claimRefreshAttempted.clear();
        state = const AuthState(status: AuthStatus.unauthenticated);
      } else {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

          if (userDoc.exists) {
            final userData = userDoc.data()!;
            if (userData['isDeleted'] == true ||
                userData['status'] == 'deleted') {
              await FirebaseAuth.instance.signOut();
              state = const AuthState(status: AuthStatus.unauthenticated);
              return;
            }
            var token = await user.getIdTokenResult();
            var claims = token.claims ?? const <String, dynamic>{};
            final profileRole = userData['role'] as String? ?? 'customer';
            final claimRole = claims['admin'] == true
                ? 'admin'
                : claims['employee'] == true
                ? 'employee'
                : 'customer';
            if (profileRole != claimRole &&
                !_claimRefreshAttempted.contains(user.uid)) {
              _claimRefreshAttempted.add(user.uid);
              token = await user.getIdTokenResult(true);
              claims = token.claims ?? const <String, dynamic>{};
            }
            final userRole = claims['admin'] == true
                ? 'admin'
                : claims['employee'] == true
                ? 'employee'
                : 'customer';
            final needsVerification =
                userData['needsVerification'] as bool? ?? false;
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
          await FirebaseAuth.instance.signOut();
          state = const AuthState(status: AuthStatus.unauthenticated);
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
        'isDeleted': false,
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
    required String requestId,
    String? notes,
  }) async {
    try {
      await FirebaseFunctions.instance.httpsCallable('reviewRoleRequest').call({
        'requestId': requestId,
        'decision': 'approve',
        'notes': notes,
      });

      print("✅ Role approved successfully");
    } catch (e) {
      print("❌ Error approving role: $e");
      throw e;
    }
  }

  Future<void> rejectRoleChange({
    required String requestId,
    String? reason,
  }) async {
    try {
      await FirebaseFunctions.instance.httpsCallable('reviewRoleRequest').call({
        'requestId': requestId,
        'decision': 'reject',
        'notes': reason,
      });

      print("✅ Role rejected successfully");
    } catch (e) {
      print("❌ Error rejecting role: $e");
      throw e;
    }
  }

  Future<void> setUserRole({
    required String userId,
    required String role,
    required String reason,
  }) async {
    await FirebaseFunctions.instance.httpsCallable('setUserRole').call({
      'targetUid': userId,
      'role': role,
      'reason': reason,
    });
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

  Future<void> deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No signed-in user to delete.',
      );
    }

    await AccountDeletionService.deleteMyAccountData();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pending_referral_request_${user.uid}');
    await prefs.remove('pending_referral_fingerprint_${user.uid}');
    await prefs.remove('pending_task_request_${user.uid}');
    await prefs.remove('pending_task_fingerprint_${user.uid}');
    await FirebaseAuth.instance.signOut();

    // authStateChanges() will also fire with null, but update eagerly so the
    // UI reflects the signed-out state immediately.
    state = const AuthState(status: AuthStatus.unauthenticated);
    print("✅ Account deactivated successfully");
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
