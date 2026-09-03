import 'package:dowell_app/features/dashboard/screens/customer/submit_referral_screen.dart';
import 'package:dowell_app/features/dashboard/providers/referral_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryPendingReferralStore implements PendingReferralStore {
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

Future<void> _fillRequiredReferralFields(WidgetTester tester) async {
  final fields = find.byType(TextFormField);
  final pageScroll = find
      .descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(Scrollable),
      )
      .first;
  await tester.enterText(fields.at(0), 'Referral Person');
  await tester.enterText(fields.at(1), 'person@example.com');
  await tester.enterText(fields.at(2), '5551234567');
  await tester.enterText(fields.at(3), '123 Example Street');
  await tester.scrollUntilVisible(
    find.text('Residential Pest Control'),
    300,
    scrollable: pageScroll,
  );
  await tester.tap(find.text('Residential Pest Control'));
  await tester.pump();
  await tester.scrollUntilVisible(
    find.byKey(const Key('submitReferralButton')),
    300,
    scrollable: pageScroll,
  );
}

void main() {
  testWidgets('referral UI uses correct branding and has no referral code', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SubmitReferralScreen())),
    );
    expect(find.text('Submit New Referral'), findsOneWidget);
    expect(find.text('Referral Information'), findsOneWidget);
    expect(find.text('Submit Referral'), findsOneWidget);
    expect(find.textContaining('Dowell Pest Control service'), findsOneWidget);
    expect(find.textContaining('Code:'), findsNothing);
    expect(find.byKey(const Key('referralConsentCheckbox')), findsOneWidget);
    expect(
      find.textContaining('address with Dowell Pest Control'),
      findsOneWidget,
    );
  });

  testWidgets('unchecked consent blocks callable submission', (tester) async {
    var calls = 0;
    final submission = ReferralSubmissionProvider(
      userIdFactory: () => 'alice',
      pendingStore: _MemoryPendingReferralStore(),
      requestIdFactory: () => 'request_1234567890',
      callable: (payload) async {
        calls++;
        throw Exception('should not be called');
      },
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [referralProvider.overrideWith((ref) => submission)],
        child: const MaterialApp(home: SubmitReferralScreen()),
      ),
    );
    await _fillRequiredReferralFields(tester);

    await tester.tap(find.byKey(const Key('submitReferralButton')));
    await tester.pump();

    expect(calls, 0);
    expect(find.byKey(const Key('referralConsentError')), findsOneWidget);
    expect(
      find.textContaining('Please confirm that you have permission'),
      findsOneWidget,
    );
  });

  testWidgets('checked consent allows the secure callable path', (
    tester,
  ) async {
    var calls = 0;
    final submission = ReferralSubmissionProvider(
      userIdFactory: () => 'alice',
      pendingStore: _MemoryPendingReferralStore(),
      requestIdFactory: () => 'request_1234567890',
      callable: (payload) async {
        calls++;
        throw Exception('simulated sanitized failure');
      },
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [referralProvider.overrideWith((ref) => submission)],
        child: const MaterialApp(home: SubmitReferralScreen()),
      ),
    );
    await _fillRequiredReferralFields(tester);
    await tester.tap(find.byKey(const Key('referralConsentCheckbox')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('submitReferralButton')));
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('Submission Failed'), findsOneWidget);
    expect(find.textContaining('Firestore'), findsNothing);
  });
}
