import 'package:flutter_test/flutter_test.dart';
import 'package:kidz_planets/application/state/explorer_state.dart';
import 'package:kidz_planets/presentation/screens/explorer_screen.dart';

ExplorerState _state({
  String? selectedPlanetId = 'earth',
  bool celebrating = false,
}) {
  return ExplorerState(
    selectedPlanetId: selectedPlanetId,
    celebrationTitle: celebrating ? 'Mission 1 Complete!' : null,
    celebrationDescription: celebrating ? 'You discovered Earth.' : null,
  );
}

void main() {
  // A mission success loops its cue for as long as the celebration dialog is up,
  // so nothing else may speak over it. Planet narration runs at 0.92, so it has
  // to wait for the dialog to be dismissed or it buries the cue and reads the
  // dialog out loud.

  test('planet audio is held while the celebration is showing', () {
    expect(
      canStartPlanetAudio(current: _state(celebrating: true)),
      isFalse,
      reason: 'the success cue must be audible on its own',
    );
  });

  test('planet audio starts once the celebration is dismissed', () {
    expect(
      canStartPlanetAudio(current: _state(celebrating: false)),
      isTrue,
    );
  });

  test('a tapped body always speaks, wrong mission pick or not', () {
    // Tapping a planet is how the child explores, so the body that was tapped
    // is described and plays its own ambience regardless of whether it was the
    // mission target. Only the *mission* feedback is the companion's job.
    expect(canStartPlanetAudio(current: _state()), isTrue);
  });

  test('an ordinary selection speaks immediately', () {
    expect(
      canStartPlanetAudio(current: _state()),
      isTrue,
    );
  });

  test('celebrationVisible needs both title and description', () {
    final partial = ExplorerState(celebrationTitle: 'Mission 1 Complete!');
    expect(partial.celebrationVisible, isFalse);
    expect(
      canStartPlanetAudio(current: partial),
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
        canStartPlanetAudio(current: state),
        isNot(state.celebrationVisible),
        reason: 'celebrating=$celebrating',
      );
    }
  });
}
