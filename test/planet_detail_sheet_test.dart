import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidz_planets/application/state/providers.dart';
import 'package:kidz_planets/data/datasources/planet_catalog.dart';
import 'package:kidz_planets/presentation/widgets/panels/planet_detail_sheet.dart';

/// Mirrors the explorer's production placement: a 16px inset on both sides,
/// 88px above the bottom nav, capped at 290 tall.
Future<void> pumpSheet(WidgetTester tester, String planetId,
    {Size screen = const Size(360, 640)}) async {
  tester.view.physicalSize = screen * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);

  final planet =
      PlanetCatalog.planets.firstWhere((p) => p.id == planetId);

  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          Positioned(
            left: 16,
            right: 16,
            bottom: 88,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 290),
              child: PlanetDetailSheet(planet: planet),
            ),
          ),
        ]),
      ),
    ),
  ));
  // Let the AnimatedSize settle on its final size.
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('detail sheet fits for every planet', (tester) async {
    for (final planet in PlanetCatalog.planets) {
      await pumpSheet(tester, planet.id);
      expect(tester.takeException(), isNull,
          reason: '${planet.id} overflows the sheet');
    }
  });

  testWidgets('detail sheet fits on a short viewport', (tester) async {
    // Little vertical room: the sheet has to give up height, not overflow.
    for (final planet in PlanetCatalog.planets) {
      await pumpSheet(tester, planet.id, screen: const Size(360, 520));
      expect(tester.takeException(), isNull,
          reason: '${planet.id} overflows on a short viewport');
    }
  });

  testWidgets('detail sheet fits with a long hotspot override shown',
      (tester) async {
    await pumpSheet(tester, 'saturn');

    final container = ProviderScope.containerOf(
        tester.element(find.byType(PlanetDetailSheet)));
    final longest = PlanetCatalog.planets
        .expand((p) => p.hotspots)
        .reduce((a, b) => a.description.length > b.description.length ? a : b);
    container
        .read(explorerControllerProvider.notifier)
        .showHotspot(longest);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('detail sheet fits while collapsed and while expanded',
      (tester) async {
    await pumpSheet(tester, 'jupiter');
    final container = ProviderScope.containerOf(
        tester.element(find.byType(PlanetDetailSheet)));

    container.read(explorerControllerProvider.notifier).toggleDetailCard();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull,
        reason: 'collapsing the card must not overflow');

    container.read(explorerControllerProvider.notifier).toggleDetailCard();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull,
        reason: 're-expanding the card must not overflow');
  });
}
