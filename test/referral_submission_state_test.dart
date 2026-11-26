import 'dart:async';
import 'dart:convert';

import 'package:dowell_app/features/dashboard/providers/referral_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemoryPendingReferralStore implements PendingReferralStore {
  final Map<String, PendingReferral> values = {};
  bool failReads = false;
  bool failWrites = false;
  bool failClears = false;

  @override
  Future<void> clear(String uid) async {
    if (failClears) {
      throw PendingReferralStorageException('clear', Exception('locked'));
    }
    values.remove(uid);
  }

  @override
  Future<PendingReferral?> read(String uid) async {
    if (failReads) {
      throw PendingReferralStorageException('read', Exception('locked'));
    }
    return values[uid];
  }

  @override
  Future<void> write(String uid, PendingReferral pending) async {
    if (failWrites) {
      throw PendingReferralStorageException('write', Exception('locked'));
    }
    values[uid] = pending;
  }
}

/// Simulates Keychain failures such as errSecInteractionNotAllowed.
class FailingSecureStorage extends FlutterSecureStorage {
  const FailingSecureStorage();

  static final _error = PlatformException(code: 'Unexpected security result');

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => throw _error;

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => throw _error;

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => throw _error;
}

ReferralForm _form({
  String name = 'Person',
  String email = 'person@example.com',
  String notes = '',
}) => ReferralForm(
  referralName: name,
  referralEmail: email,
  referralPhone: '5551234567',
  address: '123 Example Street',
  serviceType: 'residential',
  notes: notes,
);

const _success = <String, dynamic>{
  'success': true,
  'referralId': 'referral-1',
  'bugBucksAwarded': 125,
  'balanceAfter': 125,
};

/// Records every callable payload and lets each test script the outcome.
class _Harness {
  _Harness({PendingReferralStore? store})
    : store = store ?? MemoryPendingReferralStore();

  final PendingReferralStore store;
  final payloads = <Map<String, dynamic>>[];
  var generatedIds = 0;
  Future<Map<String, dynamic>> Function()? outcome;

  ReferralSubmissionProvider provider() => ReferralSubmissionProvider(
    userIdFactory: () => 'alice',
    pendingStore: store,
    requestIdFactory: () => 'request_123456789${generatedIds++}',
    callable: (payload) async {
      payloads.add(payload);
      return (outcome ?? () async => _success)();
    },
  );

  List<String> get sentIds =>
      payloads.map((p) => p['requestId'] as String).toList();
}

Matcher _stage(ReferralSubmissionStage stage) =>
    isA<ReferralSubmissionException>().having((e) => e.stage, 'stage', stage);

void main() {
  test('copyWith can clear a referral submission error', () {
    const failed = ReferralSubmissionState(error: 'Previous failure');

    final retrying = failed.copyWith(
      isLoading: true,
      error: null,
      success: false,
    );

    expect(retrying.error, isNull);
    expect(retrying.isLoading, isTrue);
    expect(retrying.success, isFalse);
  });

  test('copyWith preserves an error when error is omitted', () {
    const failed = ReferralSubmissionState(error: 'Previous failure');

    final stopped = failed.copyWith(isLoading: false);

    expect(stopped.error, 'Previous failure');
  });

  test('callable payload excludes server-authored fields', () {
    final payload = _form().toCallableMap('request_1234567890');

    expect(
      payload.keys,
      containsAll(<String>[
        'requestId',
        'referralName',
        'referralEmail',
        'referralPhone',
        'address',
        'serviceType',
        'notes',
      ]),
    );
    expect(payload, isNot(contains('customerId')));
    expect(payload, isNot(contains('status')));
    expect(payload, isNot(contains('bugBucksAwarded')));
  });

  test(
    'unknown outcome reuses request ID after restart; success clears it',
    () async {
      final harness = _Harness();
      harness.outcome = () async => throw Exception('network outcome unknown');

      await expectLater(
        harness.provider().submitReferral(_form()),
        throwsA(_stage(ReferralSubmissionStage.callableSubmission)),
      );
      expect(harness.sentIds, ['request_1234567890']);

      harness.outcome = null;
      final restarted = harness.provider();
      final result = await restarted.submitReferral(_form());

      expect(harness.sentIds, ['request_1234567890', 'request_1234567890']);
      expect(result['message'], contains('125 Bug Bucks'));
      expect(await restarted.readPending(), isNull);

      await restarted.submitReferral(_form(name: 'Another Person'));
      expect(harness.sentIds.last, 'request_1234567891');
    },
  );

  test(
    'a function failure such as not-found keeps the pending record',
    () async {
      final harness = _Harness();
      harness.outcome = () async => throw Exception('NOT FOUND');

      await expectLater(
        harness.provider().submitReferral(_form()),
        throwsA(isA<ReferralSubmissionException>()),
      );

      final pending = await harness.provider().readPending();
      expect(pending?.requestId, 'request_1234567890');
      expect(pending?.form?.referralName, 'Person');
    },
  );

  group('retrying the original payload', () {
    test(
      'resends the exact stored payload and request ID after restart',
      () async {
        final harness = _Harness();
        harness.outcome = () async => throw Exception('timeout');
        final original = _form(name: 'Person', notes: 'Back door');
        await expectLater(
          harness.provider().submitReferral(original),
          throwsA(isA<ReferralSubmissionException>()),
        );

        harness.outcome = null;
        final restarted = harness.provider();
        final pending = await restarted.readPending();
        expect(pending?.canRetry, isTrue);

        await restarted.retryPendingSubmission();

        expect(harness.payloads, hasLength(2));
        expect(harness.payloads[1], harness.payloads[0]);
        expect(
          harness.payloads[1],
          original.toCallableMap('request_1234567890'),
        );
        expect(await restarted.readPending(), isNull);
        expect(harness.generatedIds, 1);
      },
    );

    test('re-entering equivalent details sends the stored original', () async {
      final harness = _Harness();
      harness.outcome = () async => throw Exception('timeout');
      await expectLater(
        harness.provider().submitReferral(_form(name: 'Person')),
        throwsA(isA<ReferralSubmissionException>()),
      );

      harness.outcome = null;
      await harness.provider().submitReferral(_form(name: '  PERSON '));

      expect(harness.payloads[1]['referralName'], 'Person');
      expect(harness.sentIds, ['request_1234567890', 'request_1234567890']);
    });

    test('reports when there is nothing to retry', () async {
      final harness = _Harness();
      await expectLater(
        harness.provider().retryPendingSubmission(),
        throwsA(_stage(ReferralSubmissionStage.pendingConflict)),
      );
      expect(harness.payloads, isEmpty);
    });
  });

  group('changed payload', () {
    test(
      'is rejected without calling the server or touching the record',
      () async {
        final harness = _Harness();
        harness.outcome = () async => throw Exception('timeout');
        final store = harness.store as MemoryPendingReferralStore;
        await expectLater(
          harness.provider().submitReferral(_form()),
          throwsA(isA<ReferralSubmissionException>()),
        );
        final before = store.values['alice'];

        await expectLater(
          harness.provider().submitReferral(_form(name: 'Someone Else')),
          throwsA(
            isA<PendingReferralMismatchException>().having(
              (e) => e.pending.form?.referralName,
              'pending name',
              'Person',
            ),
          ),
        );

        expect(harness.payloads, hasLength(1));
        expect(identical(store.values['alice'], before), isTrue);
        expect(harness.generatedIds, 1);
      },
    );
  });

  group('discarding', () {
    test(
      'only an explicit discard clears; the new ID comes after it',
      () async {
        final harness = _Harness();
        harness.outcome = () async => throw Exception('timeout');
        final provider = harness.provider();
        await expectLater(
          provider.submitReferral(_form()),
          throwsA(isA<ReferralSubmissionException>()),
        );

        provider.resetState();
        expect(await provider.readPending(), isNotNull);
        await expectLater(
          provider.submitReferral(_form(name: 'Someone Else')),
          throwsA(isA<PendingReferralMismatchException>()),
        );
        expect(harness.generatedIds, 1, reason: 'no new key before discard');

        await provider.discardPendingSubmission();
        expect(await provider.readPending(), isNull);
        expect(harness.generatedIds, 1, reason: 'discard alone creates no key');

        harness.outcome = null;
        await provider.submitReferral(_form(name: 'Someone Else'));
        expect(harness.sentIds, ['request_1234567890', 'request_1234567891']);
        expect(harness.payloads.last['referralName'], 'Someone Else');
      },
    );

    test('a failed discard keeps the record and reports it', () async {
      final store = MemoryPendingReferralStore();
      final harness = _Harness(store: store);
      harness.outcome = () async => throw Exception('timeout');
      final provider = harness.provider();
      await expectLater(
        provider.submitReferral(_form()),
        throwsA(isA<ReferralSubmissionException>()),
      );

      store.failClears = true;
      await expectLater(
        provider.discardPendingSubmission(),
        throwsA(_stage(ReferralSubmissionStage.pendingStorage)),
      );
      expect(store.values['alice']?.requestId, 'request_1234567890');
    });
  });

  group('duplicate submission prevention', () {
    test('a second tap while one is in flight is rejected', () async {
      final harness = _Harness();
      final gate = Completer<Map<String, dynamic>>();
      harness.outcome = () => gate.future;
      final provider = harness.provider();

      final first = provider.submitReferral(_form());
      await expectLater(
        provider.submitReferral(_form()),
        throwsA(_stage(ReferralSubmissionStage.inProgress)),
      );
      await expectLater(
        provider.retryPendingSubmission(),
        throwsA(_stage(ReferralSubmissionStage.inProgress)),
      );
      await expectLater(
        provider.discardPendingSubmission(),
        throwsA(_stage(ReferralSubmissionStage.inProgress)),
      );

      gate.complete(_success);
      await first;
      expect(harness.payloads, hasLength(1));
      expect(harness.generatedIds, 1);
      expect(provider.state.isLoading, isFalse);
    });
  });

  group('storage failures', () {
    test('an unreadable store blocks sending', () async {
      final store = MemoryPendingReferralStore()..failReads = true;
      final harness = _Harness(store: store);

      await expectLater(
        harness.provider().submitReferral(_form()),
        throwsA(_stage(ReferralSubmissionStage.pendingStorage)),
      );
      expect(harness.payloads, isEmpty);
    });

    test('a failed save blocks sending', () async {
      final store = MemoryPendingReferralStore()..failWrites = true;
      final harness = _Harness(store: store);
      final provider = harness.provider();

      await expectLater(
        provider.submitReferral(_form()),
        throwsA(_stage(ReferralSubmissionStage.pendingStorage)),
      );
      expect(harness.payloads, isEmpty);
      expect(provider.state.isLoading, isFalse);
      expect(provider.state.error, contains('not sent'));
    });

    test('a failed clear after success still reports success', () async {
      final store = MemoryPendingReferralStore()..failClears = true;
      final harness = _Harness(store: store);

      final result = await harness.provider().submitReferral(_form());

      expect(result['success'], isTrue);
      // Left in place; retrying it is idempotent on the server.
      expect(store.values['alice']?.requestId, 'request_1234567890');
    });

    test('Keychain errors surface as storage exceptions', () async {
      final store = SecurePendingReferralStore(
        secureStorage: const FailingSecureStorage(),
      );
      SharedPreferences.setMockInitialValues({});

      await expectLater(
        store.read('alice'),
        throwsA(isA<PendingReferralStorageException>()),
      );
      await expectLater(
        store.write(
          'alice',
          PendingReferral(
            requestId: 'request_1234567890',
            fingerprint: _form().normalizedFingerprint,
            form: _form(),
          ),
        ),
        throwsA(isA<PendingReferralStorageException>()),
      );
      await expectLater(
        store.clear('alice'),
        throwsA(isA<PendingReferralStorageException>()),
      );
    });
  });

  group('SecurePendingReferralStore', () {
    late Map<String, String> keychain;
    late SecurePendingReferralStore store;

    setUp(() {
      keychain = {};
      FlutterSecureStorage.setMockInitialValues(keychain);
      SharedPreferences.setMockInitialValues({});
      store = SecurePendingReferralStore();
    });

    test(
      'round-trips the payload in secure storage, not preferences',
      () async {
        final pending = PendingReferral(
          requestId: 'request_1234567890',
          fingerprint: _form().normalizedFingerprint,
          form: _form(notes: 'Gate code'),
        );
        await store.write('alice', pending);

        final read = await store.read('alice');
        expect(read?.requestId, 'request_1234567890');
        expect(
          read?.form?.toPayloadJson(),
          _form(notes: 'Gate code').toPayloadJson(),
        );
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getKeys(), isEmpty);
        expect(keychain.keys, [SecurePendingReferralStore.secureKey('alice')]);
        expect(await store.read('bob'), isNull);

        await store.clear('alice');
        expect(await store.read('alice'), isNull);
        expect(keychain, isEmpty);
      },
    );

    test('a corrupt record is unreadable, never treated as absent', () async {
      keychain[SecurePendingReferralStore.secureKey('alice')] = '{not json';
      final harness = _Harness(store: store);
      final provider = harness.provider();

      final pending = await provider.readPending();
      expect(pending?.isReadable, isFalse);
      await expectLater(
        provider.submitReferral(_form()),
        throwsA(isA<PendingReferralMismatchException>()),
      );
      await expectLater(
        provider.retryPendingSubmission(),
        throwsA(_stage(ReferralSubmissionStage.pendingConflict)),
      );
      expect(harness.payloads, isEmpty);

      await provider.discardPendingSubmission();
      expect(await provider.readPending(), isNull);
    });

    test('a record with an incomplete payload is not filled in', () async {
      keychain[SecurePendingReferralStore.secureKey('alice')] = jsonEncode({
        'version': 2,
        'requestId': 'request_1234567890',
        'fingerprint': _form().normalizedFingerprint,
        'payload': {'referralName': 'Person'},
      });

      final pending = await store.read('alice');
      expect(pending?.requestId, 'request_1234567890');
      expect(pending?.form, isNull);
      expect(pending?.canRetry, isFalse);
    });
  });

  group('legacy pending records (request ID and hash only)', () {
    late Map<String, String> keychain;
    late SecurePendingReferralStore store;
    final legacyForm = _form();

    setUp(() {
      keychain = {};
      FlutterSecureStorage.setMockInitialValues(keychain);
      SharedPreferences.setMockInitialValues({
        SecurePendingReferralStore.legacyRequestKey('alice'):
            'legacy_request_123456',
        SecurePendingReferralStore.legacyFingerprintKey('alice'):
            legacyForm.normalizedFingerprint,
      });
      store = SecurePendingReferralStore();
    });

    test(
      'are surfaced without details and cannot be blindly retried',
      () async {
        final harness = _Harness(store: store);
        final provider = harness.provider();

        final pending = await provider.readPending();
        expect(pending?.requestId, 'legacy_request_123456');
        expect(pending?.isReadable, isTrue);
        expect(pending?.form, isNull);
        expect(pending?.canRetry, isFalse);

        await expectLater(
          provider.retryPendingSubmission(),
          throwsA(_stage(ReferralSubmissionStage.pendingConflict)),
        );
        await expectLater(
          provider.submitReferral(_form(name: 'Someone Else')),
          throwsA(isA<PendingReferralMismatchException>()),
        );
        expect(harness.payloads, isEmpty);
        expect(harness.generatedIds, 0);
      },
    );

    test('re-entering the same details retries under the legacy ID', () async {
      final harness = _Harness(store: store);
      harness.outcome = () async => throw Exception('timeout');
      final provider = harness.provider();

      await expectLater(
        provider.submitReferral(legacyForm),
        throwsA(isA<ReferralSubmissionException>()),
      );

      expect(harness.sentIds, ['legacy_request_123456']);
      expect(harness.generatedIds, 0);
      // Now stored securely with the payload actually sent; legacy keys gone.
      final upgraded = await store.read('alice');
      expect(upgraded?.requestId, 'legacy_request_123456');
      expect(upgraded?.form?.toPayloadJson(), legacyForm.toPayloadJson());
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);

      harness.outcome = null;
      await provider.retryPendingSubmission();
      expect(harness.sentIds, [
        'legacy_request_123456',
        'legacy_request_123456',
      ]);
      expect(await store.read('alice'), isNull);
    });

    test(
      'a confirmed discard removes them; the next referral gets a new ID',
      () async {
        final harness = _Harness(store: store);
        final provider = harness.provider();

        await provider.discardPendingSubmission();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getKeys(), isEmpty);
        expect(await store.read('alice'), isNull);
        await provider.submitReferral(_form(name: 'Someone Else'));
        expect(harness.sentIds, ['request_1234567890']);
      },
    );

    test('a partial legacy record was never sent and is ignored', () async {
      SharedPreferences.setMockInitialValues({
        SecurePendingReferralStore.legacyRequestKey('alice'):
            'legacy_request_123456',
      });
      expect(await SecurePendingReferralStore().read('alice'), isNull);
    });
  });

  test('callable error codes map to sanitized messages', () {
    expect(
      ReferralSubmissionProvider.userMessageForCode('unauthenticated'),
      contains('sign in'),
    );
    expect(
      ReferralSubmissionProvider.userMessageForCode('invalid-argument'),
      contains('check'),
    );
    expect(
      ReferralSubmissionProvider.userMessageForCode('already-exists'),
      contains('already'),
    );
    expect(
      ReferralSubmissionProvider.userMessageForCode('failed-precondition'),
      contains('cannot'),
    );
    expect(
      ReferralSubmissionProvider.userMessageForCode('unavailable'),
      contains('retry safely'),
    );
    expect(
      ReferralSubmissionProvider.userMessageForCode('internal'),
      isNot(contains('Firestore')),
    );
  });
}
