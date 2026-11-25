import 'package:fast_resto_bigbonney/provider.dart';
import 'package:fast_resto_bigbonney/services/app_foreground.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('idle customers poll notifications every 4th tick (2 min)', () {
    final hits = [
      for (var t = 1; t <= 8; t++)
        FASTProvider.shouldPollNotifications(t, hasActiveOrders: false),
    ];
    expect(hits, [false, false, false, true, false, false, false, true]);
  });

  test('customers with an order in flight poll every tick', () {
    for (var t = 1; t <= 5; t++) {
      expect(
        FASTProvider.shouldPollNotifications(t, hasActiveOrders: true),
        isTrue,
      );
    }
  });

  test('background states stop polling, transient inactive does not', () {
    AppForeground.update(AppLifecycleState.paused);
    expect(AppForeground.isActive, isFalse);
    AppForeground.update(AppLifecycleState.hidden);
    expect(AppForeground.isActive, isFalse);
    AppForeground.update(AppLifecycleState.inactive);
    expect(AppForeground.isActive, isTrue);
    AppForeground.update(AppLifecycleState.resumed);
    expect(AppForeground.isActive, isTrue);
  });
}
