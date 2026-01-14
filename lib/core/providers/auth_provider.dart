import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
          // Fetch user data from Firestore
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
            // User document doesn't exist, create one with default customer role
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
            userRole: 'customer', // Default fallback
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

  // SIMPLIFIED REGISTRATION - Only creates user, role is default 'customer'
  Future<void> registerWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      state = state.copyWith(status: AuthStatus.loading);

      // Create user in Firebase Auth
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      // Create user document in Firestore with default customer role
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

  // Request role upgrade
  Future<void> requestRoleUpgrade({
    required String requestedRole,
    required String userId,
    String? reason,
  }) async {
    try {
      // Create role request document
      await FirebaseFirestore.instance.collection('role_requests').add({
        'userId': userId,
        'requestedRole': requestedRole,
        'status': 'pending',
        'reason': reason,
        'requestedAt': FieldValue.serverTimestamp(),
        'reviewedAt': null,
        'reviewedBy': null,
      });

      // Update user document to show pending verification
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

  // Admin: Approve role change
  Future<void> approveRoleChange({
    required String userId,
    required String newRole,
    required String adminId,
    String? notes,
  }) async {
    try {
      // Update user role
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

      // Update role request status
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

  // Admin: Reject role change
  Future<void> rejectRoleChange({
    required String userId,
    required String adminId,
    String? reason,
  }) async {
    try {
      // Update user document
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'needsVerification': false,
        'requestedRole': null,
        'status': 'active',
        'rejectedBy': adminId,
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectionReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update role request status
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

  // Update current user's role in state
  void updateUserRole(String role) {
    state = state.copyWith(userRole: role);
  }

  // SIMPLIFIED LOGOUT
  Future<void> logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      print("✅ User logged out successfully");
    } catch (e) {
      print("❌ Logout error: $e");
      throw e;
    }
  }

  // Add this method to the AuthProvider class (after the logout method):
  Future<void> signOut() async {
    return logout(); // Just call the existing logout method
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
