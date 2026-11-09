import 'package:flutter_test/flutter_test.dart';
import 'package:fast_resto_bigbonney/models.dart';
import 'package:fast_resto_bigbonney/screens/resto/client_proximity.dart';

Order _order({
  double gpsProgress = 0,
  int etaMin = 0,
  bool atEntrance = false,
  FulfillmentType type = FulfillmentType.pickup,
}) =>
    Order(
      id: 'o1',
      restaurantId: 'r1',
      restaurantName: 'Resto',
      restaurantImage: '',
      items: const [],
      subtotal: 10,
      serviceFee: 1,
      total: 11,
      status: OrderStatus.preparing,
      createdAt: '2026-11-09T12:00:00Z',
      userWalkTimeMinutes: 10,
      gpsProgress: gpsProgress,
      clientDelayMin: etaMin,
      isReadyAtEntrance: atEntrance,
      fulfillmentType: type,
    );

void main() {
  test('client not left yet → green', () {
    final p = clientProximity(_order());
    expect(p, ClientProximity.notLeft);
    expect(p!.color, kProxGreen);
    expect(p.tintsCard, isFalse); // card keeps its status colour
  });

  test('client en route, more than 2 min away → yellow', () {
    final p = clientProximity(_order(gpsProgress: 30, etaMin: 6));
    expect(p, ClientProximity.enRoute);
    expect(p!.color, kProxYellow);
    // Even near the end of the route, a known ETA over 2 min stays yellow.
    expect(clientProximity(_order(gpsProgress: 95, etaMin: 3)),
        ClientProximity.enRoute);
  });

  test('2 minutes or less → red', () {
    for (final eta in [1, 2]) {
      final p = clientProximity(_order(gpsProgress: 50, etaMin: eta));
      expect(p, ClientProximity.arriving, reason: '$eta min');
      expect(p!.color, kProxRed);
    }
  });

  test('no live ETA yet: route almost walked counts as arriving', () {
    expect(clientProximity(_order(gpsProgress: 92)), ClientProximity.arriving);
    expect(clientProximity(_order(gpsProgress: 60)), ClientProximity.enRoute);
  });

  test('at the entrance → red, whatever the GPS says', () {
    final p = clientProximity(_order(atEntrance: true));
    expect(p, ClientProximity.atEntrance);
    expect(p!.color, kProxRed);
  });

  test('only pickups get a proximity colour', () {
    expect(clientProximity(_order(type: FulfillmentType.dineIn)), isNull);
  });
}
