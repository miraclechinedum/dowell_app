import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<Map<String, dynamic>> submitReferral({
    required String referralName,
    required String referralEmail,
    required String referralPhone,
    required String address,
    required String serviceType,
    String? notes,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      final userData = userDoc.data();
      final customerName =
          userData?['displayName'] ??
          user.email?.split('@').first ??
          'Customer';
      final referralCode = userData?['referralCode'] ?? 'NONE';

      final referralRef = _firestore.collection('referrals').doc();
      final referralId = referralRef.id;

      final referralData = {
        'id': referralId,
        'customerId': user.uid,
        'customerName': customerName,
        'customerEmail': user.email,
        'customerReferralCode': referralCode,
        'referralName': referralName.trim(),
        'referralEmail': referralEmail.trim().toLowerCase(),
        'referralPhone': referralPhone.trim(),
        'address': address.trim(),
        'serviceType': serviceType,
        'notes': notes?.trim() ?? '',
        'status': 'pending',
        'bugBucksAwarded': 100,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'assignedTo': null,
        'adminNotes': '',
        'convertedAt': null,
      };

      await referralRef.set(referralData);

      await _awardBugBucks(
        userId: user.uid,
        amount: 100,
        type: 'referral',
        description: 'Referral: $referralName',
        referenceId: referralId,
      );

      await _updateUserStats(userId: user.uid, bugBucksToAdd: 100);

      await _createAdminNotification(
        title: 'New Referral Submitted',
        message: '$customerName submitted a referral for $referralName',
        type: 'new_referral',
        referenceId: referralId,
      );

      return {
        'success': true,
        'referralId': referralId,
        'message': 'Referral submitted successfully! 100 Bug Bucks awarded.',
      };
    } catch (e) {
      print('Error submitting referral: $e');
      rethrow;
    }
  }

  static Future<void> _awardBugBucks({
    required String userId,
    required int amount,
    required String type,
    required String description,
    required String referenceId,
  }) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final currentBalance = userDoc.data()?['bugBucks'] ?? 0;
      final newBalance = currentBalance + amount;

      await _firestore.collection('bugbucks_transactions').add({
        'userId': userId,
        'type': type,
        'amount': amount,
        'description': description,
        'referenceId': referenceId,
        'balanceBefore': currentBalance,
        'balanceAfter': newBalance,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error awarding Bug Bucks: $e');
      rethrow;
    }
  }

  static Future<void> _updateUserStats({
    required String userId,
    required int bugBucksToAdd,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'bugBucks': FieldValue.increment(bugBucksToAdd),
        'totalReferrals': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating user stats: $e');
      rethrow;
    }
  }

  static Future<void> _createAdminNotification({
    required String title,
    required String message,
    required String type,
    required String referenceId,
  }) async {
    try {
      final adminsQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      for (final adminDoc in adminsQuery.docs) {
        await _firestore.collection('notifications').add({
          'userId': adminDoc.id,
          'title': title,
          'message': message,
          'type': type,
          'referenceId': referenceId,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error creating admin notification: $e');
    }
  }

  static Future<String> getUserReferralCode() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();

      if (userData?['referralCode'] != null) {
        return userData!['referralCode'] as String;
      }

      final referralCode = _generateReferralCode();

      await _firestore.collection('users').doc(user.uid).update({
        'referralCode': referralCode,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return referralCode;
    } catch (e) {
      print('Error getting referral code: $e');
      rethrow;
    }
  }

  static String _generateReferralCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = StringBuffer('DOWELL');

    for (int i = 0; i < 6; i++) {
      random.write(
        chars[(DateTime.now().microsecondsSinceEpoch + i) % chars.length],
      );
    }

    return random.toString();
  }
}
