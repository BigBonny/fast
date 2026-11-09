import 'package:flutter/material.dart';

import '../../models.dart';

/// Where a pickup client is, as shown on the Pro order cards and the
/// kitchen screen. One rule for both screens:
///
/// - green  = client hasn't left yet
/// - yellow = client en route
/// - red    = client 2 minutes away or less, or at the entrance
enum ClientProximity { notLeft, enRoute, arriving, atEntrance }

/// Red threshold: live walking ETA at or under this many minutes.
const int kArrivingEtaMin = 2;

const Color kProxGreen = Color(0xFF22C55E);
const Color kProxYellow = Color(0xFFFACC15);
const Color kProxRed = Color(0xFFEF4444);

/// null for orders that aren't pickups (dine-in, delivery).
///
/// `gpsProgress` is only sent once the client has really started moving
/// (or tapped "Je pars"). While en route, the server stores the live walking
/// ETA in `clientDelayMin` (1-60 min); 0 means no position yet, in which
/// case a route almost walked (≥ 90 %) also counts as arriving.
ClientProximity? clientProximity(Order order) {
  if (order.fulfillmentType != FulfillmentType.pickup) return null;
  if (order.isReadyAtEntrance) return ClientProximity.atEntrance;
  if (order.gpsProgress <= 0) return ClientProximity.notLeft;
  final eta = order.clientDelayMin;
  final arriving = eta > 0 ? eta <= kArrivingEtaMin : order.gpsProgress >= 90;
  return arriving ? ClientProximity.arriving : ClientProximity.enRoute;
}

extension ClientProximityStyle on ClientProximity {
  Color get color => switch (this) {
    ClientProximity.notLeft => kProxGreen,
    ClientProximity.enRoute => kProxYellow,
    ClientProximity.arriving || ClientProximity.atEntrance => kProxRed,
  };

  /// Text colour on a chip filled with [color]: dark on yellow, white
  /// otherwise.
  Color get onColor =>
      this == ClientProximity.enRoute ? Colors.black : Colors.white;

  String get labelKey => switch (this) {
    ClientProximity.notLeft => 'client_not_left',
    ClientProximity.enRoute => 'prox_far',
    ClientProximity.arriving => 'client_almost',
    ClientProximity.atEntrance => 'prox_here',
  };

  /// Whether the card border takes the proximity colour. A client who hasn't
  /// left keeps the order's status colour (violet = preparing, blue = ready),
  /// so the kitchen still sees where each order stands.
  bool get tintsCard => this != ClientProximity.notLeft;
}
