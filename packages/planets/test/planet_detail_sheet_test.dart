import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets/data.dart';
import 'package:planets/state.dart';
import 'package:planets/widgets.dart';

import 'helpers/localized_app.dart';

/// Mirrors the explorer's production placement: a 16px inset on both sides,
/// 88px above the bottom nav, capped at 290 tall.
Future<void> pumpSheet(
  WidgetTester tester,
  String planetId, {
  Size screen = const Size(360, 640),
}) async {
  tester.view.physicalSize = screen * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);

  final planet = PlanetCatalog.planets.firstWhere((p) => p.id == planetId);

  await tester.pumpWidget(
    localizedApp(
      Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned(
              left: 16,
              right: 16,
              bottom: 88,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 290),
                child: PlanetDetailSheet(planet: planet),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  // Let the AnimatedSize settle on its final size.
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('detail sheet fits for every planet', (tester) async {
    for (final planet in PlanetCatalog.planets) {
      await pumpSheet(tester, planet.id);
      expect(
        tester.takeException(),
        isNull,
        reason: '${planet.id} overflows the sheet',
      );
    }
  });

  testWidgets('detail sheet fits on a short viewport', (tester) async {
    // Little vertical room: the sheet has to give up height, not overflow.
    for (final planet in PlanetCatalog.planets) {
      await pumpSheet(tester, planet.id, screen: const Size(360, 520));
      expect(
        tester.takeException(),
        isNull,
        reason: '${planet.id} overflows on a short viewport',
      );
    }
  });

  testWidgets('detail sheet fits with a long hotspot override shown', (
    tester,
  ) async {
    await pumpSheet(tester, 'saturn');

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanetDetailSheet)),
    );
    // The longest description in the whole catalogue, to check the sheet
    // reflows rather than clipping. Carried with its owner because a hotspot
    // is only identified by a slug, and slugs repeat across planets.
    final longest = PlanetCatalog.planets
        .expand((p) => p.hotspots)
        .reduce((a, b) => a.description.length > b.description.length ? a : b);
    final longestPlanet = PlanetCatalog.planets.firstWhere(
      (p) => p.hotspots.contains(longest),
    );
    container
        .read(explorerControllerProvider.notifier)
        .showHotspot(longest, planetId: longestPlanet.id);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('detail sheet fits while collapsed and while expanded', (
    tester,
  ) async {
    await pumpSheet(tester, 'jupiter');
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanetDetailSheet)),
    );

    container.read(explorerControllerProvider.notifier).toggleDetailCard();
    await tester.pumpAndSettle();
    expect(
      tester.takeException(),
      isNull,
      reason: 'collapsing the card must not overflow',
    );

    container.read(explorerControllerProvider.notifier).toggleDetailCard();
    await tester.pumpAndSettle();
    expect(
      tester.takeException(),
      isNull,
      reason: 're-expanding the card must not overflow',
    );
  });
}
