import 'package:fast_resto_bigbonney/widgets/fast_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('fastIsTablet', () {
    // The breakpoint must key off the device's shorter side: a phone in
    // landscape is wide (~850px) but short (~390px) and must stay a
    // "phone". Tablets are large on both axes.
    test('phones never count as tablets, in either orientation', () {
      expect(fastIsTablet(const Size(390, 844)), isFalse); // iPhone portrait
      expect(fastIsTablet(const Size(844, 390)), isFalse); // iPhone landscape
      expect(fastIsTablet(const Size(412, 915)), isFalse); // large Android
      expect(fastIsTablet(const Size(915, 412)), isFalse);
    });

    test('tablets count in both orientations', () {
      expect(fastIsTablet(const Size(744, 1133)), isTrue); // iPad mini portrait
      expect(fastIsTablet(const Size(1133, 744)), isTrue); // iPad mini landscape
      expect(fastIsTablet(const Size(834, 1194)), isTrue); // iPad 11" portrait
      expect(fastIsTablet(const Size(1194, 834)), isTrue);
      expect(fastIsTablet(const Size(1024, 1366)), isTrue); // iPad Pro portrait
      expect(fastIsTablet(const Size(1366, 1024)), isTrue);
    });

    test('boundary: 600px shortest side is the cutoff', () {
      expect(fastIsTablet(const Size(600, 1000)), isFalse);
      expect(fastIsTablet(const Size(601, 1000)), isTrue);
      expect(fastIsTablet(const Size(1000, 601)), isTrue);
    });
  });

  group('responsive nav widgets', () {
    final items = [
      const FastNavItem(icon: Icons.home, label: 'Home'),
      const FastNavItem(icon: Icons.list, label: 'Orders', badge: 2),
      const FastNavItem(icon: Icons.person, label: 'Profile', dot: true),
    ];

    testWidgets('FastNavRail lays out on iPad landscape without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1366, 1024);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                FastNavRail(
                  currentIndex: 1,
                  items: items,
                  onTap: (_) {},
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(FastNavRail), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('FastNavBar still lays out on a phone', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: FastNavBar(
              currentIndex: 0,
              items: items,
              onTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
