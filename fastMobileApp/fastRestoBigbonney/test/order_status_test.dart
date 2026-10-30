import 'package:flutter_test/flutter_test.dart';
import 'package:fast_resto_bigbonney/models.dart';

void main() {
  test('fromApiJson parses every backend status including snake_case', () {
    expect(OrderStatus.fromApiJson('PLACED'), OrderStatus.placed);
    expect(OrderStatus.fromApiJson('PREPARING'), OrderStatus.preparing);
    // Regression: 'READY_FOR_PICKUP' used to parse as `placed` because
    // readyForPickup.name.toUpperCase() never matches the underscored API
    // value — ready orders showed the wrong status and never notified.
    expect(
      OrderStatus.fromApiJson('READY_FOR_PICKUP'),
      OrderStatus.readyForPickup,
    );
    expect(OrderStatus.fromApiJson('COMPLETED'), OrderStatus.completed);
    expect(OrderStatus.fromApiJson('CANCELLED'), OrderStatus.cancelled);
    expect(OrderStatus.fromApiJson('ready_for_pickup'),
        OrderStatus.readyForPickup);
    expect(OrderStatus.fromApiJson('SOMETHING_NEW'), OrderStatus.placed);
  });
}
