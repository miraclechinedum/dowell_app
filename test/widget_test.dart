import 'package:dowell_app/features/dashboard/screens/customer/submit_referral_screen.dart';
import 'package:dowell_app/features/dashboard/providers/referral_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryPendingReferralStore implements PendingReferralStore {
  final Map<String, PendingReferral> values = {};

  @override
  Future<void> clear(String uid) async => values.remove(uid);

  @override
  Future<PendingReferral?> read(String uid) async => values[uid];

  @override
  Future<void> write(String uid, PendingReferral pending) async {
    values[uid] = pending;
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

  group('pending referral recovery', () {
    final original = ReferralForm(
      referralName: 'Original Person',
      referralEmail: 'original@example.com',
      referralPhone: '5550001111',
      address: '1 Original Road',
      serviceType: 'termite',
      notes: '',
    );
    late _MemoryPendingReferralStore store;
    late List<Map<String, dynamic>> payloads;
    late int generatedIds;

    ReferralSubmissionProvider buildProvider() => ReferralSubmissionProvider(
      userIdFactory: () => 'alice',
      pendingStore: store,
      requestIdFactory: () => 'request_new_${generatedIds++}_000000',
      callable: (payload) async {
        payloads.add(payload);
        return {'success': true, 'bugBucksAwarded': 125};
      },
    );

    Future<void> pumpScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [referralProvider.overrideWith((ref) => buildProvider())],
          child: MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SubmitReferralScreen(),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    setUp(() {
      store = _MemoryPendingReferralStore();
      payloads = [];
      generatedIds = 0;
      store.values['alice'] = PendingReferral(
        requestId: 'request_original_1234',
        fingerprint: original.normalizedFingerprint,
        form: original,
      );
    });

    testWidgets('banner after restart retries the exact original', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.byKey(const Key('pendingReferralBanner')), findsOneWidget);
      expect(find.textContaining('Original Person'), findsOneWidget);

      await tester.tap(find.byKey(const Key('pendingBannerRetryButton')));
      await tester.pumpAndSettle();

      expect(payloads, [original.toCallableMap('request_original_1234')]);
      expect(generatedIds, 0);
      expect(store.values, isEmpty);
      expect(find.text('Success!'), findsOneWidget);
      expect(find.byKey(const Key('pendingReferralBanner')), findsNothing);
    });

    testWidgets('legacy record banner offers discard only', (tester) async {
      store.values['alice'] = const PendingReferral(
        requestId: 'legacy_request_123456',
        fingerprint: 'legacy-fingerprint',
      );
      await pumpScreen(tester);

      expect(find.byKey(const Key('pendingReferralBanner')), findsOneWidget);
      expect(
        find.textContaining('were not saved on this device'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('pendingBannerRetryButton')), findsNothing);
      expect(
        find.byKey(const Key('pendingBannerDiscardButton')),
        findsOneWidget,
      );
    });

    testWidgets(
      'changed details require a confirmed discard before a new key',
      (tester) async {
        await pumpScreen(tester);
        await _fillRequiredReferralFields(tester);
        await tester.tap(find.byKey(const Key('referralConsentCheckbox')));
        await tester.pump();
        final dialog = find.byKey(const Key('pendingReferralConflictDialog'));
        // Closing a dialog restores text-field focus, which scrolls the page.
        Future<void> tapSubmit() async {
          final submit = find.byKey(const Key('submitReferralButton'));
          await tester.ensureVisible(submit);
          await tester.pumpAndSettle();
          await tester.tap(submit);
        }

        // Cancel leaves everything as it was.
        await tapSubmit();
        await tester.pumpAndSettle();
        expect(dialog, findsOneWidget);
        expect(
          find.byKey(const Key('conflictRetryPendingButton')),
          findsOneWidget,
        );
        await tester.tap(
          find.descendant(of: dialog, matching: find.text('Cancel')),
        );
        await tester.pumpAndSettle();
        expect(payloads, isEmpty);
        expect(store.values['alice']?.requestId, 'request_original_1234');

        // Choosing discard but declining the confirmation keeps it too.
        await tapSubmit();
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('conflictDiscardPendingButton')));
        await tester.pumpAndSettle();
        expect(find.text('Discard Pending Referral?'), findsOneWidget);
        await tester.tap(find.text('Keep It'));
        await tester.pumpAndSettle();
        expect(payloads, isEmpty);
        expect(generatedIds, 0);
        expect(store.values['alice']?.requestId, 'request_original_1234');

        // Confirmed: the old record goes, then the new details get a new key.
        await tapSubmit();
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('conflictDiscardPendingButton')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('confirmDiscardPendingReferralButton')),
        );
        await tester.pumpAndSettle();

        expect(payloads, hasLength(1));
        expect(payloads.single['requestId'], 'request_new_0_000000');
        expect(payloads.single['referralName'], 'Referral Person');
        expect(generatedIds, 1);
        expect(find.text('Success!'), findsOneWidget);
      },
    );

    testWidgets('cancelling the form does not clear a pending submission', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tester.enterText(find.byType(TextFormField).first, 'Someone');
      final pageScroll = find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first;
      final cancel = find.widgetWithText(OutlinedButton, 'Cancel');
      await tester.scrollUntilVisible(cancel, 300, scrollable: pageScroll);
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(find.byType(SubmitReferralScreen), findsNothing);
      expect(store.values['alice']?.requestId, 'request_original_1234');
      expect(payloads, isEmpty);
    });
  });
}
