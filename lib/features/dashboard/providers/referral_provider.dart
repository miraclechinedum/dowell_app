import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// =============== REFERRAL FORM MODEL ===============
class ReferralForm {
  final String referralName;
  final String referralEmail;
  final String referralPhone;
  final String address;
  final String serviceType;
  final String notes;

  ReferralForm({
    required this.referralName,
    required this.referralEmail,
    required this.referralPhone,
    required this.address,
    required this.serviceType,
    required this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'referralName': referralName,
      'referralEmail': referralEmail,
      'referralPhone': referralPhone,
      'address': address,
      'serviceType': serviceType,
      'notes': notes,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
      'bugBucksAwarded': 100,
    };
  }
}

// =============== REFERRAL SUBMISSION STATE ===============
class ReferralSubmissionState {
  final bool isLoading;
  final String? error;
  final String? referralCode;
  final bool success;

  const ReferralSubmissionState({
    this.isLoading = false,
    this.error,
    this.referralCode,
    this.success = false,
  });

  ReferralSubmissionState copyWith({
    bool? isLoading,
    String? error,
    String? referralCode,
    bool? success,
  }) {
    return ReferralSubmissionState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      referralCode: referralCode ?? this.referralCode,
      success: success ?? this.success,
    );
  }
}

// =============== REFERRAL SUBMISSION PROVIDER ===============
class ReferralSubmissionProvider
    extends StateNotifier<ReferralSubmissionState> {
  ReferralSubmissionProvider() : super(const ReferralSubmissionState());

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> getReferralCode() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get or create referral code for user
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists && userDoc.data()?['referralCode'] != null) {
        return userDoc.data()!['referralCode'] as String;
      } else {
        // Generate new referral code
        final referralCode = _generateReferralCode();
        await _firestore.collection('users').doc(user.uid).set({
          'referralCode': referralCode,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        return referralCode;
      }
    } catch (e) {
      print('Error getting referral code: $e');
      throw Exception('Failed to get referral code');
    }
  }

  Future<Map<String, dynamic>> submitReferral(ReferralForm form) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get user data
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userName = userDoc.data()?['name'] ?? user.displayName ?? 'Unknown';
      final userEmail = user.email ?? '';

      // Prepare referral data
      final referralData = form.toMap()
        ..addAll({
          'customerId': user.uid,
          'customerName': userName,
          'customerEmail': userEmail,
          'submittedAt': FieldValue.serverTimestamp(),
        });

      // Add referral to Firestore
      final docRef = await _firestore.collection('referrals').add(referralData);

      // Update user's bug bucks
      await _firestore.collection('users').doc(user.uid).set({
        'bugBucks': FieldValue.increment(100),
        'totalReferrals': FieldValue.increment(1),
        'lastReferralAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      state = state.copyWith(isLoading: false, success: true);

      return {
        'success': true,
        'message': 'Referral submitted successfully! You earned 100 Bug Bucks.',
        'referralId': docRef.id,
      };
    } catch (e) {
      print('Error submitting referral: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      throw Exception('Failed to submit referral: $e');
    }
  }

  String _generateReferralCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    final code = StringBuffer();

    for (int i = 0; i < 8; i++) {
      final index = (random + i) % chars.length;
      code.write(chars[index]);
    }

    return code.toString();
  }

  void resetState() {
    state = const ReferralSubmissionState();
  }
}

// =============== REFERRAL LIST STATE ===============
class ReferralListState {
  final List<Map<String, dynamic>> referrals;
  final bool isLoading;
  final String? error;
  final String filter;
  final int totalReferrals;
  final int totalBugBucks;

  const ReferralListState({
    this.referrals = const [],
    this.isLoading = false,
    this.error,
    this.filter = 'all',
    this.totalReferrals = 0,
    this.totalBugBucks = 0,
  });

  ReferralListState copyWith({
    List<Map<String, dynamic>>? referrals,
    bool? isLoading,
    String? error,
    String? filter,
    int? totalReferrals,
    int? totalBugBucks,
  }) {
    return ReferralListState(
      referrals: referrals ?? this.referrals,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      filter: filter ?? this.filter,
      totalReferrals: totalReferrals ?? this.totalReferrals,
      totalBugBucks: totalBugBucks ?? this.totalBugBucks,
    );
  }

  // ADD THIS MISSING METHOD
  Map<String, int> getStatusStats() {
    final stats = <String, int>{
      'pending': 0,
      'contacted': 0,
      'converted': 0,
      'rejected': 0,
      'total': referrals.length,
    };

    for (var referral in referrals) {
      final status = referral['status'] as String? ?? 'pending';
      stats[status] = (stats[status] ?? 0) + 1;
    }

    return stats;
  }
}

// =============== REFERRAL LIST PROVIDER ===============
class ReferralListProvider extends StateNotifier<ReferralListState> {
  ReferralListProvider() : super(const ReferralListState()) {
    _loadReferrals();
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _loadReferrals() async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final user = _auth.currentUser;
      if (user == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'User not authenticated',
        );
        return;
      }

      Query query = _firestore
          .collection('referrals')
          .where('customerId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true);

      if (state.filter != 'all') {
        query = query.where('status', isEqualTo: state.filter);
      }

      final snapshot = await query.get();

      // Calculate stats
      int totalBugBucks = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        totalBugBucks += (data['bugBucksAwarded'] as int? ?? 0);
      }

      final referrals = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          ...data,
          'id': doc.id,
          'doc': doc, // Store document reference for real-time updates
        };
      }).toList();

      state = state.copyWith(
        referrals: referrals,
        isLoading: false,
        totalReferrals: referrals.length,
        totalBugBucks: totalBugBucks,
      );
    } catch (e) {
      print('Error loading referrals: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load referrals: ${e.toString()}',
      );
    }
  }

  Future<void> setFilter(String filter) async {
    state = state.copyWith(filter: filter);
    await _loadReferrals();
  }

  Future<void> refresh() async {
    await _loadReferrals();
  }

  Stream<QuerySnapshot> get referralsStream {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    Query query = _firestore
        .collection('referrals')
        .where('customerId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true);

    if (state.filter != 'all') {
      query = query.where('status', isEqualTo: state.filter);
    }

    return query.snapshots();
  }
}

// =============== PROVIDERS ===============
// NEW: Provider for submitting referrals
final referralProvider =
    StateNotifierProvider<ReferralSubmissionProvider, ReferralSubmissionState>((
      ref,
    ) {
      return ReferralSubmissionProvider();
    });

// EXISTING: Provider for viewing referrals list
final referralListProvider =
    StateNotifierProvider<ReferralListProvider, ReferralListState>((ref) {
      return ReferralListProvider();
    });
