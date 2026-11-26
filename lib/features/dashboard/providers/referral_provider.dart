import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _notProvided = Object();

enum ReferralSubmissionStage {
  callableSubmission,
  pendingConflict,
  pendingStorage,
  inProgress,
}

class ReferralSubmissionException implements Exception {
  final ReferralSubmissionStage stage;
  final String userMessage;

  const ReferralSubmissionException(this.stage, this.userMessage);

  @override
  String toString() => userMessage;
}

/// A different submission is still unconfirmed. Nothing was sent: the user
/// must retry [pending] or deliberately discard it.
class PendingReferralMismatchException extends ReferralSubmissionException {
  final PendingReferral pending;

  const PendingReferralMismatchException(this.pending)
    : super(
        ReferralSubmissionStage.pendingConflict,
        'A previous submission is still pending with different details. '
        'Retry the original details or deliberately discard it and start a new referral.',
      );
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
    return {'requestId': requestId, ...toPayloadJson()};
  }

  Map<String, String> toPayloadJson() => {
    'referralName': referralName,
    'referralEmail': referralEmail,
    'referralPhone': referralPhone,
    'address': address,
    'serviceType': serviceType,
    'notes': notes,
  };

  /// Returns null unless every field is present; missing details are never
  /// filled in.
  static ReferralForm? fromPayloadJson(Object? json) {
    if (json is! Map) return null;
    String? field(String key) {
      final value = json[key];
      return value is String ? value : null;
    }

    final referralName = field('referralName');
    final referralEmail = field('referralEmail');
    final referralPhone = field('referralPhone');
    final address = field('address');
    final serviceType = field('serviceType');
    final notes = field('notes');
    if (referralName == null ||
        referralEmail == null ||
        referralPhone == null ||
        address == null ||
        serviceType == null ||
        notes == null) {
      return null;
    }
    return ReferralForm(
      referralName: referralName,
      referralEmail: referralEmail,
      referralPhone: referralPhone,
      address: address,
      serviceType: serviceType,
      notes: notes,
    );
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

// =============== PENDING SUBMISSION ===============
/// A submission the server has not confirmed. Its request ID must be reused
/// for any retry so the server can deduplicate it.
@immutable
class PendingReferral {
  const PendingReferral({
    required this.requestId,
    required this.fingerprint,
    this.form,
  }) : isReadable = true;

  /// A stored record that exists but cannot be parsed. It can only be
  /// deliberately discarded.
  const PendingReferral.unreadable()
    : requestId = '',
      fingerprint = '',
      form = null,
      isReadable = false;

  final String requestId;
  final String fingerprint;

  /// The exact payload sent with [requestId]. Null for records written by app
  /// versions that stored only the request ID and fingerprint.
  final ReferralForm? form;
  final bool isReadable;

  bool get canRetry => isReadable && form != null;

  bool matches(String fingerprint) =>
      isReadable && this.fingerprint == fingerprint;
}

class PendingReferralStorageException implements Exception {
  const PendingReferralStorageException(this.operation, this.cause);

  final String operation;
  final Object cause;

  @override
  String toString() =>
      'PendingReferralStorageException($operation, ${cause.runtimeType})';
}

abstract class PendingReferralStore {
  /// Throws [PendingReferralStorageException] if storage cannot be read.
  Future<PendingReferral?> read(String uid);

  /// Throws [PendingReferralStorageException] if the record was not saved.
  Future<void> write(String uid, PendingReferral pending);

  /// Throws [PendingReferralStorageException] if the record may remain.
  Future<void> clear(String uid);
}

/// Keeps pending referral details (third-party PII) in the iOS Keychain /
/// Android Keystore-backed storage, and still reads records that earlier app
/// versions left in SharedPreferences (request ID and fingerprint only).
class SecurePendingReferralStore implements PendingReferralStore {
  SecurePendingReferralStore({
    FlutterSecureStorage? secureStorage,
    Future<SharedPreferences> Function()? preferences,
  }) : _secure =
           secureStorage ?? const FlutterSecureStorage(iOptions: iosOptions),
       _preferences = preferences ?? SharedPreferences.getInstance;

  /// Readable after the first unlock following a restart (so a retry is not
  /// blocked by a locked screen), never restored to another device, and not
  /// synced to iCloud Keychain.
  static const iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  static String secureKey(String uid) => 'pending_referral_v2_$uid';
  static String legacyRequestKey(String uid) => 'pending_referral_request_$uid';
  static String legacyFingerprintKey(String uid) =>
      'pending_referral_fingerprint_$uid';

  final FlutterSecureStorage _secure;
  final Future<SharedPreferences> Function() _preferences;

  @override
  Future<PendingReferral?> read(String uid) async {
    final String? raw;
    try {
      raw = await _secure.read(key: secureKey(uid));
    } catch (error) {
      throw PendingReferralStorageException('read', error);
    }
    if (raw != null) return _decode(raw);

    final String? requestId;
    final String? fingerprint;
    try {
      final prefs = await _preferences();
      requestId = prefs.getString(legacyRequestKey(uid));
      fingerprint = prefs.getString(legacyFingerprintKey(uid));
    } catch (error) {
      throw PendingReferralStorageException('read', error);
    }
    // Earlier versions saved both values before calling the server, so a
    // partial record was never sent (and they ignored it as well).
    if (requestId == null || fingerprint == null) return null;
    return PendingReferral(requestId: requestId, fingerprint: fingerprint);
  }

  static PendingReferral _decode(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is Map &&
          json['version'] == 2 &&
          json['requestId'] is String &&
          (json['requestId'] as String).isNotEmpty &&
          json['fingerprint'] is String) {
        return PendingReferral(
          requestId: json['requestId'] as String,
          fingerprint: json['fingerprint'] as String,
          form: ReferralForm.fromPayloadJson(json['payload']),
        );
      }
    } on FormatException {
      // Fall through: treated as unreadable, never as absent.
    }
    return const PendingReferral.unreadable();
  }

  @override
  Future<void> write(String uid, PendingReferral pending) async {
    final form = pending.form;
    if (!pending.isReadable || form == null) {
      throw ArgumentError('Only complete pending records can be written.');
    }
    try {
      await _secure.write(
        key: secureKey(uid),
        value: jsonEncode({
          'version': 2,
          'requestId': pending.requestId,
          'fingerprint': pending.fingerprint,
          'payload': form.toPayloadJson(),
        }),
      );
    } catch (error) {
      throw PendingReferralStorageException('write', error);
    }
    // The secure record now supersedes any legacy record; read() prefers it
    // even if this cleanup fails.
    try {
      await _removeLegacy(uid);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Legacy pending referral cleanup failed: $error');
      }
    }
  }

  @override
  Future<void> clear(String uid) async {
    try {
      await _secure.delete(key: secureKey(uid));
      await _removeLegacy(uid);
    } catch (error) {
      throw PendingReferralStorageException('clear', error);
    }
  }

  Future<void> _removeLegacy(String uid) async {
    final prefs = await _preferences();
    await prefs.remove(legacyRequestKey(uid));
    await prefs.remove(legacyFingerprintKey(uid));
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
       _pendingStore = pendingStore ?? SecurePendingReferralStore(),
       _userIdFactory =
           userIdFactory ?? (() => FirebaseAuth.instance.currentUser?.uid),
       super(const ReferralSubmissionState());

  final ReferralCallable _callable;
  final RequestIdFactory _requestIdFactory;
  final PendingReferralStore _pendingStore;
  final UserIdFactory _userIdFactory;
  bool _inFlight = false;

  static Future<Map<String, dynamic>> _defaultCallable(
    Map<String, dynamic> input,
  ) async {
    final result = await FirebaseFunctions.instance
        .httpsCallable('submitReferral')
        .call<Map<String, dynamic>>(input);
    return result.data;
  }

  /// The signed-in user's unconfirmed submission, if any.
  Future<PendingReferral?> readPending() async {
    final uid = _userIdFactory();
    if (uid == null) return null;
    return _readPending(uid);
  }

  /// Submits [form]. If an unconfirmed submission with the same details
  /// exists, it is resent with its original request ID and payload; if its
  /// details differ, throws [PendingReferralMismatchException] without sending.
  Future<Map<String, dynamic>> submitReferral(ReferralForm form) {
    return _guarded(() async {
      final uid = _requireUid();
      final fingerprint = form.normalizedFingerprint;
      final pending = await _readPending(uid);
      if (pending != null && !pending.matches(fingerprint)) {
        throw PendingReferralMismatchException(pending);
      }
      if (pending != null && pending.form != null) {
        return _send(uid, pending.requestId, pending.form!);
      }
      // New submission, or a legacy record (no stored payload) whose details
      // the user has re-entered exactly: persist the payload being sent
      // before sending it.
      final requestId = pending?.requestId ?? _requestIdFactory();
      await _writePending(
        uid,
        PendingReferral(
          requestId: requestId,
          fingerprint: fingerprint,
          form: form,
        ),
      );
      return _send(uid, requestId, form);
    });
  }

  /// Resends the pending submission's exact original payload and request ID.
  Future<Map<String, dynamic>> retryPendingSubmission() {
    return _guarded(() async {
      final uid = _requireUid();
      final pending = await _readPending(uid);
      final form = pending?.form;
      if (pending == null) {
        throw const ReferralSubmissionException(
          ReferralSubmissionStage.pendingConflict,
          'There is no pending referral to retry.',
        );
      }
      if (!pending.canRetry || form == null) {
        throw const ReferralSubmissionException(
          ReferralSubmissionStage.pendingConflict,
          'The original referral details are not available on this device. '
          'Re-enter the exact same details to retry, or discard the pending submission.',
        );
      }
      return _send(uid, pending.requestId, form);
    });
  }

  /// Abandons the pending submission so the next one gets a new request ID.
  /// Call only after the user explicitly confirms. A referral the server
  /// already received is not affected.
  Future<void> discardPendingSubmission() {
    return _guarded(() async {
      final uid = _requireUid();
      try {
        await _pendingStore.clear(uid);
      } on PendingReferralStorageException catch (error) {
        if (kDebugMode) debugPrint('Pending referral discard failed: $error');
        throw const ReferralSubmissionException(
          ReferralSubmissionStage.pendingStorage,
          'We could not discard the pending referral. Please try again.',
        );
      }
      state = const ReferralSubmissionState();
    });
  }

  /// Resets screen state only. A pending submission is cleared solely by a
  /// confirmed success or [discardPendingSubmission].
  void resetState() {
    state = const ReferralSubmissionState();
  }

  Future<T> _guarded<T>(Future<T> Function() action) async {
    // Checked before the first await, so a second tap in the same frame is
    // rejected rather than racing the first.
    if (_inFlight) {
      throw const ReferralSubmissionException(
        ReferralSubmissionStage.inProgress,
        'A referral submission is already in progress.',
      );
    }
    _inFlight = true;
    state = state.copyWith(isLoading: true, error: null, success: false);
    try {
      return await action();
    } on ReferralSubmissionException catch (failure) {
      state = state.copyWith(isLoading: false, error: failure.userMessage);
      rethrow;
    } finally {
      _inFlight = false;
      if (state.isLoading) state = state.copyWith(isLoading: false);
    }
  }

  String _requireUid() {
    final uid = _userIdFactory();
    if (uid == null) {
      throw const ReferralSubmissionException(
        ReferralSubmissionStage.callableSubmission,
        'Your session has expired. Please sign in again and retry.',
      );
    }
    return uid;
  }

  Future<PendingReferral?> _readPending(String uid) async {
    try {
      return await _pendingStore.read(uid);
    } on PendingReferralStorageException catch (error) {
      if (kDebugMode) debugPrint('Pending referral read failed: $error');
      throw const ReferralSubmissionException(
        ReferralSubmissionStage.pendingStorage,
        'We could not check this device for an earlier referral submission. '
        'Nothing was sent. Please try again.',
      );
    }
  }

  Future<void> _writePending(String uid, PendingReferral pending) async {
    try {
      await _pendingStore.write(uid, pending);
    } on PendingReferralStorageException catch (error) {
      if (kDebugMode) debugPrint('Pending referral write failed: $error');
      throw const ReferralSubmissionException(
        ReferralSubmissionStage.pendingStorage,
        'We could not save this submission securely on this device, '
        'so it was not sent. Please try again.',
      );
    }
  }

  Future<Map<String, dynamic>> _send(
    String uid,
    String requestId,
    ReferralForm form,
  ) async {
    final Map<String, dynamic> result;
    try {
      result = await _callable(form.toCallableMap(requestId));
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'Referral callable failed code=${error is FirebaseFunctionsException ? error.code : 'unknown'} '
          'requestId=$requestId\n$stackTrace',
        );
      }
      throw ReferralSubmissionException(
        ReferralSubmissionStage.callableSubmission,
        userMessageForCode(
          error is FirebaseFunctionsException ? error.code : 'unknown',
          details: error is FirebaseFunctionsException ? error.details : null,
        ),
      );
    }
    // Confirmed by the server. If clearing fails the record stays, and
    // retrying it is safe: the server returns the original result for the
    // same request ID and payload.
    try {
      await _pendingStore.clear(uid);
    } on PendingReferralStorageException catch (error) {
      if (kDebugMode) debugPrint('Pending referral clear failed: $error');
    }
    final amount = (result['bugBucksAwarded'] as num?)?.toInt() ?? 0;
    state = state.copyWith(isLoading: false, success: true);
    return {
      ...result,
      'message':
          'Referral submitted successfully! You earned $amount Bug Bucks.',
    };
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
