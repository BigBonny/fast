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
  static const int _distanceFilterMeters = 30;

  StreamSubscription<Position>? _sub;
  final Set<String> _notified = {};

  List<Order> Function()? _orders;
  List<Restaurant> Function()? _restaurants;
  void Function(Order order, Restaurant restaurant)? _onArrival;

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
    String foregroundTitle = 'FAST',
    String foregroundBody = 'Tracking your pickup',
  }) {
    _orders = orders;
    _restaurants = restaurants;
    _onArrival = onArrival;
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
    for (final (order, restaurant) in evaluateArrivals(
      p.latitude,
      p.longitude,
      _orders?.call() ?? const <Order>[],
      _restaurants?.call() ?? const <Restaurant>[],
      _notified,
    )) {
      _notified.add(order.id);
      _onArrival?.call(order, restaurant);
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
    Set<String> alreadyNotified,
  ) {
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
      if (distanceKm * 1000 <= triggerRadiusMeters) {
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
  void reset() => _notified.clear();

  void stop() {
    _pause();
    _orders = null;
    _restaurants = null;
    _onArrival = null;
    _notified.clear();
  }
}
