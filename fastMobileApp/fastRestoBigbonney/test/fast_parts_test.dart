// Widget tests for the shared customer pieces in lib/widgets/fast_parts.dart.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fast_resto_bigbonney/theme.dart';
import 'package:fast_resto_bigbonney/widgets/fast_parts.dart';

Widget _host(
  Widget child, {
  ThemeMode mode = ThemeMode.light,
  TextDirection direction = TextDirection.ltr,
  double width = 360,
}) {
  return MaterialApp(
    theme: FASTTheme.light(),
    darkTheme: FASTTheme.dark(),
    themeMode: mode,
    home: Directionality(
      textDirection: direction,
      child: Scaffold(
        body: Center(
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );
}

const _longName =
    'Tartine de chèvre chaud au miel de lavande et noix caramélisées maison';

void main() {
  group('FastMenuRow', () {
    testWidgets('long name wraps to two lines without overflow, no photo', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          FastMenuRow(
            name: _longName,
            description: 'Pain de campagne, chèvre, miel, noix, roquette.',
            price: 12.5,
            image: '',
            prepMinutes: 8,
            onTap: () => taps++,
          ),
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('€12.50'), findsOneWidget);
      expect(find.text('~8 min'), findsOneWidget);
      // No photo: the "+" still shows, standing alone.
      expect(find.byIcon(Icons.add), findsOneWidget);

      await tester.tap(find.text(_longName));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('sold-out item shows the tag and hides the "+"', (tester) async {
      await tester.pumpWidget(
        _host(
          FastMenuRow(
            name: 'Croque',
            description: '',
            price: 7,
            image: '',
            available: false,
            unavailableLabel: 'Épuisé',
            onTap: () {},
          ),
        ),
      );
      expect(find.text('ÉPUISÉ'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsNothing);
    });

    testWidgets('reservation-only rows hide the "+"', (tester) async {
      await tester.pumpWidget(
        _host(
          FastMenuRow(
            name: 'Menu dégustation',
            description: '',
            price: 60,
            image: '',
            showAdd: false,
            onTap: () {},
          ),
        ),
      );
      expect(find.byIcon(Icons.add), findsNothing);
    });

    testWidgets('lays out right-to-left and in dark mode', (tester) async {
      await tester.pumpWidget(
        _host(
          FastMenuRow(
            name: 'شاورما دجاج',
            description: 'خبز، دجاج، ثوم، مخلل',
            price: 9.9,
            image: '',
            onTap: () {},
          ),
          mode: ThemeMode.dark,
          direction: TextDirection.rtl,
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('€9.90'), findsOneWidget);
    });
  });

  group('FastStepper', () {
    testWidgets('never goes below min and reports each change', (tester) async {
      var value = 1;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) => FastStepper(
              value: value,
              onChanged: (v) => setState(() => value = v),
            ),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pumpAndSettle();
      expect(value, 1);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(value, 3);

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pumpAndSettle();
      expect(value, 2);
      expect(find.text('2'), findsOneWidget);
    });
  });

  group('FastPickupCode', () {
    testWidgets('shows the code unchanged, on a narrow screen too', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const FastPickupCode(
            code: 'K7QM-FAST',
            label: 'Code de retrait',
            hint: 'Donnez-le au restaurant si le QR ne fonctionne pas',
          ),
          width: 240,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('K7QM-FAST'), findsOneWidget);
      expect(find.text('CODE DE RETRAIT'), findsOneWidget);
    });
  });

  test('fastPriceLabel keeps the app-wide price format', () {
    expect(fastPriceLabel(12.5), '€12.50');
    expect(fastPriceLabel(0), '€0.00');
  });
}
