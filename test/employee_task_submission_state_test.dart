import 'package:dowell_app/core/services/employee_service.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryPendingTaskStore implements PendingTaskStore {
  (String, String)? value;

  @override
  Future<void> clear(String uid) async => value = null;

  @override
  Future<(String, String)?> read(String uid) async => value;

  @override
  Future<void> write(String uid, String requestId, String fingerprint) async =>
      value = (requestId, fingerprint);
}

void main() {
  test('process restart reuses the request ID for an unchanged task', () async {
    final store = MemoryPendingTaskStore();
    final first = TaskRequestCoordinator(store, () => 'request-one');
    expect(await first.resolve('employee', 'same-payload'), 'request-one');

    final afterRestart = TaskRequestCoordinator(store, () => 'request-two');
    expect(
      await afterRestart.resolve('employee', 'same-payload'),
      'request-one',
    );
  });

  test(
    'changed task payload cannot silently reuse a pending request ID',
    () async {
      final store = MemoryPendingTaskStore();
      final coordinator = TaskRequestCoordinator(store, () => 'request-one');
      await coordinator.resolve('employee', 'first-payload');

      expect(
        () => coordinator.resolve('employee', 'changed-payload'),
        throwsException,
      );
    },
  );
}
