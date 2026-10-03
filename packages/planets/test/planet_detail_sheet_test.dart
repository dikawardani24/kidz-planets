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

  group('focus side rails', () {
    // The rails only exist while a body is focused, so the container is used to
    // put the explorer into that state rather than a tap on the scene, which a
    // widget test has no way to aim.
    Future<ProviderContainer> pumpRails(
      WidgetTester tester, {
      String? selectedPlanetId,
    }) async {
      await tester.pumpWidget(
        localizedApp(
          const Scaffold(
            backgroundColor: Colors.black,
            body: DetailSideRails(),
          ),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DetailSideRails)),
      );
      if (selectedPlanetId != null) {
        container
            .read(explorerControllerProvider.notifier)
            .selectPlanet(selectedPlanetId);
        await tester.pumpAndSettle();
      }
      return container;
    }

    testWidgets('the rails stay hidden until a body is focused', (
      tester,
    ) async {
      await pumpRails(tester);
      expect(find.byType(DetailSideRails), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.byIcon(Icons.refresh), findsNothing);
      expect(find.byIcon(Icons.add), findsNothing);
    });

    testWidgets('focusing a body offers a way back out', (tester) async {
      final container = await pumpRails(tester, selectedPlanetId: 'jupiter');

      // In, out and back to the default framing, all on the one rail.
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.remove), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(container.read(explorerControllerProvider).hasSelection, isTrue);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(
        container.read(explorerControllerProvider).selectedPlanetId,
        isNull,
      );
      expect(
        container.read(explorerControllerProvider).focusedPlanetId,
        isNull,
      );
      // The rail leaves with the focus, so there is nothing left to tap twice.
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('resetting the framing keeps the body focused', (tester) async {
      // The distinction that matters: the refresh button only puts the camera
      // back, so it must not read as the way out.
      final container = await pumpRails(tester, selectedPlanetId: 'jupiter');
      final notifier = container.read(explorerControllerProvider.notifier);

      notifier.adjustDetailZoom(-1.5);
      await tester.pumpAndSettle();
      expect(
        container.read(explorerControllerProvider).detailZoom,
        lessThan(1),
      );

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      expect(container.read(explorerControllerProvider).detailZoom, 1.0);
      expect(
        container.read(explorerControllerProvider).selectedPlanetId,
        'jupiter',
      );

      // `selectPlanet` arms a hint timer; let it fire so the test ends clean.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });
}
