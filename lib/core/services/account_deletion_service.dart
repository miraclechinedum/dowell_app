import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Handles permanent, Apple-compliant (Guideline 5.1.1(v)) account deletion.
///
/// This is pure Firebase logic with no UI or state: it removes every Firestore
/// document owned by a user and deletes their Firebase Authentication account.
/// State management lives in [AuthProvider] and the UI lives in the settings
/// screen — keeping this layer consistent with [FirestoreService].
class AccountDeletionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Collections that store documents owned by a user, mapped to the field
  /// that holds the owner's uid.
  ///
  /// The `users/{uid}` profile document is keyed by document id, so it is
  /// handled separately in [deleteUserData]. Global / system collections
  /// (`app_settings`, `audit_logs`) are intentionally excluded so we never
  /// touch data that is not owned by the user.
  static const Map<String, String> _ownedCollections = {
    'referrals': 'customerId',
    'employee_tasks': 'employeeId',
    'employee_cashouts': 'employeeId',
    'bugbucks_transactions': 'userId',
    'cash_bonus_transactions': 'userId',
    'role_requests': 'userId',
    'notifications': 'userId',
  };

  /// Permanently deletes every Firestore document that belongs to [uid].
  ///
  /// Documents are removed with chunked batched writes so large data sets stay
  /// within Firestore's 500-operation batch limit. A failure deleting one
  /// collection does not abort the others, so a partial failure still removes
  /// as much as possible. The main `users/{uid}` profile is deleted last.
  static Future<void> deleteUserData(String uid) async {
    for (final entry in _ownedCollections.entries) {
      await _deleteQueryInBatches(
        _firestore.collection(entry.key).where(entry.value, isEqualTo: uid),
      );
    }

    // Remove the main profile document (keyed by uid).
    await _firestore.collection('users').doc(uid).delete();
  }

  /// Deletes all documents matched by [query] in batches of up to 450
  /// operations (under Firestore's 500 limit, leaving headroom).
  static Future<void> _deleteQueryInBatches(Query query) async {
    const int batchSize = 450;

    while (true) {
      final snapshot = await query.limit(batchSize).get();
      if (snapshot.docs.isEmpty) break;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Last page reached.
      if (snapshot.docs.length < batchSize) break;
    }
  }

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

  /// Deletes the Firebase Authentication account of the current user.
  ///
  /// Throws [FirebaseAuthException] with code `requires-recent-login` when the
  /// user must re-authenticate (see [reauthenticateWithPassword]) before the
  /// account can be removed.
  static Future<void> deleteAuthAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No signed-in user to delete.',
      );
    }
    await user.delete();
  }
}
