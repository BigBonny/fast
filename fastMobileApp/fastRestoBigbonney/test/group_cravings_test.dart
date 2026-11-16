// Group cravings: when the members of a group want different things,
// the restaurants that serve all of them come first.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fast_resto_bigbonney/models.dart';
import 'package:fast_resto_bigbonney/provider.dart';
import 'package:fast_resto_bigbonney/providers/auth_provider.dart';
import 'package:fast_resto_bigbonney/screens/group_screen.dart';
import 'package:fast_resto_bigbonney/screens/home_screen.dart';
import 'package:fast_resto_bigbonney/theme.dart';

MenuItem _dish(String name, {String category = '', bool available = true}) =>
    MenuItem(
      id: name,
      name: name,
      description: '',
      price: 10,
      image: '',
      category: category,
      dietaryTags: const [],
      rating: 4.5,
      available: available,
      prepTime: 8,
    );

Restaurant _resto(
  String id,
  String name, {
  String category = '',
  String description = '',
  List<MenuItem> menu = const [],
}) => Restaurant(
  id: id,
  name: name,
  description: description,
  image: '',
  category: category,
  rating: 4.5,
  reviewsCount: 10,
  reviews: const [],
  pickupPrepTime: 10,
  distance: 0.5,
  dietaryOptions: const [],
  menu: menu,
  address: '1 rue de Paris',
);

Map<String, dynamic> _group(Map<String, String> cravingByUser) => {
  'id': 'g1',
  'status': 'OPEN',
  'members': [
    for (final e in cravingByUser.entries)
      {
        'craving': e.value,
        'user': {'id': e.key, 'name': e.key},
      },
  ],
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final burgerOnly = _resto('b', 'Big Bun', category: 'Burgers');
  final pizzaOnly = _resto('p', 'Napoli', category: 'Pizza');
  final both = _resto(
    'x',
    'Le Comptoir',
    category: 'Brasserie',
    menu: [_dish('Cheeseburger maison'), _dish('Pizza Margherita')],
  );
  final neither = _resto('s', 'Sushi Kyo', category: 'Sushi');

  group('restaurantHasCraving', () {
    test('matches the category, whatever the spelling', () {
      for (final wish in ['burger', 'Burgers', 'BURGER ']) {
        expect(
          FASTProvider.restaurantHasCraving(burgerOnly, wish),
          isTrue,
          reason: wish,
        );
      }
      expect(FASTProvider.restaurantHasCraving(burgerOnly, 'pizza'), isFalse);
    });

    test('matches a dish on the menu', () {
      expect(FASTProvider.restaurantHasCraving(both, 'burger'), isTrue);
      expect(FASTProvider.restaurantHasCraving(both, 'pizzas'), isTrue);
      expect(FASTProvider.restaurantHasCraving(both, 'sushi'), isFalse);
    });

    test('ignores sold-out dishes and descriptions', () {
      final soldOut = _resto(
        'o',
        'Chez Momo',
        description: 'Pas de pizza ici, que des grillades.',
        menu: [_dish('Pizza Regina', available: false)],
      );
      expect(FASTProvider.restaurantHasCraving(soldOut, 'pizza'), isFalse);
    });

    test('an empty craving matches nothing', () {
      expect(FASTProvider.restaurantHasCraving(both, ''), isFalse);
      expect(FASTProvider.restaurantHasCraving(both, ' '), isFalse);
    });
  });

  test('the same wish written twice counts once', () {
    expect(
      FASTProvider.distinctCravings(['Burger', ' burgers ', '', 'Pizza']),
      ['Burger', 'Pizza'],
    );
  });

  group('rankForGroup', () {
    test('restaurants serving every craving come first', () {
      final ranked = FASTProvider.rankForGroup(
        [neither, burgerOnly, pizzaOnly, both],
        ['burger', 'pizza'],
      );
      expect(ranked.map((r) => r.id), ['x', 'b', 'p', 's']);
    });

    test('the incoming order is kept between equals', () {
      final ranked = FASTProvider.rankForGroup(
        [pizzaOnly, neither, burgerOnly],
        ['burger', 'pizza'],
      );
      expect(ranked.map((r) => r.id), ['p', 'b', 's']);
    });

    test('three cravings: two out of three beats one', () {
      final two = _resto(
        't',
        'Duo',
        menu: [_dish('Burger'), _dish('Sushi mix')],
      );
      final ranked = FASTProvider.rankForGroup(
        [burgerOnly, two],
        ['burger', 'pizza', 'sushi'],
      );
      expect(ranked.map((r) => r.id), ['t', 'b']);
    });
  });

  group('provider', () {
    test('a single craving does not reorder anything', () {
      final provider = FASTProvider();
      provider.restaurants.addAll([neither, burgerOnly, both]);
      provider.setActiveGroup(id: 'g1');
      provider.applyGroupPayload(_group({'u1': 'burger', 'u2': ''}));
      expect(provider.groupRankingActive, isFalse);
      expect(provider.getFilteredRestaurants().map((r) => r.id), [
        's',
        'b',
        'x',
      ]);
      provider.dispose();
    });

    test('two different cravings put the common restaurant first', () {
      final provider = FASTProvider();
      provider.restaurants.addAll([neither, burgerOnly, pizzaOnly, both]);
      provider.setActiveGroup(id: 'g1');
      provider.applyGroupPayload(_group({'u1': 'burger', 'u2': 'pizza'}));
      expect(provider.groupRankingActive, isTrue);
      expect(provider.getFilteredRestaurants().first.id, 'x');
      expect(provider.servesWholeGroup(both), isTrue);
      expect(provider.servesWholeGroup(burgerOnly), isFalse);
      // Searching "burger" keeps only burger places, the common one first.
      provider.setKeyword('burger');
      expect(provider.getFilteredRestaurants().map((r) => r.id), ['x', 'b']);
      expect(provider.groupRestaurantSuggestions.map((r) => r.id), [
        'x',
        'b',
        'p',
      ]);
      provider.dispose();
    });

    test('leaving the group restores the normal order', () {
      final provider = FASTProvider();
      provider.restaurants.addAll([neither, both]);
      provider.setActiveGroup(id: 'g1');
      provider.applyGroupPayload(_group({'u1': 'burger', 'u2': 'pizza'}));
      expect(provider.getFilteredRestaurants().first.id, 'x');
      provider.clearActiveGroup();
      expect(provider.groupCravings, isEmpty);
      expect(provider.getFilteredRestaurants().first.id, 's');
      provider.dispose();
    });
  });

  testWidgets('home explains the group order and tags the common place', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final provider = FASTProvider();
    provider.restaurants.addAll([neither, burgerOnly, pizzaOnly, both]);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider.value(value: provider),
        ],
        child: MaterialApp(
          theme: FASTTheme.light(),
          home: const Scaffold(body: HomeScreen()),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Groupe :'), findsNothing);
    // Joining a group happens once the app is up (start-up restores the
    // saved session first).
    provider.setActiveGroup(id: 'g1');
    provider.applyGroupPayload(_group({'u1': 'burger', 'u2': 'pizza'}));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.text('Groupe : burger + pizza'), findsOneWidget);
    // Only the restaurant serving both is tagged.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            (w.data ?? '').toLowerCase() == 'convient à tout le groupe',
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
  });

  testWidgets('group dashboard lists common restaurants; host can switch', (
    tester,
  ) async {
    for (final isHost in [true, false]) {
      tester.view.physicalSize = const Size(360, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final provider = FASTProvider();
      provider.restaurants.addAll([neither, burgerOnly, pizzaOnly, both]);
      final payload = {
        ..._group({'u1': 'burger', 'u2': 'pizza'}),
        'code': 'FAST-K7Q2M9XA',
        'restaurantId': 'b',
        'isHost': isHost,
        'restaurant': {'id': 'b', 'name': 'Big Bun'},
      };
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider.value(value: provider),
          ],
          child: MaterialApp(
            theme: FASTTheme.light(),
            home: GroupScreen(debugGroup: payload),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      provider.setActiveGroup(id: 'g1', restaurantId: 'b');
      provider.applyGroupPayload(payload);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      // The restaurant serving both cravings is listed, with its wishes.
      expect(find.text('Le Comptoir'), findsOneWidget);
      expect(find.text('burger · pizza'), findsOneWidget);
      expect(find.text('Envie : pizza'), findsOneWidget);
      // Only the host gets the buttons to move the group (2 other places).
      expect(find.text('Choisir'), isHost ? findsNWidgets(2) : findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      provider.dispose();
    }
  });
}
