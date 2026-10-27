import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models.dart';

/// Watches the device GPS and fires a callback the first time the client
/// comes within range of a restaurant that has one of their active orders —
/// "you're here, show your pickup code" without any server round-trip.
class ProximityService {
  ProximityService._();
  static final ProximityService instance = ProximityService._();

  static const double _triggerRadiusMeters = 250;
  static const int _distanceFilterMeters = 40;

  StreamSubscription<Position>? _sub;
  final Set<String> _notified = {};

  List<Order> Function()? _orders;
  List<Restaurant> Function()? _restaurants;
  void Function(Order order, Restaurant restaurant)? _onArrival;

  bool get isRunning => _sub != null;

  /// (Re)binds live data sources; starts the GPS stream on first call.
  void start({
    required List<Order> Function() orders,
    required List<Restaurant> Function() restaurants,
    required void Function(Order, Restaurant) onArrival,
  }) {
    _orders = orders;
    _restaurants = restaurants;
    _onArrival = onArrival;
    if (_sub != null || kIsWeb) return;

    Geolocator.checkPermission()
        .then((permission) {
          if (permission == LocationPermission.denied ||
              permission == LocationPermission.deniedForever ||
              _sub != null) {
            return;
          }
          _sub =
              Geolocator.getPositionStream(
                locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.medium,
                  distanceFilter: _distanceFilterMeters,
                ),
              ).listen(
                _onPosition,
                onError: (Object e) {
                  if (kDebugMode) debugPrint('[Proximity] stream error: $e');
                },
              );
        })
        .catchError((Object _) {
          // No geolocator implementation (tests, desktop) — skip quietly.
        });
  }

  void _onPosition(Position p) {
    final orders = _orders?.call() ?? const <Order>[];
    final restaurants = _restaurants?.call() ?? const <Restaurant>[];
    if (orders.isEmpty || restaurants.isEmpty) return;

    for (final order in orders) {
      if (_notified.contains(order.id)) continue;
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
      if (restaurant == null ||
          (restaurant.latitude == 0 && restaurant.longitude == 0)) {
        continue;
      }

      final distanceMeters = Geolocator.distanceBetween(
        p.latitude,
        p.longitude,
        restaurant.latitude,
        restaurant.longitude,
      );
      if (distanceMeters <= _triggerRadiusMeters) {
        _notified.add(order.id);
        _onArrival?.call(order, restaurant);
      }
    }
  }

  /// Forget notified orders — call when the session resets or an order
  /// leaves the active set, so a future pickup can alert again.
  void reset() => _notified.clear();

  void stop() {
    _sub?.cancel();
    _sub = null;
    _orders = null;
    _restaurants = null;
    _onArrival = null;
    _notified.clear();
  }
}
