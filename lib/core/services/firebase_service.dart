import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  static Future<void> initialize() async {
    await Firebase.initializeApp();

    await _initializeFirestoreData();
  }

  static Future<void> _initializeFirestoreData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid);
        final userSnapshot = await userDoc.get();

        if (!userSnapshot.exists) {
          await userDoc.set({
            'email': user.email,
            'displayName':
                user.displayName ?? user.email?.split('@').first ?? 'User',
            'role': 'customer',
            'bugBucks': 0,
            'totalReferrals': 0,
            'convertedReferrals': 0,
            'referralCode': _generateReferralCode(),
            'status': 'active',
            'needsVerification': false,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }
    } catch (e) {
      print('❌ Error initializing user data: $e');
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

  static Future<void> initializeAppSettings() async {
    try {
      final settingsRef = FirebaseFirestore.instance
          .collection('app_settings')
          .doc('default');
      final settingsSnapshot = await settingsRef.get();

      if (!settingsSnapshot.exists) {
        await settingsRef.set({
          'bugBucksPerReferral': 100,
          'employeeBonusAmount': 50.00,
          'nilAthleteCommissionRate': 0.15,
          'minimumWithdrawalAmount': 25.00,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('❌ Error initializing app settings: $e');
    }
  }
}
