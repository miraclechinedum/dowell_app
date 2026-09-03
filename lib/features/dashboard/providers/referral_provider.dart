import 'dart:math';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

const _notProvided = Object();

enum ReferralSubmissionStage { callableSubmission }

class ReferralSubmissionException implements Exception {
  final ReferralSubmissionStage stage;
  final String userMessage;

  const ReferralSubmissionException(this.stage, this.userMessage);

  @override
  String toString() => userMessage;
}

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

  Map<String, dynamic> toCallableMap(String requestId) {
    return {
      'requestId': requestId,
      'referralName': referralName,
      'referralEmail': referralEmail,
      'referralPhone': referralPhone,
      'address': address,
      'serviceType': serviceType,
      'notes': notes,
    };
  }

  String get normalizedFingerprint => sha256
      .convert(
        utf8.encode(
          <String>[
            referralName.trim().toLowerCase(),
            referralEmail.trim().toLowerCase(),
            referralPhone.replaceAll(RegExp(r'\D'), ''),
            address.trim().toLowerCase(),
            serviceType.trim().toLowerCase(),
            notes.trim().toLowerCase(),
          ].join('\u001f'),
        ),
      )
      .toString();
}

abstract class PendingReferralStore {
  Future<(String, String)?> read(String uid);
  Future<void> write(String uid, String requestId, String fingerprint);
  Future<void> clear(String uid);
}

class SharedPreferencesPendingReferralStore implements PendingReferralStore {
  String _requestKey(String uid) => 'pending_referral_request_$uid';
  String _fingerprintKey(String uid) => 'pending_referral_fingerprint_$uid';

  @override
  Future<(String, String)?> read(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final requestId = prefs.getString(_requestKey(uid));
    final fingerprint = prefs.getString(_fingerprintKey(uid));
    return requestId == null || fingerprint == null
        ? null
        : (requestId, fingerprint);
  }

  @override
  Future<void> write(String uid, String requestId, String fingerprint) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_requestKey(uid), requestId);
    await prefs.setString(_fingerprintKey(uid), fingerprint);
  }

  @override
  Future<void> clear(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_requestKey(uid));
    await prefs.remove(_fingerprintKey(uid));
  }
}

typedef ReferralCallable =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> input);
typedef RequestIdFactory = String Function();
typedef UserIdFactory = String? Function();

String _newRequestId() {
  final random = Random.secure();
  return List.generate(32, (_) => random.nextInt(16).toRadixString(16)).join();
}

// =============== REFERRAL SUBMISSION STATE ===============
class ReferralSubmissionState {
  final bool isLoading;
  final String? error;
  final bool success;

  const ReferralSubmissionState({
    this.isLoading = false,
    this.error,
    this.success = false,
  });

  ReferralSubmissionState copyWith({
    bool? isLoading,
    Object? error = _notProvided,
    bool? success,
  }) {
    return ReferralSubmissionState(
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _notProvided) ? this.error : error as String?,
      success: success ?? this.success,
    );
  }
}

// =============== REFERRAL SUBMISSION PROVIDER ===============
class ReferralSubmissionProvider
    extends StateNotifier<ReferralSubmissionState> {
  ReferralSubmissionProvider({
    ReferralCallable? callable,
    RequestIdFactory? requestIdFactory,
    PendingReferralStore? pendingStore,
    UserIdFactory? userIdFactory,
  }) : _callable = callable ?? _defaultCallable,
       _requestIdFactory = requestIdFactory ?? _newRequestId,
       _pendingStore = pendingStore ?? SharedPreferencesPendingReferralStore(),
       _userIdFactory =
           userIdFactory ?? (() => FirebaseAuth.instance.currentUser?.uid),
       super(const ReferralSubmissionState());

  final ReferralCallable _callable;
  final RequestIdFactory _requestIdFactory;
  final PendingReferralStore _pendingStore;
  final UserIdFactory _userIdFactory;
  String? _activeRequestId;

  static Future<Map<String, dynamic>> _defaultCallable(
    Map<String, dynamic> input,
  ) async {
    final result = await FirebaseFunctions.instance
        .httpsCallable('submitReferral')
        .call<Map<String, dynamic>>(input);
    return result.data;
  }

  Future<Map<String, dynamic>> submitReferral(ReferralForm form) async {
    state = state.copyWith(isLoading: true, error: null, success: false);

    final uid = _userIdFactory();
    if (uid == null) {
      const failure = ReferralSubmissionException(
        ReferralSubmissionStage.callableSubmission,
        'Your session has expired. Please sign in again and retry.',
      );
      state = state.copyWith(isLoading: false, error: failure.userMessage);
      throw failure;
    }
    final fingerprint = form.normalizedFingerprint;
    final persisted = await _pendingStore.read(uid);
    if (persisted != null && persisted.$2 != fingerprint) {
      const failure = ReferralSubmissionException(
        ReferralSubmissionStage.callableSubmission,
        'A previous submission is still pending with different details. '
        'Retry the original details or deliberately discard it and start a new referral.',
      );
      state = state.copyWith(isLoading: false, error: failure.userMessage);
      throw failure;
    }
    final requestId = _activeRequestId ?? persisted?.$1 ?? _requestIdFactory();
    _activeRequestId = requestId;
    await _pendingStore.write(uid, requestId, fingerprint);
    try {
      final result = await _callable(form.toCallableMap(requestId));
      final amount = (result['bugBucksAwarded'] as num?)?.toInt() ?? 0;
      _activeRequestId = null;
      await _pendingStore.clear(uid);
      state = state.copyWith(isLoading: false, success: true);
      return {
        ...result,
        'message':
            'Referral submitted successfully! You earned $amount Bug Bucks.',
      };
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'Referral callable failed code=${error is FirebaseFunctionsException ? error.code : 'unknown'} '
          'requestId=$requestId\n$stackTrace',
        );
      }
      final failure = ReferralSubmissionException(
        ReferralSubmissionStage.callableSubmission,
        userMessageForCode(
          error is FirebaseFunctionsException ? error.code : 'unknown',
          details: error is FirebaseFunctionsException ? error.details : null,
        ),
      );
      state = state.copyWith(isLoading: false, error: failure.userMessage);
      throw failure;
    }
  }

  static String userMessageForCode(String code, {Object? details}) {
    switch (code) {
      case 'unauthenticated':
        return 'Your session has expired. Please sign in again and retry.';
      case 'invalid-argument':
        return 'Please check the referral details and try again.';
      case 'already-exists':
        if (details is Map && details['reason'] == 'request-id-mismatch') {
          return 'This submission was already used for a different referral. '
              'Start a new referral before submitting these changes.';
        }
        return 'This referral has already been submitted.';
      case 'failed-precondition':
        return 'This account cannot submit the referral right now.';
      case 'unavailable':
      case 'deadline-exceeded':
      case 'unknown':
        return 'The result could not be confirmed. You can retry safely.';
      default:
        return 'We could not submit your referral. Please try again.';
    }
  }

  Future<void> resetState({bool newReferral = true}) async {
    if (newReferral) {
      _activeRequestId = null;
      final uid = _userIdFactory();
      if (uid != null) await _pendingStore.clear(uid);
    }
    state = const ReferralSubmissionState();
  }

  @visibleForTesting
  String? get activeRequestId => _activeRequestId;
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

      final activeDocs = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['isDeleted'] != true;
      }).toList();

      // Calculate stats
      int totalBugBucks = 0;
      for (var doc in activeDocs) {
        final data = doc.data() as Map<String, dynamic>;
        totalBugBucks += (data['bugBucksAwarded'] as num?)?.toInt() ?? 0;
      }

      final referrals = activeDocs.map((doc) {
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
      if (kDebugMode) {
        debugPrint('Error loading referrals: $e');
      }
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
