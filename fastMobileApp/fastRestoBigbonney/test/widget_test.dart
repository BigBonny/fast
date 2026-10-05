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

  test('Automatic daylight respects seasons rather than fixed evening hours', () {
    const paris = LatLng(48.8566, 2.3522);
    expect(FASTProvider.isDaylightAt(DateTime.utc(2026, 12, 21, 16, 30), paris), isFalse);
    expect(FASTProvider.isDaylightAt(DateTime.utc(2026, 6, 21, 18, 30), paris), isTrue);
    expect(FASTProvider.isDaylightAt(DateTime.utc(2026, 6, 21, 0), paris), isFalse);
  });

  test('UserData restores nested guest assignment', () {
    final user = UserData.fromJson({
      'id': 'guest-test', 'name': 'Guest', 'email': 'guest@example.test',
      'role': 'GUEST', 'staffAssignment': {
        'restaurantId': 'restaurant-test', 'staffRole': 'GUEST',
      },
    });
    expect(user.restaurantId, 'restaurant-test');
    expect(user.staffRole, 'GUEST');
  });

  testWidgets('Translations can be read from button callbacks', (tester) async {
    SharedPreferences.setMockInitialValues({});
    String? label;
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => FASTProvider(),
      child: MaterialApp(home: Builder(builder: (context) => ElevatedButton(
        onPressed: () => label = tr(context, 'logout'),
        child: const Text('Translate'),
      ))),
    ));
    await tester.pump();
    await tester.tap(find.text('Translate'));
    expect(tester.takeException(), isNull);
    expect(label, isNotEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
