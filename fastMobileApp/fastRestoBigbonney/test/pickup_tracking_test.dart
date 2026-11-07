import 'package:fast_resto_bigbonney/models.dart';
import 'package:fast_resto_bigbonney/services/proximity_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pickupCodeFromToken', () {
    test('matches the backend implementation (shared vector)', () {
      // Same vector as backend/tests/autoAcceptAndPickup.test.ts.
      expect(
        pickupCodeFromToken('FAST-0123456789abcdef0123456789abcdef'),
        'E2AH-FAST',
      );
    });

    test('is 4 unambiguous chars + -FAST', () {
      expect(
        pickupCodeFromToken('FAST-ffffffffffffffffffffffffffffffff'),
        matches(RegExp(r'^[A-HJKMNP-Z2-9]{4}-FAST$')),
      );
    });
  });

  group('PickupTracker', () {
    final t0 = DateTime(2026, 11, 9, 12);

    test('GPS jitter while sitting still never starts tracking', () {
      final tracker = PickupTracker();
      for (var i = 0; i < 30; i++) {
        final d = 500.0 + (i.isEven ? 25 : -25); // ±25 m jitter
        expect(
          tracker.update(
            'o1',
            distanceMeters: d,
            serverProgress: 0,
            now: t0.add(Duration(seconds: 30 * i)),
          ),
          isNull,
        );
      }
      expect(tracker.isStarted('o1'), isFalse);
    });

    test('a short-distance order needs a real 40 m move, not just 5%', () {
      final tracker = PickupTracker();
      tracker.update('o1', distanceMeters: 300, serverProgress: 0, now: t0);
      // 20 m closer = 6.7% but under 40 m → still jitter territory.
      expect(
        tracker.update(
          'o1',
          distanceMeters: 380,
          serverProgress: 0,
          now: t0.add(const Duration(seconds: 30)),
        ),
        isNull,
      );
    });

    test('harsh ±50 m jitter still never starts tracking', () {
      final tracker = PickupTracker();
      final offsets = <double>[50, -50, 40, -45, 50, -50, 30, -40, 50, -50];
      for (var i = 0; i < offsets.length * 3; i++) {
        expect(
          tracker.update(
            'o1',
            distanceMeters: 500 + offsets[i % offsets.length],
            serverProgress: 0,
            now: t0.add(Duration(seconds: 30 * i)),
          ),
          isNull,
        );
      }
    });

    test('walking toward the restaurant starts and reports progress', () {
      final tracker = PickupTracker();
      var anyPatch = false;
      // Real GPS fixes arrive every ~5 s while walking (~8 m/step).
      for (var i = 0; i <= 40; i++) {
        final d = 1000 - i * 8.0;
        if (tracker.update(
          'o1',
          distanceMeters: d,
          serverProgress: 0,
          now: t0.add(Duration(seconds: 5 * i)),
        ) !=
            null) {
          anyPatch = true;
        }
      }
      expect(tracker.isStarted('o1'), isTrue);
      expect(anyPatch, isTrue);
    });

    test('uploads are throttled to one per 20 s', () {
      final tracker = PickupTracker();
      double? at(int sec, double d) => tracker.update(
        'o1',
        distanceMeters: d,
        serverProgress: 1, // already en route
        now: t0.add(Duration(seconds: sec)),
      );
      expect(at(0, 900), isNotNull);
      expect(at(10, 880), isNull);
      expect(at(21, 850), isNotNull);
    });

    test('"Je pars" (server already en route) resumes at once, never 0', () {
      final tracker = PickupTracker();
      final p = tracker.update(
        'o1',
        distanceMeters: 600,
        serverProgress: 1,
        now: t0,
      );
      expect(p, isNotNull);
      expect(p, greaterThanOrEqualTo(1));
    });

    test('after an app restart progress is reconstructed, not reset', () {
      final tracker = PickupTracker();
      // Server says 50% done and we're now 400 m away → started at ~800 m.
      tracker.update('o1', distanceMeters: 400, serverProgress: 50, now: t0);
      final p = tracker.update(
        'o1',
        distanceMeters: 200,
        serverProgress: 50,
        now: t0.add(const Duration(seconds: 30)),
      );
      expect(p, closeTo(75, 0.01));
    });

    test('finished orders are forgotten', () {
      final tracker = PickupTracker();
      tracker.update('o1', distanceMeters: 1000, serverProgress: 0, now: t0);
      tracker.update(
        'o1',
        distanceMeters: 800,
        serverProgress: 0,
        now: t0.add(const Duration(seconds: 30)),
      );
      tracker.retainOnly({});
      expect(tracker.isStarted('o1'), isFalse);
    });
  });
}
