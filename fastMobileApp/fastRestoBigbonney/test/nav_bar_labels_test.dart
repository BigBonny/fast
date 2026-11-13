import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fast_resto_bigbonney/theme.dart';
import 'package:fast_resto_bigbonney/widgets/fast_ui.dart';

/// The customer bar showed "Restaura…" / "Comman…" in French on narrow
/// phones. Labels must now be shown in full (scaled down if needed).
void main() {
  for (final width in [320.0, 360.0, 390.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('French nav labels fit at ${width}dp, text x$scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width * 3, 800 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            theme: FASTTheme.light(),
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 800),
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(
                bottomNavigationBar: FastNavBar(
                  calm: true,
                  calmGradient: FASTBrand.ctaGradient,
                  calmOnPill: FASTBrand.onCta,
                  currentIndex: 0,
                  onTap: (_) {},
                  items: const [
                    FastNavItem(icon: Icons.restaurant, label: 'Restaurants'),
                    FastNavItem(icon: Icons.shopping_bag, label: 'Panier'),
                    FastNavItem(icon: Icons.assignment, label: 'Commandes'),
                    FastNavItem(icon: Icons.group, label: 'Groupe'),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        for (final label in ['Restaurants', 'Panier', 'Commandes', 'Groupe']) {
          final finder = find.text(label);
          expect(finder, findsOneWidget);
          final text = tester.widget<Text>(finder);
          expect(text.overflow, isNot(TextOverflow.ellipsis));
          // Rendered box stays inside the tab (1/4 of the bar).
          final rect = tester.getRect(finder);
          expect(rect.width, lessThanOrEqualTo((width - 24) / 4));
        }
      });
    }
  }
}
