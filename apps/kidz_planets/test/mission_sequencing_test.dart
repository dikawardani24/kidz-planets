import 'package:flutter_test/flutter_test.dart';

import 'package:kidz_planets/presentation/screens/explorer_screen.dart';
import 'package:mission/state.dart';

import 'helpers/app_messages.dart';

MissionProgressState _state({bool celebrating = false}) {
  return MissionProgressState(
    celebrationTitle: celebrating ? TestMessages.title : null,
    celebrationDescription: celebrating ? TestMessages.description : null,
  );
}

void main() {
  // A mission success loops its cue for as long as the celebration dialog is up,
  // so nothing else may speak over it. Planet narration runs at 0.92, so it has
  // to wait for the dialog to be dismissed or it buries the cue and reads the
  // dialog out loud.

  test('planet audio is held while the celebration is showing', () {
    expect(
      canStartPlanetAudio(
        celebrationVisible: _state(celebrating: true).celebrationVisible,
      ),
      isFalse,
      reason: 'the success cue must be audible on its own',
    );
  });

  test('planet audio starts once the celebration is dismissed', () {
    expect(
      canStartPlanetAudio(
        celebrationVisible: _state(celebrating: false).celebrationVisible,
      ),
      isTrue,
    );
  });

  test('a tapped body always speaks, wrong mission pick or not', () {
    // Tapping a planet is how the child explores, so the body that was tapped
    // is described and plays its own ambience regardless of whether it was the
    // mission target. Only the *mission* feedback is the companion's job.
    expect(canStartPlanetAudio(celebrationVisible: false), isTrue);
  });

  test('an ordinary selection speaks immediately', () {
    expect(canStartPlanetAudio(celebrationVisible: false), isTrue);
  });

  test('celebrationVisible needs both title and description', () {
    final partial = const MissionProgressState(
      celebrationTitle: TestMessages.title,
    );
    expect(partial.celebrationVisible, isFalse);
    expect(
      canStartPlanetAudio(celebrationVisible: partial.celebrationVisible),
      isTrue,
      reason: 'a half-raised celebration must not stall the voice forever',
    );
  });

  test('the gate agrees with celebrationVisible in both directions', () {
    // The loop keeps running until celebrationVisible goes false, so a
    // disagreement between the gate and the dialog would either clip the cue
    // or leave it playing after the dialog is gone.
    for (final celebrating in [true, false]) {
      final state = _state(celebrating: celebrating);
      expect(
        canStartPlanetAudio(celebrationVisible: state.celebrationVisible),
        isNot(state.celebrationVisible),
        reason: 'celebrating=$celebrating',
      );
    }
  });
}
