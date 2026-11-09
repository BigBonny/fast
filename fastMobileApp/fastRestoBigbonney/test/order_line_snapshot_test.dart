import 'package:flutter_test/flutter_test.dart';
import 'package:fast_resto_bigbonney/models.dart';

void main() {
  final liveMenuItem = {
    'id': 'm1',
    'name': 'Burger (renamed)',
    'price': 14.0,
    'isAvailable': true,
  };

  test('order line shows the name and price paid at checkout', () {
    final line = CartItem.fromApiJson({
      'quantity': 2,
      'selectedOptions': '[]',
      'name': 'Burger',
      'unitPrice': 11.5,
      'menuItem': liveMenuItem,
    });
    expect(line.menuItem.name, 'Burger');
    expect(line.menuItem.price, 11.5);
    expect(line.menuItem.id, 'm1');
  });

  test('legacy order line without a snapshot falls back to the menu', () {
    final line = CartItem.fromApiJson({
      'quantity': 1,
      'selectedOptions': '[]',
      'name': null,
      'unitPrice': null,
      'menuItem': liveMenuItem,
    });
    expect(line.menuItem.name, 'Burger (renamed)');
    expect(line.menuItem.price, 14.0);
  });
}
