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
import 'package:fast_resto_bigbonney/widgets/intro_carousel.dart';
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

  // Measured centre of the baked Suivant / Commencer pill on each Pro slide
  // (fractions of the 576x1024 artwork). The test taps these exact pixels,
  // so a hit-zone regression on any slide fails it.
  const proPillY = [0.865, 0.89, 0.8825];

  testWidgets('Pro intro slides: baked buttons hit on a tall phone',
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
            images: ProIntroSlides.proImages,
            nextButtonRects: ProIntroSlides.proNextRects,
            dismissedPrefKey: ProIntroSlides.proDismissedKey,
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
    await tester.tapAt(at(0.5, proPillY[0]));
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
    for (var i = 0; i < ProIntroSlides.proImages.length; i++) {
      await tester.tapAt(at(0.5, proPillY[i]));
      await tester.pumpAndSettle();
      expect(controllerOf(tester).page!.round(),
          (i + 1).clamp(0, ProIntroSlides.proImages.length - 1),
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
    expect(
      (await SharedPreferences.getInstance())
          .getBool(ProIntroSlides.proDismissedKey),
      isTrue,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // The client intro is a live-rendered FastIntroCarousel (orange → violet
  // → pink) — real buttons, not baked artwork zones.
  testWidgets('Client intro carousel: buttons navigate, dismissal persists',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
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
          home: Builder(
            builder: (context) => FastIntroCarousel(
              slides: [
                FastIntroSlide(
                  icon: Icons.restaurant,
                  title: tr(context, 'ci1_t'),
                  accentPart: tr(context, 'ci1_ta'),
                  description: tr(context, 'ci1_d'),
                  accent: const Color(0xFFF59E0B),
                  glow: const Color(0xFFF97316),
                ),
                FastIntroSlide(
                  icon: Icons.location_on_outlined,
                  title: tr(context, 'ci2_t'),
                  accentPart: tr(context, 'ci2_ta'),
                  description: tr(context, 'ci2_d'),
                  accent: const Color(0xFFA855F7),
                  glow: const Color(0xFF7C3AED),
                ),
                FastIntroSlide(
                  icon: Icons.bolt,
                  title: tr(context, 'ci3_t'),
                  accentPart: tr(context, 'ci3_ta'),
                  description: tr(context, 'ci3_d'),
                  accent: const Color(0xFFFF0066),
                  glow: const Color(0xFFEC4899),
                ),
              ],
              dismissedPrefKey: ProIntroSlides.clientDismissedKey,
              onDone: () => done++,
              onBack: () => back++,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    // The medallion breathe/orbit animations repeat forever — timed pumps
    // instead of pumpAndSettle (which would never finish).
    const pageAnim = Duration(milliseconds: 500);

    // Page turns need a starting frame, then a clock jump.
    Future<void> turn() async {
      await tester.pump();
      await tester.pump(pageAnim);
      await tester.pump();
    }

    // Suivant → page 2.
    await tester.tap(find.text('Suivant'));
    await turn();
    expect(controllerOf(tester).page!.round(), 1);
    // Retour pill → page 1.
    await tester.tap(find.text('Retour'));
    await turn();
    expect(controllerOf(tester).page!.round(), 0);
    // Retour on the first slide → onBack.
    await tester.tap(find.text('Retour'));
    await tester.pump();
    expect(back, 1);
    // Suivant twice more → last slide shows Commencer, tap → onDone.
    await tester.tap(find.text('Suivant'));
    await turn();
    await tester.tap(find.text('Suivant'));
    await turn();
    expect(controllerOf(tester).page!.round(), 2);
    await tester.tap(find.text('Commencer !'));
    await tester.pump();
    expect(done, 1);
    // Passer also completes (rebuild with a fresh carousel).
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => FASTProvider(),
        child: MaterialApp(
          home: FastIntroCarousel(
            slides: const [
              FastIntroSlide(
                icon: Icons.restaurant,
                title: 'a',
                description: 'd',
                accent: Color(0xFFF59E0B),
                glow: Color(0xFFF97316),
              ),
            ],
            dismissedPrefKey: ProIntroSlides.clientDismissedKey,
            onDone: () => done++,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Passer'));
    await tester.pump();
    expect(done, 2);
    // The don't-show-again chip persists its choice.
    await tester.tap(find.byIcon(Icons.check_box_outline_blank));
    await tester.pump();
    expect(
      (await SharedPreferences.getInstance())
          .getBool(ProIntroSlides.clientDismissedKey),
      isTrue,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
