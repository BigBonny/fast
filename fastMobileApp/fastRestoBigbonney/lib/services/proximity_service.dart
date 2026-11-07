import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models.dart';
import 'location_service.dart';

/// Watches the device GPS and fires a callback the first time the client
/// comes within range of a restaurant holding one of their active pickup
/// orders — "you're here, show your code" without any server round-trip.
///
/// The stream only runs while at least one order is awaiting pickup: call
/// [sync] whenever the order list changes. Each sync retries permission +
/// stream startup, so a user granting location mid-session is picked up
/// automatically. On Android the stream runs as a foreground service (it
/// keeps working with the screen off — the actual walking-to-pickup case);
/// on iOS background updates stay enabled for the same reason.
class ProximityService {
  ProximityService._();
  static final ProximityService instance = ProximityService._();

  static const double triggerRadiusMeters = 250;
  static const double nearRadiusMeters = 800;
  static const int _distanceFilterMeters = 30;

  StreamSubscription<Position>? _sub;
  final Set<String> _notified = {};
  final Set<String> _nearNotified = {};

  List<Order> Function()? _orders;
  List<Restaurant> Function()? _restaurants;
  void Function(Order order, Restaurant restaurant)? _onArrival;
  void Function(Order order, Restaurant restaurant)? _onNear;

  /// Live tracking uplink: fires (at most every 20s per order) once the
  /// client is actually moving toward the restaurant — this is what
  /// keeps the Pro card live even with the app backgrounded.
  void Function(
    String orderId,
    double gpsProgress,
    double latitude,
    double longitude,
    bool readyAtEntrance,
  )?
  onTrack;

  final PickupTracker tracker = PickupTracker();

  /// Shown on Android's persistent foreground-service notification while
  /// tracking is active (required for background location on Android).
  String _fgTitle = 'FAST';
  String _fgBody = 'Tracking your pickup';

  bool get isRunning => _sub != null;

  /// Binds live data sources. Call once per session (login) — [sync]
  /// handles the stream lifecycle afterwards.
  void start({
    required List<Order> Function() orders,
    required List<Restaurant> Function() restaurants,
    required void Function(Order, Restaurant) onArrival,
    void Function(Order, Restaurant)? onNear,
    void Function(
      String orderId,
      double gpsProgress,
      double latitude,
      double longitude,
      bool readyAtEntrance,
    )?
    onTrack,
    String foregroundTitle = 'FAST',
    String foregroundBody = 'Tracking your pickup',
  }) {
    _orders = orders;
    _restaurants = restaurants;
    _onArrival = onArrival;
    _onNear = onNear;
    this.onTrack = onTrack;
    _fgTitle = foregroundTitle;
    _fgBody = foregroundBody;
  }

  /// Orders awaiting pickup — the only case worth burning GPS for.
  List<Order> activePickupOrders() {
    final orders = _orders?.call() ?? const <Order>[];
    return orders
        .where(
          (o) =>
              !o.isDelivery &&
              (o.status == OrderStatus.preparing ||
                  o.status == OrderStatus.readyForPickup),
        )
        .toList();
  }

  /// Call after every order-list change: starts tracking when a pickup
  /// order exists, pauses when there's nothing to arrive for. Retrying
  /// here also covers the user granting permission mid-session.
  void sync() {
    if (kIsWeb) return;
    if (activePickupOrders().isEmpty) {
      _pause();
      return;
    }
    if (_sub != null) return;
    _ensureStream();
  }

  void _ensureStream() {
    unawaited(
      Geolocator.checkPermission()
          .then((permission) {
            if (permission == LocationPermission.denied) {
              return Geolocator.requestPermission();
            }
            return permission;
          })
          .then((permission) {
            if (!canTrackWith(permission as LocationPermission) ||
                _sub != null ||
                activePickupOrders().isEmpty) {
              return;
            }
            _sub =
                Geolocator.getPositionStream(
                  locationSettings: _settings(),
                ).listen(
                  _onPosition,
                  onError: (Object e) {
                    if (kDebugMode) {
                      debugPrint('[Proximity] stream error: $e');
                    }
                  },
                );
          })
          .catchError((Object _) {
            // No geolocator implementation (tests, desktop) — skip quietly.
          }),
    );
  }

  LocationSettings _settings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Foreground service keeps updates coming with the screen off —
      // exactly when someone is walking to pick up their order.
      return AndroidSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: _distanceFilterMeters,
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: _fgTitle,
          notificationText: _fgBody,
          enableWakeLock: false,
        ),
      );
    }
    return AppleSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: _distanceFilterMeters,
      // Keep fixes coming after the user pockets their phone (blue pill
      // indicator shows while tracking — expected, and temporary).
      allowBackgroundLocationUpdates: true,
      showBackgroundLocationIndicator: true,
      pauseLocationUpdatesAutomatically: false,
    );
  }

  void _onPosition(Position p) {
    final orders = _orders?.call() ?? const <Order>[];
    final restaurants = _restaurants?.call() ?? const <Restaurant>[];
    for (final (order, restaurant) in evaluateArrivals(
      p.latitude,
      p.longitude,
      orders,
      restaurants,
      _notified,
    )) {
      _notified.add(order.id);
      _onArrival?.call(order, restaurant);
    }
    for (final (order, restaurant) in evaluateArrivals(
      p.latitude,
      p.longitude,
      orders,
      restaurants,
      _nearNotified,
      radiusMeters: nearRadiusMeters,
    )) {
      _nearNotified.add(order.id);
      // Already walking (Je pars tapped, or movement detected) — asking
      // "are you leaving?" would be noise.
      if (order.gpsProgress > 0 || tracker.isStarted(order.id)) continue;
      _onNear?.call(order, restaurant);
    }
    _pushTracking(p, orders, restaurants);
  }

  /// Live uplink for every active pickup order. [PickupTracker] decides
  /// when the client has genuinely started moving and throttles patches.
  void _pushTracking(
    Position p,
    List<Order> orders,
    List<Restaurant> restaurants,
  ) {
    if (onTrack == null) return;
    final active = orders
        .where(
          (o) =>
              !o.isDelivery &&
              (o.status == OrderStatus.preparing ||
                  o.status == OrderStatus.readyForPickup),
        )
        .toList();
    tracker.retainOnly(active.map((o) => o.id).toSet());

    final now = DateTime.now();
    for (final order in active) {
      final restaurant = _restaurantFor(order, restaurants);
      if (restaurant == null) continue;
      final distM =
          LocationService.instance.calculateDistance(
            LatLng(p.latitude, p.longitude),
            LatLng(restaurant.latitude, restaurant.longitude),
          ) *
          1000;
      final progress = tracker.update(
        order.id,
        distanceMeters: distM,
        serverProgress: order.gpsProgress,
        now: now,
      );
      if (progress == null) continue;
      onTrack?.call(
        order.id,
        progress,
        p.latitude,
        p.longitude,
        distM <= PickupTracker.entranceMeters,
      );
    }
  }

  static Restaurant? _restaurantFor(Order order, List<Restaurant> all) {
    for (final r in all) {
      if (r.id == order.restaurantId) {
        return (r.latitude == 0 && r.longitude == 0) ? null : r;
      }
    }
    return null;
  }

  /// Pure permission gate (unit-testable): tracking starts for
  /// whileInUse/always, stays off for denied/deniedForever/unableToDetermine.
  static bool canTrackWith(LocationPermission permission) =>
      permission == LocationPermission.whileInUse ||
      permission == LocationPermission.always;

  /// Pure trigger logic (unit-testable): which (order, restaurant) pairs
  /// should alert for this position. Skips deliveries, inactive orders,
  /// un-geocoded restaurants, and orders already notified.
  static List<(Order, Restaurant)> evaluateArrivals(
    double lat,
    double lng,
    List<Order> orders,
    List<Restaurant> restaurants,
    Set<String> alreadyNotified, {
    double radiusMeters = triggerRadiusMeters,
  }) {
    final hits = <(Order, Restaurant)>[];
    for (final order in orders) {
      if (alreadyNotified.contains(order.id)) continue;
      if (order.status != OrderStatus.preparing &&
          order.status != OrderStatus.readyForPickup) {
        continue;
      }
      if (order.isDelivery) continue;

      Restaurant? restaurant;
      for (final r in restaurants) {
        if (r.id == order.restaurantId) {
          restaurant = r;
          break;
        }
      }
      // No usable coordinates → can't measure, never fire.
      if (restaurant == null ||
          (restaurant.latitude == 0 && restaurant.longitude == 0)) {
        continue;
      }

      final distanceKm = LocationService.instance.calculateDistance(
        LatLng(lat, lng),
        LatLng(restaurant.latitude, restaurant.longitude),
      );
      if (distanceKm * 1000 <= radiusMeters) {
        hits.add((order, restaurant));
      }
    }
    return hits;
  }

  void _pause() {
    _sub?.cancel();
    _sub = null;
  }

  /// Forget notified orders so a future pickup can alert again.
  void reset() {
    _notified.clear();
    _nearNotified.clear();
    tracker.clear();
  }

  void stop() {
    _pause();
    _orders = null;
    _restaurants = null;
    _onArrival = null;
    _onNear = null;
    onTrack = null;
    _notified.clear();
    _nearNotified.clear();
    tracker.clear();
  }
}


/// Pure movement gate for one device (unit-testable, no GPS/plugins).
///
/// Progress is straight-line: how much closer than the first fix the client
/// is. Tracking only "starts" after a real, sustained move — the smoothed
/// distance must be ≥5% of the way AND ≥100 m closer on two consecutive
/// fixes — so GPS jitter while sitting at a table never flips the
/// restaurant's card to en-route. If the server already shows the order en
/// route (Je pars, or a previous app session) it resumes immediately,
/// reconstructing the starting distance from that progress.
class PickupTracker {
  static const double startPercent = 5;
  static const double startMeters = 100;
  static const int confirmations = 2;
  static const double entranceMeters = 120;
  static const Duration interval = Duration(seconds: 20);

  final Map<String, double> _initial = {};
  final Map<String, double> _smoothed = {};
  final Map<String, int> _confirmed = {};
  final Map<String, DateTime> _lastSent = {};
  final Set<String> _started = {};

  bool isStarted(String orderId) => _started.contains(orderId);

  /// Returns the progress (0-100) to upload now, or null to stay quiet.
  double? update(
    String orderId, {
    required double distanceMeters,
    required double serverProgress,
    required DateTime now,
  }) {
    final initial = _initial.putIfAbsent(orderId, () {
      if (serverProgress > 0 && serverProgress < 100) {
        return distanceMeters / (1 - serverProgress / 100);
      }
      return distanceMeters;
    });
    if (serverProgress > 0) _started.add(orderId);

    if (!_started.contains(orderId)) {
      final prev = _smoothed[orderId];
      final smooth = prev == null
          ? distanceMeters
          : prev * 0.5 + distanceMeters * 0.5;
      _smoothed[orderId] = smooth;
      final moved = initial - smooth;
      final pct = initial > 1 ? moved / initial * 100 : 0.0;
      if (moved >= startMeters && pct >= startPercent) {
        final n = (_confirmed[orderId] ?? 0) + 1;
        _confirmed[orderId] = n;
        if (n >= confirmations) _started.add(orderId);
      } else {
        _confirmed[orderId] = 0;
      }
      if (!_started.contains(orderId)) return null;
    }

    final progress = initial > 1
        ? ((1 - distanceMeters / initial) * 100).clamp(0.0, 100.0)
        : 0.0;
    final last = _lastSent[orderId];
    if (last != null && now.difference(last) < interval) return null;
    _lastSent[orderId] = now;
    // Started orders never report 0 — the backend treats >0 as en route.
    return progress < 1 ? 1 : progress.toDouble();
  }

  void retainOnly(Set<String> activeIds) {
    _initial.removeWhere((k, _) => !activeIds.contains(k));
    _smoothed.removeWhere((k, _) => !activeIds.contains(k));
    _confirmed.removeWhere((k, _) => !activeIds.contains(k));
    _lastSent.removeWhere((k, _) => !activeIds.contains(k));
    _started.removeWhere((k) => !activeIds.contains(k));
  }

  void clear() {
    _initial.clear();
    _smoothed.clear();
    _confirmed.clear();
    _lastSent.clear();
    _started.clear();
  }
}
