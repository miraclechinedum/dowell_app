// lib/core/providers/auth_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../models/user_model.dart';
import '../constants/app_constants.dart';
import '../services/analytics_service.dart';

final logger = Logger();

enum AuthStatus { initial, authenticated, unauthenticated, loading, error }

class AuthState {
  final AuthStatus status;
  final AppUser? user;
  final String? error;
  final bool isEmailVerified;
  final bool isLoading;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.error,
    this.isEmailVerified = false,
    this.isLoading = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    AppUser? user,
    String? error,
    bool? isEmailVerified,
    bool? isLoading,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error ?? this.error,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get hasError => error != null;
  UserRole? get userRole => user?.role;
  String? get userId => user?.id;
  bool get needsVerification => user?.needsVerification ?? false;
}

class AuthProvider extends StateNotifier<AuthState> {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final AnalyticsService _analytics;

  late final Stream<User?> _authStateStream;

  AuthProvider({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    AnalyticsService? analytics,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _analytics = analytics ?? AnalyticsService(),
       super(const AuthState()) {
    _initializeAuthListener();
  }

  void _initializeAuthListener() {
    _authStateStream = _firebaseAuth.authStateChanges();

    _authStateStream.listen(
      (User? firebaseUser) async {
        if (firebaseUser == null) {
          _updateStateUnauthenticated();
        } else {
          await _handleAuthenticatedUser(firebaseUser);
        }
      },
      onError: (error) {
        logger.e('Auth state stream error', error: error);
        state = state.copyWith(
          status: AuthStatus.error,
          error: 'Authentication stream error occurred',
        );
      },
    );
  }

  Future<void> _handleAuthenticatedUser(User firebaseUser) async {
    try {
      state = state.copyWith(isLoading: true);

      // Check email verification
      await firebaseUser.reload();
      final isEmailVerified = firebaseUser.emailVerified;

      // Get or create user document
      final appUser = await _getOrCreateUserDocument(firebaseUser);

      // Log authentication event
      _analytics.logLogin(userId: appUser.id, role: appUser.role.value);

      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: appUser,
        isEmailVerified: isEmailVerified,
        isLoading: false,
        error: null,
      );

      logger.i('User authenticated successfully: ${appUser.id}');
    } catch (e, stackTrace) {
      logger.e(
        'Error handling authenticated user',
        error: e,
        stackTrace: stackTrace,
      );
      _updateStateError('Failed to load user data: ${e.toString()}');
    }
  }

  Future<AppUser> _getOrCreateUserDocument(User firebaseUser) async {
    final userRef = _firestore.collection('users').doc(firebaseUser.uid);
    final userDoc = await userRef.get();

    if (userDoc.exists) {
      // Update last login time
      await userRef.update({
        'lastLoginAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return AppUser.fromFirestore(userDoc);
    } else {
      // Create new user document
      final newUser = AppUser.createNew(
        id: firebaseUser.uid,
        email: firebaseUser.email!,
        displayName: firebaseUser.displayName,
        photoUrl: firebaseUser.photoURL,
      );

      await userRef.set(newUser.toFirestore());
      return newUser;
    }
  }

  void _updateStateUnauthenticated() {
    state = const AuthState(status: AuthStatus.unauthenticated);
    logger.i('User unauthenticated');
  }

  void _updateStateError(String error) {
    state = state.copyWith(
      status: AuthStatus.error,
      error: error,
      isLoading: false,
    );
  }

  // ==================== AUTHENTICATION METHODS ====================

  Future<AuthResult> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
    UserRole? selectedRole,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      // Validate inputs
      if (!_isValidEmail(email)) {
        return const AuthResult.error('Invalid email format');
      }

      if (!_isValidPassword(password)) {
        return const AuthResult.error('Password must be at least 6 characters');
      }

      // Create user in Firebase Auth
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final firebaseUser = userCredential.user!;

      // Send email verification
      await firebaseUser.sendEmailVerification();

      // Update display name if provided
      if (displayName != null && displayName.isNotEmpty) {
        await firebaseUser.updateDisplayName(displayName);
        await firebaseUser.reload();
      }

      // Determine role (default to customer if not specified)
      final role = selectedRole ?? UserRole.customer;

      // Create user document in Firestore with selected role
      final appUser = AppUser.createNew(
        id: firebaseUser.uid,
        email: email,
        displayName: displayName ?? email.split('@').first,
        role: role,
        photoUrl: firebaseUser.photoURL,
      );

      await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .set(appUser.toFirestore());

      // Log registration event
      _analytics.logSignUp(method: 'email', role: role.value);

      // Create role verification request if needed
      if (role.requiresVerification) {
        await _createRoleVerificationRequest(
          userId: firebaseUser.uid,
          requestedRole: role.value,
        );
      }

      // Update state
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: appUser,
        isEmailVerified: false,
        isLoading: false,
      );

      logger.i('User registered successfully: ${firebaseUser.uid}');

      return const AuthResult.success(
        'Registration successful! Please verify your email.',
      );
    } on FirebaseAuthException catch (e) {
      logger.w('Firebase auth error during registration', error: e);
      state = state.copyWith(isLoading: false);
      return AuthResult.error(_getFirebaseErrorMessage(e.code));
    } catch (e) {
      logger.e('Unexpected error during registration', error: e);
      state = state.copyWith(isLoading: false);
      return AuthResult.error('An unexpected error occurred: ${e.toString()}');
    }
  }

  Future<AuthResult> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Check if email is verified
      await userCredential.user?.reload();
      final isVerified = userCredential.user?.emailVerified ?? false;

      if (!isVerified) {
        // Option to resend verification email
        await userCredential.user?.sendEmailVerification();
        state = state.copyWith(isLoading: false);
        return const AuthResult.warning(
          'Email not verified. A new verification email has been sent.',
        );
      }

      logger.i('User logged in successfully: ${userCredential.user?.uid}');
      state = state.copyWith(isLoading: false);
      return const AuthResult.success('Login successful!');
    } on FirebaseAuthException catch (e) {
      logger.w('Firebase auth error during login', error: e);
      state = state.copyWith(isLoading: false);
      return AuthResult.error(_getFirebaseErrorMessage(e.code));
    } catch (e) {
      logger.e('Unexpected error during login', error: e);
      state = state.copyWith(isLoading: false);
      return AuthResult.error('An unexpected error occurred: ${e.toString()}');
    }
  }

  Future<void> logout() async {
    try {
      state = state.copyWith(isLoading: true);

      // Log logout event
      if (state.user != null) {
        _analytics.logLogout(userId: state.user!.id);
      }

      await _firebaseAuth.signOut();

      logger.i('User logged out successfully');
    } catch (e) {
      logger.e('Error during logout', error: e);
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  // Alias for logout to maintain compatibility
  Future<void> signOut() async {
    return logout();
  }

  Future<AuthResult> resetPassword(String email) async {
    try {
      state = state.copyWith(isLoading: true);

      // Check if user exists first
      final methods = await _firebaseAuth.fetchSignInMethodsForEmail(email);
      if (methods.isEmpty) {
        state = state.copyWith(isLoading: false);
        return const AuthResult.error('No account found with this email');
      }

      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());

      logger.i('Password reset email sent to: $email');
      state = state.copyWith(isLoading: false);
      return const AuthResult.success(
        'Password reset email sent! Check your inbox.',
      );
    } on FirebaseAuthException catch (e) {
      logger.w('Error sending password reset', error: e);
      state = state.copyWith(isLoading: false);
      return AuthResult.error(_getFirebaseErrorMessage(e.code));
    } catch (e) {
      logger.e('Unexpected error during password reset', error: e);
      state = state.copyWith(isLoading: false);
      return AuthResult.error('Failed to send reset email: ${e.toString()}');
    }
  }

  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      state = state.copyWith(isLoading: true);

      final user = _firebaseAuth.currentUser;
      if (user == null) {
        state = state.copyWith(isLoading: false);
        return const AuthResult.error('No user logged in');
      }

      // Re-authenticate user
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      // Change password
      await user.updatePassword(newPassword);

      logger.i('Password changed successfully for: ${user.email}');
      state = state.copyWith(isLoading: false);
      return const AuthResult.success('Password changed successfully!');
    } on FirebaseAuthException catch (e) {
      logger.w('Error changing password', error: e);
      state = state.copyWith(isLoading: false);

      if (e.code == 'wrong-password') {
        return const AuthResult.error('Current password is incorrect');
      }
      return AuthResult.error(_getFirebaseErrorMessage(e.code));
    } catch (e) {
      logger.e('Unexpected error changing password', error: e);
      state = state.copyWith(isLoading: false);
      return AuthResult.error('Failed to change password: ${e.toString()}');
    }
  }

  Future<AuthResult> requestRoleUpgrade({
    required UserRole requestedRole,
    String? reason,
  }) async {
    try {
      state = state.copyWith(isLoading: true);

      final user = _firebaseAuth.currentUser;
      if (user == null) {
        state = state.copyWith(isLoading: false);
        return const AuthResult.error('No user logged in');
      }

      // Check if already has pending request
      final existingRequest = await _firestore
          .collection('role_requests')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (existingRequest.docs.isNotEmpty) {
        state = state.copyWith(isLoading: false);
        return const AuthResult.warning(
          'You already have a pending role request',
        );
      }

      // Create role request
      await _createRoleVerificationRequest(
        userId: user.uid,
        requestedRole: requestedRole.value,
        reason: reason,
      );

      // Update user document
      await _firestore.collection('users').doc(user.uid).update({
        'needsVerification': true,
        'requestedRole': requestedRole.value,
        'requestStatus': 'pending',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      logger.i('Role upgrade requested: ${user.uid} -> $requestedRole');
      state = state.copyWith(isLoading: false);

      return const AuthResult.success(
        'Role upgrade requested successfully. Admin will review your request.',
      );
    } catch (e) {
      logger.e('Error requesting role upgrade', error: e);
      state = state.copyWith(isLoading: false);
      return AuthResult.error(
        'Failed to request role upgrade: ${e.toString()}',
      );
    }
  }

  Future<void> _createRoleVerificationRequest({
    required String userId,
    required String requestedRole,
    String? reason,
  }) async {
    await _firestore.collection('role_requests').add({
      'userId': userId,
      'requestedRole': requestedRole,
      'status': 'pending',
      'reason': reason,
      'requestedAt': FieldValue.serverTimestamp(),
      'reviewedAt': null,
      'reviewedBy': null,
      'rejectionReason': null,
      'metadata': {'source': 'mobile_app', 'version': AppConstants.appVersion},
    });
  }

  Future<AuthResult> sendEmailVerification() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        return const AuthResult.error('No user logged in');
      }

      await user.sendEmailVerification();

      logger.i('Verification email sent to: ${user.email}');
      return const AuthResult.success('Verification email sent!');
    } catch (e) {
      logger.e('Error sending verification email', error: e);
      return const AuthResult.error('Failed to send verification email');
    }
  }

  Future<bool> checkEmailVerification() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) return false;

      await user.reload();
      final isVerified = user.emailVerified;

      if (isVerified && !state.isEmailVerified) {
        // Update local state
        state = state.copyWith(isEmailVerified: true);

        // Update user document
        await _firestore.collection('users').doc(user.uid).update({
          'emailVerified': true,
          'emailVerifiedAt': FieldValue.serverTimestamp(),
        });
      }

      return isVerified;
    } catch (e) {
      logger.e('Error checking email verification', error: e);
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  bool _isValidPassword(String password) {
    return password.length >= 6;
  }

  String _getFirebaseErrorMessage(String code) {
    switch (code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'invalid-verification-code':
        return 'Invalid verification code.';
      case 'invalid-verification-id':
        return 'Invalid verification ID.';
      default:
        return 'An authentication error occurred. Please try again.';
    }
  }

  Future<List<RoleRequest>> getPendingRoleRequests() async {
    try {
      final snapshot = await _firestore
          .collection('role_requests')
          .where('status', isEqualTo: 'pending')
          .orderBy('requestedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => RoleRequest.fromFirestore(doc))
          .toList();
    } catch (e) {
      logger.e('Error fetching role requests', error: e);
      return [];
    }
  }

  Future<AuthResult> approveRoleRequest({
    required String requestId,
    required String userId,
    required UserRole newRole,
    String? notes,
  }) async {
    try {
      state = state.copyWith(isLoading: true);

      final adminId = _firebaseAuth.currentUser?.uid;
      if (adminId == null) {
        state = state.copyWith(isLoading: false);
        return const AuthResult.error('Admin not authenticated');
      }

      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore.collection('users').doc(userId);
        transaction.update(userRef, {
          'role': newRole.value,
          'needsVerification': false,
          'requestedRole': null,
          'requestStatus': 'approved',
          'approvedBy': adminId,
          'approvedAt': FieldValue.serverTimestamp(),
          'approvalNotes': notes,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final requestRef = _firestore
            .collection('role_requests')
            .doc(requestId);
        transaction.update(requestRef, {
          'status': 'approved',
          'reviewedAt': FieldValue.serverTimestamp(),
          'reviewedBy': adminId,
          'notes': notes,
        });
      });

      logger.i('Role request approved: $requestId for user: $userId');

      if (state.user?.id == userId) {
        final updatedUser = state.user?.copyWith(role: newRole);
        state = state.copyWith(user: updatedUser);
      }

      state = state.copyWith(isLoading: false);
      return const AuthResult.success('Role request approved successfully');
    } catch (e) {
      logger.e('Error approving role request', error: e);
      state = state.copyWith(isLoading: false);
      return AuthResult.error(
        'Failed to approve role request: ${e.toString()}',
      );
    }
  }

  Future<AuthResult> rejectRoleRequest({
    required String requestId,
    required String userId,
    required String reason,
  }) async {
    try {
      state = state.copyWith(isLoading: true);

      final adminId = _firebaseAuth.currentUser?.uid;
      if (adminId == null) {
        state = state.copyWith(isLoading: false);
        return const AuthResult.error('Admin not authenticated');
      }

      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore.collection('users').doc(userId);
        transaction.update(userRef, {
          'needsVerification': false,
          'requestedRole': null,
          'requestStatus': 'rejected',
          'rejectedBy': adminId,
          'rejectedAt': FieldValue.serverTimestamp(),
          'rejectionReason': reason,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final requestRef = _firestore
            .collection('role_requests')
            .doc(requestId);
        transaction.update(requestRef, {
          'status': 'rejected',
          'reviewedAt': FieldValue.serverTimestamp(),
          'reviewedBy': adminId,
          'rejectionReason': reason,
        });
      });

      logger.i('Role request rejected: $requestId for user: $userId');
      state = state.copyWith(isLoading: false);
      return const AuthResult.success('Role request rejected');
    } catch (e) {
      logger.e('Error rejecting role request', error: e);
      state = state.copyWith(isLoading: false);
      return AuthResult.error('Failed to reject role request: ${e.toString()}');
    }
  }
}

class RoleRequest {
  final String id;
  final String userId;
  final String requestedRole;
  final String status;
  final String? reason;
  final DateTime requestedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? rejectionReason;
  final String? notes;

  RoleRequest({
    required this.id,
    required this.userId,
    required this.requestedRole,
    required this.status,
    this.reason,
    required this.requestedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.rejectionReason,
    this.notes,
  });

  factory RoleRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return RoleRequest(
      id: doc.id,
      userId: data['userId'] ?? '',
      requestedRole: data['requestedRole'] ?? '',
      status: data['status'] ?? 'pending',
      reason: data['reason'],
      requestedAt:
          (data['requestedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      reviewedBy: data['reviewedBy'],
      rejectionReason: data['rejectionReason'],
      notes: data['notes'],
    );
  }
}

class AuthResult {
  final bool success;
  final String? message;
  final String? error;
  final AuthResultType type;

  const AuthResult.success(this.message)
    : success = true,
      error = null,
      type = AuthResultType.success;

  const AuthResult.error(this.error)
    : success = false,
      message = null,
      type = AuthResultType.error;

  const AuthResult.warning(this.message)
    : success = true,
      error = null,
      type = AuthResultType.warning;

  bool get isSuccess => success && type != AuthResultType.warning;
  bool get isWarning => type == AuthResultType.warning;
  bool get isError => !success;
}

enum AuthResultType { success, warning, error }

final authProvider = StateNotifierProvider<AuthProvider, AuthState>((ref) {
  return AuthProvider();
});

final authStateProvider = Provider<AuthState>((ref) {
  return ref.watch(authProvider);
});

final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authProvider).user;
});

final isAdminProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.isAdmin ?? false;
});

final isEmployeeProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.isEmployee ?? false;
});
