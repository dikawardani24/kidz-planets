import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidz_planets/application/state/providers.dart';
import 'package:kidz_planets/presentation/widgets/overlays/top_bar.dart';

const hintText = '✨ Tap the Sun or any planet to inspect NASA 3D details';

/// Pumps the top bar and interaction overlays in the same Stack layout the
/// explorer screen uses, with a simulated status bar inset.
Future<void> pumpOverlays(WidgetTester tester, {double topInset = 0}) async {
  tester.view.padding = FakeViewPadding(top: topInset);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: Stack(fit: StackFit.expand, children: const [
          Positioned(top: 0, left: 0, right: 0, child: ExplorerTopBar()),
          ExplorerInteractionOverlays(),
        ]),
      ),
    ),
  ));
}

double topOf(WidgetTester tester, String text) => tester.getRect(find.text(text)).top;

void main() {
  testWidgets('hint sits below the top bar on a device with no inset', (tester) async {
    await pumpOverlays(tester);

    expect(topOf(tester, hintText),
        greaterThanOrEqualTo(tester.getRect(find.text('NASA Space Explorer')).bottom));
  });

  testWidgets('hint sits below the top bar under a notch', (tester) async {
    await pumpOverlays(tester, topInset: 47);

    final topBarBottom = tester.getRect(find.text('NASA Space Explorer')).bottom;
    expect(topOf(tester, hintText), greaterThanOrEqualTo(topBarBottom),
        reason: 'hint must clear the top bar, not render underneath it');
  });

  testWidgets('hint clears the top bar with a large status bar inset', (tester) async {
    await pumpOverlays(tester, topInset: 80);

    final topBarBottom = tester.getRect(find.text('NASA Space Explorer')).bottom;
    expect(topOf(tester, hintText), greaterThanOrEqualTo(topBarBottom));
  });

  testWidgets('hint pushes down as the inset grows', (tester) async {
    await pumpOverlays(tester, topInset: 0);
    final withoutInset = topOf(tester, hintText);

    await pumpOverlays(tester, topInset: 47);
    final withInset = topOf(tester, hintText);

    expect(withInset, greaterThan(withoutInset));
  });

  testWidgets('spin hint clears the top bar and replaces the tap hint', (tester) async {
    await pumpOverlays(tester, topInset: 47);
    expect(find.text(hintText), findsOneWidget);

    final context = tester.element(find.byType(ExplorerTopBar));
    ProviderScope.containerOf(context)
        .read(explorerControllerProvider.notifier)
        .selectPlanet('earth');
    await tester.pump();

    final topBarBottom = tester.getRect(find.text('NASA Space Explorer')).bottom;
    expect(topOf(tester, '👆 Swipe to spin'), greaterThanOrEqualTo(topBarBottom));
    expect(find.text(hintText), findsNothing);

    // Drain the 4s spin-hint timer so no timer outlives the test.
    await tester.pump(const Duration(seconds: 5));
  });
}
