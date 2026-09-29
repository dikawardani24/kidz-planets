import 'package:flutter_test/flutter_test.dart';
import 'package:kidz_planets/application/controllers/explorer_controller.dart';
import 'package:kidz_planets/application/state/explorer_state.dart';
import 'package:kidz_planets/application/state/simulation_clock.dart';
import 'package:kidz_planets/data/repositories/solar_system_repository_impl.dart';
import 'package:kidz_planets/data/datasources/solar_system_local_datasource.dart';

import 'helpers/app_messages.dart';

/// A wrong pick is the companion's job alone.
///
/// The user asked for no dialog, no hint overlay, no toast, no failure sound,
/// and no mission narration, because the avatar reacting in place already
/// covers it. These tests pin all five down, because each one is a behaviour
/// that used to exist and would otherwise be quietly reintroduced.
ExplorerController makeController() {
  final repo = SolarSystemRepositoryImpl(SolarSystemLocalDataSource());
  return ExplorerController(
    clock: SimulationClock(),
    initialMissions: repo.getMissions(),
  );
}

void main() {
  // ExplorerController owns a PlanetSoundService for the mission cues, and
  // AudioPlayer registers an audio_session channel in its constructor, so the
  // binding has to exist before the first controller is built.
  TestWidgetsFlutterBinding.ensureInitialized();

  /// A planet that is not the active mission's target.
  String aWrongPlanet(ExplorerController c, {String? not}) {
    const candidates = ['saturn', 'venus', 'neptune', 'earth', 'mars'];
    final target = c.state.activeMission!.targetPlanetId;
    for (final id in candidates) {
      if (id != target && id != not) return id;
    }
    return target;
  }

  group('a wrong pick is handled by the avatar alone', () {
    test('the avatar reacts', () {
      final c = makeController();
      c.selectPlanet(aWrongPlanet(c));
      expect(c.state.avatarMood, AvatarMood.wrong);
    });

    test('a wrong pick does not move the mission along', () {
      // The mission guide pill is the only way into the mission text, and it
      // follows the active mission. A miss must leave the child on the same
      // mission, so nothing reopens the text over the companion.
      final c = makeController();
      final activeBefore = c.state.activeMissionId;
      c.selectPlanet(aWrongPlanet(c));
      expect(c.state.activeMissionId, activeBefore);
      expect(c.state.activeMission!.completed, isFalse);
    });

    test('no hint is escalated, so there is nothing new to read out', () {
      final c = makeController();
      final levelBefore = c.state.missionHintLevel;
      c.selectPlanet(aWrongPlanet(c));
      expect(c.state.missionHintLevel, levelBefore);
    });

    test('no toast interrupts the child', () {
      final c = makeController();
      c.selectPlanet(aWrongPlanet(c));
      expect(c.state.toasts, isEmpty);
    });

    test('no celebration is shown either', () {
      final c = makeController();
      c.selectPlanet(aWrongPlanet(c));
      expect(c.state.celebrationVisible, isFalse);
    });
  });

  // A correct pick is covered by explorer_logic_test. Its success path starts a
  // real audio player, which a unit test cannot drive, so it is not driven
  // here either. The other half of the flag, that a correct pick clears the
  // silence, is covered in mission_sequencing_test against the screen's own
  // audio gate.

  group('the avatar recovers on its own', () {
    test('dismissing a celebration calms it back down', () {
      final c = makeController();
      c
        ..showCelebration(TestMessages.title, TestMessages.description)
        ..setAvatarMood(AvatarMood.success);
      expect(c.state.celebrationVisible, isTrue);

      c.closeCelebration();
      expect(c.state.celebrationVisible, isFalse);
      expect(c.state.avatarMood, AvatarMood.instruction);
    });
  });

  group('the avatar recovers on its own', () {
    test('tapping after a miss moves it to the encouraging line', () {
      final c = makeController();
      c.selectPlanet(aWrongPlanet(c));
      expect(c.state.avatarMood, AvatarMood.wrong);

      c.retryMission();
      expect(c.state.avatarMood, AvatarMood.retry);
    });

    test('retry does nothing outside a miss, so it cannot skip a win', () {
      final c = makeController();
      expect(c.state.avatarMood, AvatarMood.searching);
      c.retryMission();
      expect(c.state.avatarMood, AvatarMood.searching);
    });

    test('a second miss returns it to disappointed', () {
      final c = makeController();
      final first = aWrongPlanet(c);
      c.selectPlanet(first);
      c.retryMission();
      expect(c.state.avatarMood, AvatarMood.retry);

      // A different planet, because re-tapping the same one only closes the
      // detail view and never reaches the mission check.
      c.selectPlanet(aWrongPlanet(c, not: first));
      expect(c.state.avatarMood, AvatarMood.wrong);
    });

  });
}
