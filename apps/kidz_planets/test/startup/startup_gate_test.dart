import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('explorer-ready'), findsOneWidget);
      expect(find.text('SPACE ADVENTURE'), findsNothing);
    },
  );

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
