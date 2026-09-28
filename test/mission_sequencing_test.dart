import 'package:flutter_test/flutter_test.dart';
import 'package:kidz_planets/application/state/explorer_state.dart';
import 'package:kidz_planets/presentation/screens/explorer_screen.dart';

ExplorerState _state({
  String? selectedPlanetId = 'earth',
  bool celebrating = false,
  int wrongSelectionKey = 0,
}) {
  return ExplorerState(
    selectedPlanetId: selectedPlanetId,
    celebrationTitle: celebrating ? 'Mission 1 Complete!' : null,
    celebrationDescription: celebrating ? 'You discovered Earth.' : null,
    wrongSelectionKey: wrongSelectionKey,
  );
}

void main() {
  // A mission success plays its own 0.65 cue while the celebration dialog is
  // up. Planet narration runs at 0.92, so it has to wait for the dialog to be
  // dismissed or it buries the cue and reads the dialog out loud.

  test('planet audio is held while the celebration is showing', () {
    expect(
      canStartPlanetAudio(current: _state(celebrating: true), wrongSelectionKeyAtSelect: 0),
      isFalse,
      reason: 'the success cue must be audible on its own',
    );
  });

  test('planet audio starts once the celebration is dismissed', () {
    expect(
      canStartPlanetAudio(
        current: _state(celebrating: false),
        wrongSelectionKeyAtSelect: 0,
      ),
      isTrue,
    );
  });

  test('a wrong pick leaves the mission hint as the last word', () {
    // wrongSelectionKey was captured before the miss, and _checkMission bumped
    // it, so the hint replay for the mission body already owns the voice.
    expect(
      canStartPlanetAudio(
        current: _state(wrongSelectionKey: 1),
        wrongSelectionKeyAtSelect: 0,
      ),
      isFalse,
    );
  });

  test('an ordinary selection speaks immediately', () {
    expect(
      canStartPlanetAudio(current: _state(), wrongSelectionKeyAtSelect: 0),
      isTrue,
    );
  });

  test('celebrationVisible needs both title and description', () {
    final partial = ExplorerState(celebrationTitle: 'Mission 1 Complete!');
    expect(partial.celebrationVisible, isFalse);
    expect(
      canStartPlanetAudio(current: partial, wrongSelectionKeyAtSelect: 0),
      isTrue,
      reason: 'a half-raised celebration must not stall the voice forever',
    );
  });
}
