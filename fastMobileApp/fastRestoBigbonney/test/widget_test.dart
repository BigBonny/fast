// test/widget_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fast_resto_bigbonney/main.dart';
import 'package:fast_resto_bigbonney/provider.dart';
import 'package:fast_resto_bigbonney/providers/auth_provider.dart';
import 'package:fast_resto_bigbonney/resto_provider.dart';
import 'package:fast_resto_bigbonney/models/auth_models.dart';
import 'package:fast_resto_bigbonney/l10n/tr.dart';
import 'package:fast_resto_bigbonney/screens/home_screen.dart';
import 'package:fast_resto_bigbonney/screens/resto/pro_intro_slides.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets('App landing screen smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'fast_onboarding_done': true});
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) => AuthProvider()),
          ChangeNotifierProvider(create: (context) => FASTProvider()),
          ChangeNotifierProvider(create: (context) => RestoProvider()),
        ],
        child: const FASTApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    // Verify that the brand title FAST is visible
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, contains('FAST'));
  });

  test(
    'Automatic daylight respects seasons rather than fixed evening hours',
    () {
      const paris = LatLng(48.8566, 2.3522);
      expect(
        FASTProvider.isDaylightAt(DateTime.utc(2026, 12, 21, 16, 30), paris),
        isFalse,
      );
      expect(
        FASTProvider.isDaylightAt(DateTime.utc(2026, 6, 21, 18, 30), paris),
        isTrue,
      );
      expect(
        FASTProvider.isDaylightAt(DateTime.utc(2026, 6, 21, 0), paris),
        isFalse,
      );
    },
  );

  test('UserData restores nested guest assignment', () {
    final user = UserData.fromJson({
      'id': 'guest-test',
      'name': 'Guest',
      'email': 'guest@example.test',
      'role': 'GUEST',
      'staffAssignment': {
        'restaurantId': 'restaurant-test',
        'staffRole': 'GUEST',
      },
    });
    expect(user.restaurantId, 'restaurant-test');
    expect(user.staffRole, 'GUEST');
  });

  test('Favorites are scoped per account, not shared on one device', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Seed the pre-fix device-wide key — user A inherits it once via the
    // migration, then it must be removed so user B never sees it.
    SharedPreferences.setMockInitialValues({
      'fast_favorites': '["resto-legacy"]',
    });
    const settle = Duration(milliseconds: 50);
    final provider = FASTProvider();
    await Future<void>.delayed(settle);

    // Log in as user A — migrates the legacy device list once.
    provider.resetSession();
    provider.syncFromAuth(
      id: 'user-a',
      name: 'A',
      email: 'a@test.dev',
      phone: '',
    );
    await Future<void>.delayed(settle);
    expect(provider.isFavorite('resto-legacy'), isTrue);

    provider.toggleFavorite('resto-a');
    await Future<void>.delayed(settle);
    expect(provider.isFavorite('resto-a'), isTrue);

    // Log in as user B on the same device — must NOT see A's favorites
    // or the already-migrated legacy list.
    provider.resetSession();
    provider.syncFromAuth(
      id: 'user-b',
      name: 'B',
      email: 'b@test.dev',
      phone: '',
    );
    await Future<void>.delayed(settle);
    expect(provider.isFavorite('resto-a'), isFalse);
    expect(provider.isFavorite('resto-legacy'), isFalse);

    // Back to user A — their list is intact.
    provider.resetSession();
    provider.syncFromAuth(
      id: 'user-a',
      name: 'A',
      email: 'a@test.dev',
      phone: '',
    );
    await Future<void>.delayed(settle);
    expect(provider.isFavorite('resto-a'), isTrue);
    expect(provider.isFavorite('resto-legacy'), isTrue);

    // The legacy device-wide key was migrated away, not shared.
    expect(
      (await SharedPreferences.getInstance()).getString('fast_favorites'),
      isNull,
    );
  });

  testWidgets('Home hero lays out without errors (no black screen)', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => FASTProvider()),
        ],
        child: const MaterialApp(home: Scaffold(body: HomeScreen())),
      ),
    );
    await tester.pump();
    // A layout exception here renders a blank page in release builds.
    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Translations can be read from button callbacks', (tester) async {
    SharedPreferences.setMockInitialValues({});
    String? label;
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => FASTProvider(),
        child: MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => label = tr(context, 'logout'),
              child: const Text('Translate'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Translate'));
    expect(tester.takeException(), isNull);
    expect(label, isNotEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Measured centre of the baked Suivant / Commencer / C'est parti pill on
  // each slide (fractions of the 576x1024 artwork). The test taps these
  // exact pixels, so a hit-zone regression on any slide fails it.
  const proPillY = [0.905, 0.877, 0.902, 0.904];
  const clientPillY = [0.886, 0.866, 0.866, 0.906];

  for (final set in [
    (name: 'Pro', images: ProIntroSlides.proImages,
     rects: ProIntroSlides.proNextRects, pills: proPillY,
     key: ProIntroSlides.proDismissedKey),
    (name: 'client', images: ProIntroSlides.clientImages,
     rects: ProIntroSlides.clientNextRects, pills: clientPillY,
     key: ProIntroSlides.clientDismissedKey),
  ]) {
    testWidgets('${set.name} intro slides: baked buttons hit on a tall phone',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      // 9:19.5 phone — the 9:16 artwork must letterbox, not crop.
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      var done = 0, back = 0;
      PageController controllerOf(WidgetTester t) =>
          t.widget<PageView>(find.byType(PageView)).controller!;
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => FASTProvider(),
          child: MaterialApp(
            home: ProIntroSlides(
              images: set.images,
              nextButtonRects: set.rects,
              dismissedPrefKey: set.key,
              onDone: () => done++,
              onBack: () => back++,
            ),
          ),
        ),
      );
      await tester.pump();

      final fitted = applyBoxFit(
        BoxFit.contain,
        const Size(576, 1024),
        const Size(1080, 2340),
      ).destination;
      expect(fitted.width, 1080);
      expect(fitted.height, lessThan(2340));
      final top = (2340 - fitted.height) / 2;
      Offset at(double fx, double fy) =>
          Offset(fx * fitted.width, top + fy * fitted.height);

      // Pill on slide 1 → page 2.
      await tester.tapAt(at(0.5, set.pills[0]));
      await tester.pumpAndSettle();
      expect(controllerOf(tester).page!.round(), 1);
      // Retour → back to page 1.
      await tester.tapAt(at(0.12, 0.03));
      await tester.pumpAndSettle();
      expect(controllerOf(tester).page!.round(), 0);
      // Retour on first slide → onBack.
      await tester.tapAt(at(0.12, 0.03));
      await tester.pump();
      expect(back, 1);
      // Passer → onDone from anywhere.
      await tester.tapAt(at(0.9, 0.03));
      await tester.pump();
      expect(done, 1);
      // Each slide's own pill advances; the last one completes.
      for (var i = 0; i < set.images.length; i++) {
        await tester.tapAt(at(0.5, set.pills[i]));
        await tester.pumpAndSettle();
        expect(controllerOf(tester).page!.round(),
            (i + 1).clamp(0, set.images.length - 1),
            reason: 'pill on slide ${i + 1} should advance');
      }
      expect(done, 2);
      // Page dots / counter row (y≈0.95) must not be covered by the chip.
      final chip = find.byIcon(Icons.check_box_outline_blank);
      expect(chip, findsOneWidget);
      expect(tester.getTopLeft(chip).dy,
          greaterThan(top + 0.975 * fitted.height));
      await tester.tap(chip);
      await tester.pump();
      expect((await SharedPreferences.getInstance()).getBool(set.key), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
