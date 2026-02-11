import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  static Future<void> initialize() async {
    await Firebase.initializeApp();

    await FirebaseAuth.instance.app.isAutomaticDataCollectionEnabled;

    await _initializeFirestoreData();
    await initializeAppSettings();
  }

  static Future<void> _initializeFirestoreData() async {
    try {
      await FirebaseAuth.instance.app.isAutomaticDataCollectionEnabled;

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
    // Improved referral code generation
    final random = DateTime.now().microsecondsSinceEpoch;
    final code =
        'DOWELL${random.toString().substring(random.toString().length - 6)}';
    return code;
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
