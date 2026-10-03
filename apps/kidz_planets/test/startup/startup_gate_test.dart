import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:core/l10n.dart';
import 'package:planets/scene.dart';

import 'package:kidz_planets/application/startup/startup_providers.dart';
import 'package:kidz_planets/presentation/screens/startup_gate.dart';

import '../helpers/localized_app.dart';
import 'fake_startup_hooks.dart';

/// Stands in for the real Explorer: the gate test is about *when* the swap
/// happens, and the real screen pulls in a 3D scene view that needs a GPU.
class _StubExplorer extends StatelessWidget {
  const _StubExplorer();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('explorer-ready')));
}

void main() {
  testWidgets(
    'the Explorer stays out of the tree until startup completes and the '
    'child taps the CTA',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final hooks = FakeStartupHooks()
        ..gateOn(SolarSystemStartupTaskId.solarSystem);
      await tester.pumpWidget(
        localizedApp(
          const StartupGate(explorerBuilder: _StubExplorer.new),
          overrides: [startupWith(hooks)],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Phase one: intro visible, no heavy Explorer in the tree, no bar
      // at 100% while the scene task is still held.
      expect(find.text('SPACE ADVENTURE'), findsOneWidget);
      expect(find.text('explorer-ready'), findsNothing);
      expect(find.text('100%'), findsNothing);
      expect(find.text("LET'S EXPLORE!"), findsNothing);

      hooks.openGate(SolarSystemStartupTaskId.solarSystem);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Ready — but the swap waits for the child's tap, not for a timer.
      expect(find.text("LET'S EXPLORE!"), findsOneWidget);
      expect(find.text('explorer-ready'), findsNothing);

      await tester.tap(find.text("LET'S EXPLORE!"));
      await tester.pump();
      // The launch beat: the Explorer is already built underneath the intro,
      // but the intro is still the one on screen.
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('explorer-ready'), findsOneWidget);
      expect(find.text('SPACE ADVENTURE'), findsOneWidget);

      // The handover: both pages alive and crossfading, neither snapped away.
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('explorer-ready'), findsOneWidget);
      expect(find.text('SPACE ADVENTURE'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));
      // One more frame for the gate to drop the finished intro from the tree.
      await tester.pump();

      expect(find.text('explorer-ready'), findsOneWidget);
      expect(find.text('SPACE ADVENTURE'), findsNothing);
    },
  );

  testWidgets('the handover is one animated zoom, not a cut: the CTA is dead on the way '
      'out and the Explorer settles to full size', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final hooks = FakeStartupHooks();
    await tester.pumpWidget(
      localizedApp(
        const StartupGate(explorerBuilder: _StubExplorer.new),
        overrides: [startupWith(hooks)],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    hooks.openGate(SolarSystemStartupTaskId.solarSystem);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text("LET'S EXPLORE!"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 300));

    // Mid-flight the intro is still hit-testable-looking but must not respond:
    // a second tap during the handover cannot restart the swap.
    await tester.tap(find.text("LET'S EXPLORE!"), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    // Straight through: still the Explorer, no bounce back to the intro.
    expect(find.text('explorer-ready'), findsOneWidget);
    expect(find.text('SPACE ADVENTURE'), findsNothing);

    final scale = tester
        .widgetList<ScaleTransition>(find.byType(ScaleTransition))
        .map((t) => t.scale.value)
        .toList();
    expect(
      scale.where((s) => s > 1.0),
      isEmpty,
      reason: 'every page has settled back to full size by now',
    );
  });

  testWidgets(
      'the reveal waits for the Explorer first frame, not just the rocket',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final hooks = FakeStartupHooks()
      ..gateOn(SolarSystemStartupTaskId.solarSystem);
    final container = ProviderContainer(overrides: [startupWith(hooks)]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: kSupportedLocales,
          home: const StartupGate(explorerBuilder: _StubExplorer.new),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    hooks.openGate(SolarSystemStartupTaskId.solarSystem);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text("LET'S EXPLORE!"), findsOneWidget);

    // The primed scene is still compiling its first frame: the flag the real
    // scene view flips on its first presented tick stays down.
    container.read(explorerScenePresentedProvider.notifier).state = false;

    await tester.tap(find.text("LET'S EXPLORE!"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    // The Explorer is already mounted underneath, but the reveal holds: the
    // intro is still fully on screen, so the child never sees a compiling
    // scene or a loading fallback mid-crossfade.
    expect(find.text('explorer-ready'), findsOneWidget);
    expect(find.text('SPACE ADVENTURE'), findsOneWidget);
    // Time passing alone must not start the swap while the first frame is
    // still owed: the handover is readiness-gated, not timer-driven.
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('explorer-ready'), findsOneWidget);
    expect(find.text('SPACE ADVENTURE'), findsOneWidget);

    // First frame presented: the handover runs and settles as usual. (The
    // bare pump lets the freshly started ticker schedule before time moves;
    // starting an animation outside a frame needs one in tests. Production
    // frames run continuously, so this is test-only plumbing.)
    container.read(explorerScenePresentedProvider.notifier).state = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('explorer-ready'), findsOneWidget);
    expect(find.text('SPACE ADVENTURE'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.text('explorer-ready'), findsOneWidget);
    expect(find.text('SPACE ADVENTURE'), findsNothing);
  });

  testWidgets('a failed startup keeps the child on the intro, never a blank '
      'screen', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final hooks = FakeStartupHooks()
      ..failing.add(SolarSystemStartupTaskId.missions);
    await tester.pumpWidget(
      localizedApp(
        const StartupGate(explorerBuilder: _StubExplorer.new),
        overrides: [startupWith(hooks)],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Oh no!'), findsOneWidget);
    expect(find.text('explorer-ready'), findsNothing);
  });
}
