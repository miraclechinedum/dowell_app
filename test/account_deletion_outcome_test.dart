import 'package:dowell_app/core/services/account_deletion_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('disabled or missing Auth account confirms ambiguous deletion', () {
    expect(
      AccountDeletionService.isConfirmedDeletedAuthState('user-disabled'),
      isTrue,
    );
    expect(
      AccountDeletionService.isConfirmedDeletedAuthState('user-not-found'),
      isTrue,
    );
  });

  test('network and credential errors do not falsely confirm deletion', () {
    expect(
      AccountDeletionService.isConfirmedDeletedAuthState(
        'network-request-failed',
      ),
      isFalse,
    );
    expect(
      AccountDeletionService.isConfirmedDeletedAuthState('wrong-password'),
      isFalse,
    );
  });
}
