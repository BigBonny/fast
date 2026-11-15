// Reservation notifications: what the restaurant team is alerted about,
// and when the client's "table in 1 hour" reminder fires.

import 'package:flutter_test/flutter_test.dart';

import 'package:fast_resto_bigbonney/models.dart';
import 'package:fast_resto_bigbonney/provider.dart';
import 'package:fast_resto_bigbonney/resto_provider.dart';

Reservation _resa(String id, String status, {DateTime? at}) => Reservation(
  id: id,
  restaurantId: 'r1',
  customerName: 'Camille',
  partySize: 4,
  dateTime: at ?? DateTime.now().add(const Duration(days: 1)),
  status: status,
  restaurantName: 'King Tacos',
);

void main() {
  group('restaurant alerts', () {
    test('the first fetch after launch never alerts', () {
      final alerts = RestoProvider.reservationAlerts(null, [
        _resa('a', 'PENDING'),
      ]);
      expect(alerts.created, isEmpty);
      expect(alerts.cancelled, isEmpty);
    });

    test('a new pending request alerts once', () {
      final list = [_resa('a', 'CONFIRMED'), _resa('b', 'PENDING')];
      final alerts = RestoProvider.reservationAlerts({'a': 'CONFIRMED'}, list);
      expect(alerts.created.map((r) => r.id), ['b']);
      // Seen on the next poll: nothing more to say.
      final again = RestoProvider.reservationAlerts({
        'a': 'CONFIRMED',
        'b': 'PENDING',
      }, list);
      expect(again.created, isEmpty);
    });

    test('a client cancelling a request or a confirmed table alerts', () {
      final alerts = RestoProvider.reservationAlerts(
        {'a': 'CONFIRMED', 'b': 'PENDING', 'c': 'DECLINED'},
        [
          _resa('a', 'CANCELLED'),
          _resa('b', 'CANCELLED'),
          _resa('c', 'DECLINED'),
        ],
      );
      expect(alerts.cancelled.map((r) => r.id), ['a', 'b']);
      expect(alerts.created, isEmpty);
    });

    test('an already-handled reservation appearing late stays silent', () {
      final alerts = RestoProvider.reservationAlerts({}, [
        _resa('a', 'CANCELLED'),
        _resa('b', 'CONFIRMED'),
      ]);
      expect(alerts.created, isEmpty);
      expect(alerts.cancelled, isEmpty);
    });
  });

  group('client reminder', () {
    final now = DateTime(2026, 11, 15, 18);

    test('fires one hour before a confirmed table', () {
      final r = _resa('a', 'CONFIRMED', at: DateTime(2026, 11, 15, 20, 30));
      expect(
        FASTProvider.reservationReminderDelay(r, now),
        const Duration(hours: 1, minutes: 30),
      );
    });

    test('no reminder when the table is less than an hour away', () {
      final r = _resa('a', 'CONFIRMED', at: DateTime(2026, 11, 15, 18, 40));
      expect(FASTProvider.reservationReminderDelay(r, now), isNull);
    });

    test('no reminder unless the restaurant confirmed', () {
      for (final status in ['PENDING', 'DECLINED', 'CANCELLED']) {
        final r = _resa('a', status, at: DateTime(2026, 11, 16, 20));
        expect(
          FASTProvider.reservationReminderDelay(r, now),
          isNull,
          reason: status,
        );
      }
    });
  });

  test('a confirmed upcoming table can still be cancelled', () {
    expect(_resa('a', 'CONFIRMED').isCancellable, isTrue);
    expect(_resa('a', 'PENDING').isCancellable, isTrue);
    expect(_resa('a', 'DECLINED').isCancellable, isFalse);
    expect(
      _resa(
        'a',
        'CONFIRMED',
        at: DateTime.now().subtract(const Duration(hours: 2)),
      ).isCancellable,
      isFalse,
    );
  });
}
