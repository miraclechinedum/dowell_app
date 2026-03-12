// lib/core/services/notification_service.dart
//
// Handles creating notification documents for all user types.
// The 'notifications' collection is created automatically the first time
// any notification is written — Firestore creates collections on first write.
//
// FIRESTORE RULE TO ADD (already in firestore.rules from previous session):
//   match /notifications/{notifId} {
//     allow create: if request.auth != null;
//     allow read, update: if request.auth.uid == resource.data.userId || isAdmin();
//   }

import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static final _db = FirebaseFirestore.instance;

  // ── Write a notification doc ───────────────────────────────────────────────
  static Future<void> send({
    required String userId,
    required String title,
    required String message,
    required String type,
    String? referenceId,
  }) async {
    try {
      await _db.collection('notifications').add({
        'userId': userId,
        'title': title,
        'message': message,
        'type': type,
        'referenceId': referenceId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Never let notification failures crash the main action
    }
  }

  // ── Get unread count for a user ────────────────────────────────────────────
  static Future<int> unreadCount(String userId) async {
    try {
      final snap = await _db
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();
      return snap.docs.length;
    } catch (_) {
      return 0;
    }
  }

  // ── Mark all as read for a user ────────────────────────────────────────────
  static Future<void> markAllRead(String userId) async {
    try {
      final snap = await _db
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();
      if (snap.docs.isEmpty) return;
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (_) {}
  }

  // ── Seed a welcome notification (call once after user registration) ────────
  static Future<void> sendWelcome(String userId, String userName) async {
    await send(
      userId: userId,
      title: 'Welcome to Dowell! 🎉',
      message:
          'Hi $userName! Your account is set up. Start referring customers to earn Bug Bucks.',
      type: 'welcome',
    );
  }
}
