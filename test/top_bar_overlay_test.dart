import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidz_planets/application/state/explorer_state.dart';
import 'package:kidz_planets/application/state/providers.dart';
import 'package:kidz_planets/presentation/widgets/overlays/top_bar.dart';

/// The idle banner names the active mission, which the real provider always
/// has one of before anything is completed.
const missionBanner = 'Mission 1: Find Planet Earth';
const exploredBanner = '✨ Solar system fully explored!';
const spinHint = '👆 Swipe to spin';

/// Pumps the top bar and interaction overlays in the same Stack layout the
/// explorer screen uses, with a simulated status bar inset.
Future<void> pumpOverlays(
  WidgetTester tester, {
  double topInset = 0,
}) async {
  tester.view.padding = FakeViewPadding(top: topInset);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: const [
              Positioned(top: 0, left: 0, right: 0, child: ExplorerTopBar()),
              ExplorerInteractionOverlays(),
            ],
          ),
        ),
      ),
    ),
  );
}

double topOf(WidgetTester tester, String text) =>
    tester.getRect(find.text(text)).top;

double topBarBottom(WidgetTester tester) =>
    tester.getRect(find.text('NASA Space Explorer')).bottom;

void main() {
  testWidgets('mission banner is shown while a mission is active',
      (tester) async {
    await pumpOverlays(tester);

    expect(find.text(missionBanner), findsOneWidget);
    expect(find.text(exploredBanner), findsNothing);
  });

  testWidgets('mission banner sits below the top bar on a device with no inset',
      (tester) async {
    await pumpOverlays(tester);

    expect(topOf(tester, missionBanner),
        greaterThanOrEqualTo(topBarBottom(tester)));
  });

  testWidgets('mission banner sits below the top bar under a notch',
      (tester) async {
    await pumpOverlays(tester, topInset: 47);

    expect(topOf(tester, missionBanner),
        greaterThanOrEqualTo(topBarBottom(tester)),
        reason: 'banner must clear the top bar, not render underneath it');
  });

  testWidgets('mission banner clears the top bar with a large status bar inset',
      (tester) async {
    await pumpOverlays(tester, topInset: 80);

    expect(topOf(tester, missionBanner),
        greaterThanOrEqualTo(topBarBottom(tester)));
  });

  testWidgets('mission banner pushes down as the inset grows', (tester) async {
    await pumpOverlays(tester, topInset: 0);
    final withoutInset = topOf(tester, missionBanner);

    await pumpOverlays(tester, topInset: 47);
    final withInset = topOf(tester, missionBanner);

    expect(withInset, greaterThan(withoutInset));
  });

  testWidgets('spin hint clears the top bar and replaces the mission banner',
      (tester) async {
    await pumpOverlays(tester, topInset: 47);
    expect(find.text(missionBanner), findsOneWidget);

    final context = tester.element(find.byType(ExplorerTopBar));
    ProviderScope.containerOf(context)
        .read(explorerControllerProvider.notifier)
        .selectPlanet('earth');
    await tester.pump();

    expect(topOf(tester, spinHint), greaterThanOrEqualTo(topBarBottom(tester)));
    expect(find.text(missionBanner), findsNothing);

    // Drain the 4s spin-hint timer so no timer outlives the test.
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('the explored banner replaces the mission banner once every '
      'mission is complete', (tester) async {
    await pumpOverlays(tester);
    final context = tester.element(find.byType(ExplorerTopBar));
    final notifier =
        ProviderScope.containerOf(context).read(explorerControllerProvider.notifier);

    // Every mission target in catalog order, so "fully explored" is true rather
    // than just an artefact of the active id pointing at a completed mission.
    for (final planetId in ['earth', 'mars', 'saturn', 'jupiter']) {
      notifier.completeFirstPendingFor(planetId);
    }
    await tester.pump();

    expect(
      ProviderScope.containerOf(context).read(explorerControllerProvider).missions,
      everyElement(isA<MissionState>().having((m) => m.completed, 'completed', isTrue)),
    );
    expect(find.text(exploredBanner), findsOneWidget);
    expect(find.text(missionBanner), findsNothing);

    // Drain the 3s toast timers so none outlives the test.
    await tester.pump(const Duration(seconds: 5));
  });
}
