// Layout tests for the customer restaurant page. The embedded map has no
// platform implementation in tests, so `debugSkipMaps` swaps it for a
// plain box; everything else is the real screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fast_resto_bigbonney/models.dart';
import 'package:fast_resto_bigbonney/provider.dart';
import 'package:fast_resto_bigbonney/providers/auth_provider.dart';
import 'package:fast_resto_bigbonney/screens/restaurant_screen.dart';
import 'package:fast_resto_bigbonney/services/map_helper.dart';
import 'package:fast_resto_bigbonney/theme.dart';
import 'package:fast_resto_bigbonney/widgets/fast_parts.dart';

MenuItem _dish(String id, String name, String cat, {bool available = true}) =>
    MenuItem(
      id: id,
      name: name,
      description:
          'Description du plat, assez longue pour tenir sur deux '
          'lignes dans une rangée étroite.',
      price: 12.5,
      image: '',
      category: cat,
      dietaryTags: const [],
      rating: 4.5,
      available: available,
      prepTime: 8,
    );

Restaurant _restaurant({bool reservationOnly = false}) => Restaurant(
  id: 'r1',
  name: 'Le Très Long Nom du Comptoir Gourmand du Haut-Marais et de Belleville',
  description: 'Burgers et frites maison.',
  image: '',
  category: 'burgers',
  rating: 4.7,
  reviewsCount: 128,
  reviews: [
    Review(
      id: 'rv1',
      userName: 'Camille',
      userEmail: '',
      rating: 5,
      comment: 'Prêt pile à mon arrivée.',
      date: '2026-10-28T12:10:00Z',
    ),
  ],
  pickupPrepTime: 12,
  distance: 0.4,
  dietaryOptions: const [],
  menu: [
    _dish('d1', 'Burger du Marais', 'Burgers'),
    _dish(
      'd2',
      'Le Montmartre végétarien aux légumes rôtis et pesto de roquette',
      'Burgers',
    ),
    _dish('d3', 'Cheeseburger', 'Burgers', available: false),
    _dish('d4', 'Citronnade', 'Boissons'),
  ],
  address: '14 rue des Rosiers, 75004 Paris',
  reservationsEnabled: true,
  reservationOnly: reservationOnly,
);

Future<FASTProvider> _pump(
  WidgetTester tester, {
  required ThemeMode mode,
  required Size size,
  bool reservationOnly = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final provider = FASTProvider();
  provider.restaurants.add(_restaurant(reservationOnly: reservationOnly));
  provider.selectRestaurant('r1');
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider.value(value: provider),
      ],
      child: MaterialApp(
        theme: FASTTheme.light(),
        darkTheme: FASTTheme.dark(),
        themeMode: mode,
        home: const Scaffold(body: RestaurantScreen()),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
  return provider;
}

/// Tear the screen down and release the provider's timers.
Future<void> _finish(WidgetTester tester, FASTProvider provider) async {
  await tester.pumpWidget(const SizedBox.shrink());
  provider.dispose();
  await tester.pump(const Duration(seconds: 30));
}

void main() {
  setUp(() => debugSkipMaps = true);
  tearDown(() => debugSkipMaps = false);

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('restaurant page lays out on a narrow phone (${mode.name})', (
      tester,
    ) async {
      final provider = await _pump(
        tester,
        mode: mode,
        size: const Size(320, 640),
      );
      expect(tester.takeException(), isNull);

      // Scroll through the whole page: menu, address block, reviews.
      final scrollable = find.byType(Scrollable).first;
      for (var i = 0; i < 6; i++) {
        await tester.drag(scrollable, const Offset(0, -400));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
      }
      await _finish(tester, provider);
    });
  }

  testWidgets('menu is one column of rows; sold-out rows have no "+"', (
    tester,
  ) async {
    final provider = await _pump(
      tester,
      mode: ThemeMode.light,
      size: const Size(390, 2400),
    );
    expect(find.byType(FastMenuRow), findsNWidgets(4));
    // Three available dishes show a "+"; the sold-out one does not.
    expect(
      find.descendant(
        of: find.byType(FastMenuRow),
        matching: find.byIcon(Icons.add),
      ),
      findsNWidgets(3),
    );
    expect(tester.takeException(), isNull);
    await _finish(tester, provider);
  });

  testWidgets('reservation-only restaurants show no "+" on menu rows', (
    tester,
  ) async {
    final provider = await _pump(
      tester,
      mode: ThemeMode.light,
      size: const Size(390, 2400),
      reservationOnly: true,
    );
    expect(
      find.descendant(
        of: find.byType(FastMenuRow),
        matching: find.byIcon(Icons.add),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    await _finish(tester, provider);
  });
}
