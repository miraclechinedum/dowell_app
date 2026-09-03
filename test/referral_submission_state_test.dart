import 'package:dowell_app/features/dashboard/providers/referral_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryPendingReferralStore implements PendingReferralStore {
  final Map<String, (String, String)> values = {};
  @override
  Future<void> clear(String uid) async => values.remove(uid);
  @override
  Future<(String, String)?> read(String uid) async => values[uid];
  @override
  Future<void> write(String uid, String requestId, String fingerprint) async {
    values[uid] = (requestId, fingerprint);
  }
}

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
    final payload = ReferralForm(
      referralName: 'Person',
      referralEmail: 'person@example.com',
      referralPhone: '5551234567',
      address: '123 Example Street',
      serviceType: 'residential',
      notes: '',
    ).toCallableMap('request_1234567890');

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

  test('unknown outcome reuses request ID; success clears it', () async {
    final seenIds = <String>[];
    var calls = 0;
    var generatedIds = 0;
    final store = MemoryPendingReferralStore();
    final provider = ReferralSubmissionProvider(
      userIdFactory: () => 'alice',
      pendingStore: store,
      requestIdFactory: () => 'request_123456789${generatedIds++}',
      callable: (payload) async {
        seenIds.add(payload['requestId'] as String);
        calls++;
        if (calls == 1) throw Exception('network outcome unknown');
        return {
          'success': true,
          'referralId': 'referral-1',
          'bugBucksAwarded': 125,
          'balanceAfter': 125,
        };
      },
    );
    final form = ReferralForm(
      referralName: 'Person',
      referralEmail: 'person@example.com',
      referralPhone: '5551234567',
      address: '123 Example Street',
      serviceType: 'residential',
      notes: '',
    );

    await expectLater(
      provider.submitReferral(form),
      throwsA(isA<ReferralSubmissionException>()),
    );
    expect(provider.activeRequestId, 'request_1234567890');
    final restarted = ReferralSubmissionProvider(
      userIdFactory: () => 'alice',
      pendingStore: store,
      requestIdFactory: () => 'request_1234567891',
      callable: (payload) async {
        seenIds.add(payload['requestId'] as String);
        return {
          'success': true,
          'referralId': 'referral-1',
          'bugBucksAwarded': 125,
          'balanceAfter': 125,
        };
      },
    );
    final result = await restarted.submitReferral(form);
    expect(seenIds, ['request_1234567890', 'request_1234567890']);
    expect(result['message'], contains('125 Bug Bucks'));
    expect(restarted.activeRequestId, isNull);
    await restarted.submitReferral(form);
    expect(seenIds.last, 'request_1234567891');
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
