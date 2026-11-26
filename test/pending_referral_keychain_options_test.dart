import 'package:dowell_app/features/dashboard/providers/referral_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Kept in its own file: other tests replace the secure storage platform with
// an in-memory fake, which would bypass the method channel checked here.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('iOS Keychain items are device-only and not iCloud-synced', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    SharedPreferences.setMockInitialValues({});
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });

    await SecurePendingReferralStore().write(
      'alice',
      PendingReferral(
        requestId: 'request_1234567890',
        fingerprint: 'fingerprint',
        form: ReferralForm(
          referralName: 'Person',
          referralEmail: 'person@example.com',
          referralPhone: '5551234567',
          address: '123 Example Street',
          serviceType: 'residential',
          notes: '',
        ),
      ),
    );

    final write = calls.singleWhere((call) => call.method == 'write');
    final options = (write.arguments as Map)['options'] as Map;
    expect(options['accessibility'], 'first_unlock_this_device');
    expect(options['synchronizable'], 'false');
    expect(options.containsKey('groupId'), isFalse);
    debugDefaultTargetPlatformOverride = null;
  });
}
