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

  static const Duration _trackInterval = Duration(seconds: 20);
  static const double _trackStartThreshold = 5; // % of route covered
  final Map<String, double> _initialDistances = {};
  final Map<String, DateTime> _lastTrackSent = {};
  final Set<String> _trackStarted = {};

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
      _onNear?.call(order, restaurant);
    }
    _pushTracking(p, orders, restaurants);
  }

  /// Straight-line progress toward each active pickup order. Patches
  /// only start once the client has genuinely moved (≥5% closer than
  /// their first fix) — GPS jitter at the start never flips the Pro
  /// card to en-route. Once started, patches keep flowing (including
  /// drops) until the order leaves the active set.
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
    final activeIds = active.map((o) => o.id).toSet();
    _initialDistances.removeWhere((k, _) => !activeIds.contains(k));
    _lastTrackSent.removeWhere((k, _) => !activeIds.contains(k));
    _trackStarted.removeWhere((k) => !activeIds.contains(k));

    final now = DateTime.now();
    for (final order in active) {
      Restaurant? restaurant;
      for (final r in restaurants) {
        if (r.id == order.restaurantId) {
          restaurant = r;
          break;
        }
      }
      if (restaurant == null ||
          (restaurant.latitude == 0 && restaurant.longitude == 0)) {
        continue;
      }
      final distM =
          LocationService.instance
              .calculateDistance(
                LatLng(p.latitude, p.longitude),
                LatLng(restaurant.latitude, restaurant.longitude),
              ) *
          1000;
      final initial = _initialDistances.putIfAbsent(order.id, () => distM);
      final progress = initial > 1
          ? ((1 - distM / initial) * 100).clamp(0.0, 100.0)
          : 0.0;
      if (progress >= _trackStartThreshold) _trackStarted.add(order.id);
      if (!_trackStarted.contains(order.id)) continue;

      final last = _lastTrackSent[order.id];
      if (last != null && now.difference(last) < _trackInterval) continue;
      _lastTrackSent[order.id] = now;
      onTrack?.call(
        order.id,
        progress,
        p.latitude,
        p.longitude,
        distM <= 120,
      );
    }
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
    _initialDistances.clear();
    _lastTrackSent.clear();
    _trackStarted.clear();
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
    _initialDistances.clear();
    _lastTrackSent.clear();
    _trackStarted.clear();
  }
}
