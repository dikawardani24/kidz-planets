import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:kidz_planets/infrastructure/services/planet_narration_provider.dart';
import 'package:kidz_planets/infrastructure/services/planet_narration_service.dart';
import 'package:kidz_planets/presentation/widgets/panels/mission_guide.dart';

import 'helpers/localized_app.dart';

/// Keeps the dialog's replay button from reaching the real audio plugin.
class _SilentPlayer extends AudioPlayer {
  @override
  Future<Duration?> setAsset(
    String assetPath, {
    String? package,
    bool preload = true,
    Duration? initialPosition,
    dynamic tag,
  }) async =>
      const Duration(milliseconds: 10);

  @override
  Future<void> play() async {}

  @override
  Future<void> stop() async {}
}

class _Launcher extends ConsumerWidget {
  const _Launcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => showMissionDialog(context, ref),
            child: const Text('open'),
          ),
        ),
      );
}

void main() {
  Future<void> openMissionDialog(WidgetTester tester, {Locale locale = const Locale('en')}) async {
    await tester.pumpWidget(localizedApp(
      const _Launcher(),
      locale: locale,
      overrides: [
        planetNarrationServiceProvider.overrideWithValue(
          PlanetNarrationService(playerFactory: _SilentPlayer.new),
        ),
      ],
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('the dialog opens on the first clue', (tester) async {
    await openMissionDialog(tester);

    expect(find.textContaining('Look for a blue world'), findsOneWidget);
  });

  testWidgets('offers a bigger clue while one is left', (tester) async {
    await openMissionDialog(tester);

    expect(find.text('Need a bigger clue?'), findsOneWidget);
  });

  testWidgets('revealing a clue swaps the text in place', (tester) async {
    await openMissionDialog(tester);

    await tester.tap(find.text('Need a bigger clue?'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Look for a blue world'), findsNothing);
    expect(find.textContaining('Mercury, Venus, then Earth'), findsOneWidget);
  });

  testWidgets('hides the button once the last clue is out', (tester) async {
    await openMissionDialog(tester);

    await tester.tap(find.text('Need a bigger clue?'));
    await tester.pumpAndSettle();
    expect(find.text('Need a bigger clue?'), findsOneWidget);

    await tester.tap(find.text('Need a bigger clue?'));
    await tester.pumpAndSettle();

    expect(find.text('Need a bigger clue?'), findsNothing);
    expect(find.textContaining('the only world where we have people'),
        findsOneWidget);
  });

  testWidgets('the dialog still fits after the button is added', (tester) async {
    // A short viewport is the case that used to clip the sheet.
    tester.view.physicalSize = const Size(320 * 3, 480 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await openMissionDialog(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Need a bigger clue?'), findsOneWidget);
  });
}
