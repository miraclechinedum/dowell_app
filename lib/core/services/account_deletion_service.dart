import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Handles Apple-compliant account deletion through retained deactivation.
///
/// Account deactivation is performed by a trusted callable. The client only handles
/// recent-login reauthentication and invokes that backend operation.
/// State management lives in [AuthProvider] and the UI lives in the settings
/// screen.
class AccountDeletionService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Re-authenticates the current user with their email + [password].
  ///
  /// Firebase requires a recent sign-in before sensitive operations such as
  /// account deletion. Throws [FirebaseAuthException] on invalid credentials.
  static Future<void> reauthenticateWithPassword(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No signed-in user to re-authenticate.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
  }

  static Future<void> deleteMyAccountData() async {
    try {
      await FirebaseFunctions.instance
          .httpsCallable('deleteMyAccountData')
          .call();
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'failed-precondition') {
        throw FirebaseAuthException(
          code: 'requires-recent-login',
          message: 'Recent authentication is required.',
        );
      }
      if (_isAmbiguousCallableCode(error.code)) {
        final user = _auth.currentUser;
        if (user == null) return;
        try {
          await user.reload();
          if (_auth.currentUser == null) return;
        } on FirebaseAuthException catch (authError) {
          if (isConfirmedDeletedAuthState(authError.code)) return;
        }
      }
      rethrow;
    }
  }

  static bool _isAmbiguousCallableCode(String code) => const {
    'unauthenticated',
    'unavailable',
    'deadline-exceeded',
    'unknown',
    'internal',
  }.contains(code);

  static bool isConfirmedDeletedAuthState(String code) =>
      const {'user-disabled', 'user-not-found'}.contains(code);
}
