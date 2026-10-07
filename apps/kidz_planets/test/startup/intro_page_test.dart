import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kidz_planets/application/startup/startup_providers.dart';
import 'package:kidz_planets/presentation/screens/intro/intro_page.dart';

import '../helpers/localized_app.dart';
import 'fake_startup_hooks.dart';

/// Pumps the intro under [hooks] and lets the first frame land.
///
/// The test surface is stretched to a tall portrait phone: the intro is a
/// scrolling column, and a tap on the completion CTA needs it inside the
/// viewport rather than a scroll away.
Future<void> pumpIntro(
  WidgetTester tester,
  FakeStartupHooks hooks, {
  void Function()? onEnter,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    localizedApp(
      IntroPage(onEnterExplorer: onEnter ?? () {}),
      overrides: [startupWith(hooks)],
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('the intro is the first thing a child sees', (tester) async {
    final hooks = FakeStartupHooks()
      ..gateOn(SolarSystemStartupTaskId.core)
      ..gateOn(SolarSystemStartupTaskId.solarSystem)
      ..gateOn(SolarSystemStartupTaskId.missions)
      ..gateOn(SolarSystemStartupTaskId.companion)
      ..gateOn(SolarSystemStartupTaskId.sounds)
      ..gateOn(SolarSystemStartupTaskId.moons);
    await pumpIntro(tester, hooks);

    // Branding, title, rocket and bar — the prototype's hierarchy.
    expect(find.text('Kidz Planets Adventure'), findsOneWidget);
    expect(find.text('SPACE ADVENTURE'), findsOneWidget);
    expect(find.text('🚀'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);

    // Nothing finished: no completion state, no failure state.
    expect(find.text("LET'S EXPLORE!"), findsNothing);
    expect(find.text('Oh no!'), findsNothing);
  });

  testWidgets('the bar tracks real work and hits 100% only at the end', (
    tester,
  ) async {
    // Gating the first (serial) task holds the pipeline before any later
    // level can overwrite the current-task copy: with every required task
    // unfinished the bar is held and the completion CTA stays hidden —
    // exactly as real startup work in progress would hold it. Moons are
    // lazy and never gate the bar.
    final hooks = FakeStartupHooks()..gateOn(SolarSystemStartupTaskId.core);
    await pumpIntro(tester, hooks);

    // Held work: never 100%, never the completion state.
    expect(find.text('100%'), findsNothing);
    expect(find.text("LET'S EXPLORE!"), findsNothing);
    // Not stuck at zero either: the gated task reported and owns its slice.
    expect(find.text('0%'), findsNothing);

    hooks.openGate(SolarSystemStartupTaskId.core);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('100%'), findsOneWidget);
    expect(find.text('✨ YOUR UNIVERSE IS READY! ✨'), findsOneWidget);
    expect(find.text('"✨ YOUR UNIVERSE IS READY! ✨"'), findsOneWidget);
    expect(find.text("LET'S EXPLORE!"), findsOneWidget);
    expect(find.text('Welcome aboard, Explorer!'), findsOneWidget);
  });

  testWidgets('a failure shows the kid-friendly retry, and retry recovers', (
    tester,
  ) async {
    final hooks = FakeStartupHooks()
      ..failing.add(SolarSystemStartupTaskId.solarSystem);
    await pumpIntro(tester, hooks);

    // The failure state: plain sentences, never the thrown exception. The
    // modal dialog shouts over the inline card, so both read the same copy.
    expect(find.text('Oh no!'), findsNWidgets(2));
    expect(
      find.text('Something went wrong while preparing your space adventure.'),
      findsNWidgets(2),
    );
    expect(find.text('🔄 TRY AGAIN'), findsNWidgets(2));
    expect(find.textContaining('startup failure'), findsNothing);
    expect(find.text("LET'S EXPLORE!"), findsNothing);

    hooks.failing.clear();
    // The dialog's retry: the route on top owns the dismissible one.
    final dialogRetry = find.descendant(
      of: find.byType(Dialog),
      matching: find.text('🔄 TRY AGAIN'),
    );
    expect(dialogRetry, findsOneWidget);
    await tester.tap(dialogRetry);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Oh no!'), findsNothing);
    expect(find.text('🔄 TRY AGAIN'), findsNothing);
    expect(find.text("LET'S EXPLORE!"), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('the completion CTA hands over after its launch beat', (
    tester,
  ) async {
    var entered = false;
    final hooks = FakeStartupHooks();
    await pumpIntro(tester, hooks, onEnter: () => entered = true);
    expect(find.text("LET'S EXPLORE!"), findsOneWidget);

    await tester.tap(find.text("LET'S EXPLORE!"));
    // The rocket climbs first; the swap lands after the launch beat.
    await tester.pump();
    expect(entered, isFalse);
    await tester.pump(const Duration(milliseconds: 700));
    expect(entered, isTrue);
  });
}
