import 'dart:async';

import 'package:fast_resto_bigbonney/services/permission_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('permission prompts run one at a time, in call order', () async {
    final log = <String>[];
    final firstDialog = Completer<void>();

    final notifications = PermissionQueue.run(() async {
      log.add('notifications:start');
      await firstDialog.future; // dialog still open
      log.add('notifications:end');
      return 'granted';
    });
    final location = PermissionQueue.run(() async {
      log.add('location:start');
      return 'whileInUse';
    });

    await Future<void>.delayed(Duration.zero);
    expect(log, ['notifications:start']); // location waits for the dialog

    firstDialog.complete();
    expect(await notifications, 'granted');
    expect(await location, 'whileInUse');
    expect(log, [
      'notifications:start',
      'notifications:end',
      'location:start',
    ]);
  });

  test('a failed prompt does not block the next one', () async {
    final failed = PermissionQueue.run<void>(
      () async => throw StateError('plugin missing'),
    );
    final next = PermissionQueue.run(() async => 'ok');

    await expectLater(failed, throwsStateError);
    expect(await next, 'ok');
  });
}
