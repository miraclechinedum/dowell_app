// lib/core/providers/auth_provider.dart
import 'dart:async';
import 'dart:math';
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
  final UserModel? user;
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
    UserModel? user,
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

  // needsVerification: non-customer roles that aren't approved yet
  bool get needsVerification =>
      user != null &&
      user!.role != UserRole.customer &&
      user!.role != UserRole.admin &&
      !user!.isApproved;
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

      await firebaseUser.reload();
      final isEmailVerified = firebaseUser.emailVerified;

      // Add timeout to prevent indefinite hanging on Firestore
      final userModel = await _getOrCreateUserDocument(firebaseUser).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('User data fetch timed out'),
      );

      _analytics.logLogin(userId: userModel.id, role: userModel.role.name);

      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: userModel,
        isEmailVerified: isEmailVerified,
        isLoading: false,
        error: null,
      );

      logger.i('User authenticated successfully: ${userModel.id}');
    } catch (e, stackTrace) {
      logger.e(
        'Error handling authenticated user',
        error: e,
        stackTrace: stackTrace,
      );

      // Provide more helpful error messages
      String errorMsg = 'Failed to load user data';
      if (e is TimeoutException) {
        errorMsg = 'Connection timeout. Check your internet and try again.';
      } else if (e.toString().contains('permission-denied')) {
        errorMsg = 'Access denied. Please contact support.';
      }

      _updateStateError(errorMsg);
    }
  }

  Future<UserModel> _getOrCreateUserDocument(User firebaseUser) async {
    final userRef = _firestore.collection('users').doc(firebaseUser.uid);
    final userDoc = await userRef.get();

    if (userDoc.exists) {
      await userRef.update({
        'lastLoginAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return UserModel.fromMap(
        userDoc.data() as Map<String, dynamic>,
        userDoc.id,
      );
    } else {
      final newUser = UserModel(
        id: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        fullName:
            firebaseUser.displayName ??
            firebaseUser.email?.split('@').first ??
            '',
        phoneNumber: '',
        role: UserRole.customer,
        isApproved: true,
        createdAt: DateTime.now(),
        walletBalance: 0.0,
        referralCode: _generateReferralCode(
          firebaseUser.displayName ??
              firebaseUser.email?.split('@').first ??
              'U',
        ),
      );

      await userRef.set({
        ...newUser.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      return newUser;
    }
  }

  void _updateStateUnauthenticated() {
    state = const AuthState(status: AuthStatus.unauthenticated);
    logger.i('User unauthenticated');
  }

  void _updateStateError(String message) {
    state = state.copyWith(
      status: AuthStatus.error,
      error: message,
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

      if (!_isValidEmail(email)) {
        state = state.copyWith(isLoading: false);
        return const AuthResult.error('Please enter a valid email address.');
      }

      if (!_isValidPassword(password)) {
        state = state.copyWith(isLoading: false);
        return const AuthResult.error(
          'Password must be at least 6 characters.',
        );
      }

      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final firebaseUser = userCredential.user!;

      await firebaseUser.sendEmailVerification();

      if (displayName != null && displayName.isNotEmpty) {
        await firebaseUser.updateDisplayName(displayName);
        await firebaseUser.reload();
      }

      final role = selectedRole ?? UserRole.customer;
      final name = displayName ?? email.split('@').first;
      final isApproved = role == UserRole.customer || role == UserRole.admin;

      final newUser = UserModel(
        id: firebaseUser.uid,
        email: email.trim(),
        fullName: name,
        phoneNumber: '',
        role: role,
        isApproved: isApproved,
        createdAt: DateTime.now(),
        walletBalance: 0.0,
        referralCode: _generateReferralCode(name),
      );

      await _firestore.collection('users').doc(firebaseUser.uid).set({
        ...newUser.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      _analytics.logSignUp(method: 'email', role: role.name);

      if (role == UserRole.employee || role == UserRole.athlete) {
        await _createRoleVerificationRequest(
          userId: firebaseUser.uid,
          requestedRole: role.name,
        );
      }

      // Sign out immediately after registration.
      // The user must verify their email then log in manually.
      // AuthWrapper will see unauthenticated state and show LoginScreen.
      await _firebaseAuth.signOut();

      state = const AuthState(status: AuthStatus.unauthenticated);

      logger.i('User registered successfully: ${firebaseUser.uid}');
      return const AuthResult.success(
        'Registration successful! Please verify your email, then sign in.',
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

      await userCredential.user?.reload();
      final isVerified = userCredential.user?.emailVerified ?? false;

      if (!isVerified) {
        // Resend verification link then sign back out immediately.
        // This stops Firebase authStateChanges from routing the user into
        // the app and ensures AuthWrapper stays on LoginScreen.
        await userCredential.user?.sendEmailVerification();
        await _firebaseAuth.signOut();
        final msg =
            "Your email address hasn't been verified yet. "
            'We just re-sent a verification link to ${email.trim()} — '
            'please check your inbox (and spam folder), tap the link, '
            'then come back and sign in.';
        state = state.copyWith(isLoading: false, error: msg);
        return AuthResult.error(msg);
      }

      logger.i('User logged in successfully: ${userCredential.user?.uid}');
      state = state.copyWith(isLoading: false);
      return const AuthResult.success('Login successful!');
    } on FirebaseAuthException catch (e) {
      logger.w('Firebase auth error during login', error: e);
      final message = _getFirebaseErrorMessage(e.code);
      state = state.copyWith(isLoading: false, error: message);
      return AuthResult.error(message);
    } catch (e) {
      logger.e('Unexpected error during login', error: e);
      final message = 'An unexpected error occurred. Please try again.';
      state = state.copyWith(isLoading: false, error: message);
      return AuthResult.error(message);
    }
  }

  Future<void> logout() async {
    try {
      state = state.copyWith(isLoading: true);
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

  Future<void> signOut() async => logout();

  Future<AuthResult> resetPassword(String email) async {
    try {
      state = state.copyWith(isLoading: true);

      if (!_isValidEmail(email.trim())) {
        state = state.copyWith(isLoading: false);
        return const AuthResult.error('Please enter a valid email address.');
      }

      final methods = await _firebaseAuth.fetchSignInMethodsForEmail(
        email.trim(),
      );
      if (methods.isEmpty) {
        state = state.copyWith(isLoading: false);
        return const AuthResult.error(
          'No account found with this email address.',
        );
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
      return AuthResult.error('Failed to send reset email. Please try again.');
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
        return const AuthResult.error('No user is currently signed in.');
      }

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);

      logger.i('Password changed successfully for: ${user.email}');
      state = state.copyWith(isLoading: false);
      return const AuthResult.success('Password changed successfully!');
    } on FirebaseAuthException catch (e) {
      logger.w('Error changing password', error: e);
      state = state.copyWith(isLoading: false);
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return const AuthResult.error(
          'Your current password is incorrect. Please try again.',
        );
      }
      return AuthResult.error(_getFirebaseErrorMessage(e.code));
    } catch (e) {
      logger.e('Unexpected error changing password', error: e);
      state = state.copyWith(isLoading: false);
      return AuthResult.error('Failed to change password. Please try again.');
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
        return const AuthResult.error('No user is currently signed in.');
      }

      final existingRequest = await _firestore
          .collection('role_requests')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (existingRequest.docs.isNotEmpty) {
        state = state.copyWith(isLoading: false);
        return const AuthResult.warning(
          'You already have a pending role request. Please wait for admin review.',
        );
      }

      await _createRoleVerificationRequest(
        userId: user.uid,
        requestedRole: requestedRole.name,
        reason: reason,
      );

      await _firestore.collection('users').doc(user.uid).update({
        'requestedRole': requestedRole.name,
        'requestStatus': 'pending',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      logger.i('Role upgrade requested: ${user.uid} -> ${requestedRole.name}');
      state = state.copyWith(isLoading: false);

      return const AuthResult.success(
        'Role upgrade requested successfully. An admin will review your request.',
      );
    } catch (e) {
      logger.e('Error requesting role upgrade', error: e);
      state = state.copyWith(isLoading: false);
      return AuthResult.error(
        'Failed to request role upgrade. Please try again.',
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
        return const AuthResult.error('No user is currently signed in.');
      }
      await user.sendEmailVerification();
      logger.i('Verification email sent to: ${user.email}');
      return const AuthResult.success(
        'Verification email sent! Please check your inbox.',
      );
    } catch (e) {
      logger.e('Error sending verification email', error: e);
      return const AuthResult.error(
        'Failed to send verification email. Please try again.',
      );
    }
  }

  Future<bool> checkEmailVerification() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) return false;

      await user.reload();
      final isVerified = user.emailVerified;

      if (isVerified && !state.isEmailVerified) {
        state = state.copyWith(isEmailVerified: true);
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

  /// Re-fetches the user document from Firestore and updates state.
  Future<void> reloadUser() async {
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        state = state.copyWith(user: UserModel.fromMap(doc.data()!, doc.id));
      }
    } catch (e) {
      logger.e('Error reloading user', error: e);
    }
  }

  void refreshUser(UserModel updatedUser) {
    state = state.copyWith(user: updatedUser);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  // ==================== ADMIN METHODS ====================

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
        return const AuthResult.error('Admin is not authenticated.');
      }

      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore.collection('users').doc(userId);
        transaction.update(userRef, {
          'role': newRole.name,
          'isApproved': true,
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
        state = state.copyWith(
          user: state.user?.copyWith(role: newRole, isApproved: true),
        );
      }

      state = state.copyWith(isLoading: false);
      return const AuthResult.success('Role request approved successfully.');
    } catch (e) {
      logger.e('Error approving role request', error: e);
      state = state.copyWith(isLoading: false);
      return AuthResult.error(
        'Failed to approve role request. Please try again.',
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
        return const AuthResult.error('Admin is not authenticated.');
      }

      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore.collection('users').doc(userId);
        transaction.update(userRef, {
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
      return const AuthResult.success('Role request rejected.');
    } catch (e) {
      logger.e('Error rejecting role request', error: e);
      state = state.copyWith(isLoading: false);
      return AuthResult.error(
        'Failed to reject role request. Please try again.',
      );
    }
  }

  // ==================== HELPERS ====================

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  bool _isValidPassword(String password) {
    return password.length >= 6;
  }

  String _generateReferralCode(String name) {
    final initials = name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase())
        .join();
    final suffix = (1000 + Random().nextInt(8999)).toString();
    return '$initials$suffix';
  }

  String _getFirebaseErrorMessage(String code) {
    switch (code) {
      // ── Credential errors ──────────────────────────────────────────────
      case 'invalid-credential':
      case 'invalid-email-or-password':
        return 'Incorrect email or password. Please check your details and try again.';
      case 'wrong-password':
        return 'Incorrect password. Please try again or reset your password.';
      case 'user-not-found':
        return 'No account found with this email address.';

      // ── Account errors ─────────────────────────────────────────────────
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email using a different sign-in method.';

      // ── Input errors ───────────────────────────────────────────────────
      case 'invalid-email':
        return 'The email address format is not valid.';
      case 'weak-password':
        return 'Password is too weak. Please use at least 6 characters.';

      // ── Session errors ─────────────────────────────────────────────────
      case 'requires-recent-login':
        return 'Please sign out and sign back in to perform this action.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please wait a moment before trying again.';

      // ── Network errors ─────────────────────────────────────────────────
      case 'network-request-failed':
        return 'Network error. Please check your internet connection and try again.';

      // ── Verification errors ────────────────────────────────────────────
      case 'invalid-verification-code':
        return 'Invalid verification code. Please try again.';
      case 'invalid-verification-id':
        return 'Invalid verification ID. Please restart the process.';
      case 'expired-action-code':
        return 'This link has expired. Please request a new one.';
      case 'invalid-action-code':
        return 'This link is invalid or has already been used.';

      // ── Fallback ───────────────────────────────────────────────────────
      default:
        return 'An authentication error occurred. Please try again.';
    }
  }
}

// ─── RoleRequest ─────────────────────────────────────────────────────────────

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

// ─── AuthResult ───────────────────────────────────────────────────────────────

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

// ─── Providers ───────────────────────────────────────────────────────────────

final authProvider = StateNotifierProvider<AuthProvider, AuthState>((ref) {
  return AuthProvider();
});

final authStateProvider = Provider<AuthState>((ref) {
  return ref.watch(authProvider);
});

final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authProvider).user;
});

final isAdminProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.role == UserRole.admin;
});

final isEmployeeProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.role == UserRole.employee;
});
