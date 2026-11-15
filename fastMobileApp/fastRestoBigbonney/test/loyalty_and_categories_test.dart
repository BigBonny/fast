// Loyalty cards, category de-duplication and the search/create field.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fast_resto_bigbonney/models.dart';
import 'package:fast_resto_bigbonney/provider.dart';
import 'package:fast_resto_bigbonney/providers/auth_provider.dart';
import 'package:fast_resto_bigbonney/screens/home_screen.dart';
import 'package:fast_resto_bigbonney/theme.dart';
import 'package:fast_resto_bigbonney/widgets/loyalty_card.dart';
import 'package:fast_resto_bigbonney/widgets/suggest_field.dart';

Restaurant _resto(
  String id,
  String name,
  String category, {
  bool loyalty = false,
}) => Restaurant(
  id: id,
  name: name,
  description: '',
  image: '',
  category: category,
  rating: 4.5,
  reviewsCount: 10,
  reviews: const [],
  pickupPrepTime: 10,
  distance: 0.5,
  dietaryOptions: const [],
  menu: const [],
  address: '1 rue de Paris',
  loyaltyEnabled: loyalty,
  loyaltyThreshold: 10,
  loyaltyReward: loyalty ? 'Un menu offert' : '',
);

Widget _host(Widget child, FASTProvider provider, {ThemeMode? mode}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider.value(value: provider),
    ],
    child: MaterialApp(
      theme: FASTTheme.light(),
      darkTheme: FASTTheme.dark(),
      themeMode: mode ?? ThemeMode.light,
      home: Scaffold(body: child),
    ),
  );
}

/// Unmounts the tree and disposes the provider so no timer outlives
/// the test.
Future<void> _finish(WidgetTester tester, FASTProvider provider) async {
  await tester.pumpWidget(const SizedBox.shrink());
  provider.dispose();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('foldText', () {
    test('ignores case, accents and extra spaces', () {
      expect(foldText('  Crêpes  &  Gaufres '), 'crepes & gaufres');
      expect(foldText('CAFÉ'), foldText('cafe'));
    });
  });

  group('categories', () {
    test('spelling variants map to the built-in category', () {
      for (final label in ['Pizza', 'pizzas', 'PIZZA ', 'Pizzás']) {
        expect(FASTProvider.normalizeCategoryId(label), 'pizza', reason: label);
      }
      expect(FASTProvider.normalizeCategoryId('Cuisine indienne'), 'indien');
      expect(FASTProvider.normalizeCategoryId('Restaurant chinois'), 'chinois');
      expect(FASTProvider.normalizeCategoryId('Sandwicherie'), 'sandwich');
      expect(FASTProvider.normalizeCategoryId('Burgers'), 'burger');
    });

    test('the home strip never shows a category twice', () {
      final provider = FASTProvider();
      provider.restaurants.addAll([
        _resto('a', 'A', 'Pizzas, Congolais'),
        _resto('b', 'B', 'pizza, congolaise'),
        _resto('c', 'C', 'Congolais , Cuisine indienne, Libanais'),
      ]);
      final strip = provider.browseCategories;
      final names = strip.map((c) => foldText(c.name)).toList();
      expect(names.toSet().length, names.length);
      expect(strip.where((c) => c.id == 'pizza').length, 1);
      // One custom chip per custom cuisine, whatever the spelling.
      final custom = strip.where((c) => c.id.startsWith('custom:')).toList();
      expect(custom.map((c) => c.name), ['Congolais', 'Libanais']);
    });

    test('search suggestions ignore accents and list each match once', () {
      final provider = FASTProvider();
      provider.restaurants.add(_resto('a', 'A', 'Crêperie bretonne'));
      provider.setKeyword('crep');
      final ids = provider.getAutocompleteCategories().map((c) => c.id);
      expect(ids, contains('crepes'));
      expect(ids.toSet().length, ids.length);
    });

    test('restaurant search ignores accents', () {
      final provider = FASTProvider();
      provider.restaurants.add(_resto('a', 'Le Café Hélène', 'Café'));
      provider.setKeyword('helene');
      expect(provider.getFilteredRestaurants().single.id, 'a');
    });
  });

  group('suggestMatches', () {
    const options = ['Boissons', 'Desserts', 'Burgers', 'Bowls', 'Entrées'];

    test('names starting with the query come first', () {
      expect(suggestMatches(options, 'b'), ['Boissons', 'Burgers', 'Bowls']);
      expect(suggestMatches(options, 'ss'), ['Boissons', 'Desserts']);
      expect(suggestMatches(options, 'entree'), ['Entrées']);
    });

    test('an existing entry is reused whatever the case or accents', () {
      expect(existingOption(options, 'boissons '), 'Boissons');
      expect(existingOption(options, 'ENTREES'), 'Entrées');
      expect(existingOption(options, 'Tapas'), isNull);
    });
  });

  testWidgets('SuggestField offers existing entries, then creation', (
    tester,
  ) async {
    final provider = FASTProvider();
    final controller = TextEditingController();
    final created = <String>[];
    await tester.pumpWidget(
      _host(
        Padding(
          padding: const EdgeInsets.all(16),
          child: SuggestField(
            controller: controller,
            options: const ['Boissons', 'Desserts'],
            decoration: const InputDecoration(),
            createLabel: (t) => 'Créer « $t »',
            onCreate: created.add,
          ),
        ),
        provider,
      ),
    );
    await tester.tap(find.byType(TextFormField));
    await tester.enterText(find.byType(TextFormField), 'boi');
    await tester.pump();
    expect(find.text('Boissons'), findsOneWidget);
    expect(find.text('Créer « boi »'), findsOneWidget);

    // Typing an existing category in another case offers no duplicate.
    await tester.enterText(find.byType(TextFormField), 'boissons');
    await tester.pump();
    expect(find.text('Créer « boissons »'), findsNothing);
    await tester.tap(find.text('Boissons'));
    await tester.pump();
    expect(controller.text, 'Boissons');

    await tester.enterText(find.byType(TextFormField), 'Tapas');
    await tester.pump();
    await tester.tap(find.text('Créer « Tapas »'));
    await tester.pump();
    expect(created, ['Tapas']);
    await _finish(tester, provider);
  });

  group('loyalty', () {
    test('card parses the backend payload', () {
      final card = LoyaltyCard.fromApiJson({
        'restaurantId': 'r1',
        'restaurantName': 'King Tacos',
        'threshold': 10,
        'reward': 'Un menu offert',
        'stamps': 7,
        'remaining': 3,
        'rewardAvailable': false,
      });
      expect(card.stamps, 7);
      expect(card.remaining, 3);
      expect(card.rewardAvailable, isFalse);
    });

    test('restaurant without a reward has no programme', () {
      expect(_resto('a', 'A', 'Tacos').hasLoyalty, isFalse);
      expect(_resto('a', 'A', 'Tacos', loyalty: true).hasLoyalty, isTrue);
    });

    testWidgets('card shows progress, reward and no overflow', (tester) async {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        final provider = FASTProvider();
        await tester.pumpWidget(
          _host(
            Center(
              child: SizedBox(
                width: 320,
                child: LoyaltyCardView(
                  card: const LoyaltyCard(
                    restaurantId: 'r1',
                    restaurantName:
                        'King Tacos du Haut-Marais et de Belleville',
                    threshold: 10,
                    reward: 'Un menu offert',
                    stamps: 7,
                  ),
                  onUse: () {},
                ),
              ),
            ),
            provider,
            mode: mode,
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Un menu offert'), findsOneWidget);
        expect(
          find.text('Encore 3 commandes avant votre récompense !'),
          findsOneWidget,
        );
        // Not complete yet: no "use" button.
        expect(find.text('Utiliser ma récompense'), findsNothing);
        await _finish(tester, provider);
      }
    });

    testWidgets('a complete card offers to use the reward', (tester) async {
      var used = 0;
      final provider = FASTProvider();
      await tester.pumpWidget(
        _host(
          SingleChildScrollView(
            child: LoyaltyCardView(
              card: const LoyaltyCard(
                restaurantId: 'r1',
                restaurantName: 'King Tacos',
                threshold: 5,
                reward: 'Une boisson offerte',
                stamps: 5,
                rewardAvailable: true,
              ),
              onUse: () => used++,
            ),
          ),
          provider,
        ),
      );
      expect(find.text('Votre récompense vous attend !'), findsOneWidget);
      await tester.tap(find.text('Utiliser ma récompense'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(used, 1);
      await _finish(tester, provider);
    });

    testWidgets('restaurant bubble uses the restaurateur\'s own settings', (
      tester,
    ) async {
      final provider = FASTProvider();
      await tester.pumpWidget(
        _host(
          Center(
            child: SizedBox(
              width: 320,
              child: LoyaltyBubble(
                restaurant: _resto('a', 'King Tacos', 'Tacos', loyalty: true),
              ),
            ),
          ),
          provider,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        find.textContaining(
          'Cumulez 10 commandes et profitez de : Un menu offert',
        ),
        findsOneWidget,
      );
      await _finish(tester, provider);
    });
  });

  testWidgets('home shows the missing-restaurant card without overflow', (
    tester,
  ) async {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final provider = FASTProvider();
      provider.restaurants.addAll([
        _resto('a', 'King Tacos', 'Tacos, Pizzas', loyalty: true),
        _resto('b', 'Chez Momo', 'pizza'),
      ]);
      await tester.pumpWidget(_host(const HomeScreen(), provider, mode: mode));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      expect(find.text('Un resto manque ?'), findsOneWidget);
      expect(find.text('Nom du restaurant'), findsOneWidget);
      await _finish(tester, provider);
    }
  });
}
