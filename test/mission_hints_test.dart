import 'package:flutter_test/flutter_test.dart';
import 'package:kidz_planets/application/controllers/explorer_controller.dart';
import 'package:kidz_planets/application/state/explorer_state.dart';
import 'package:kidz_planets/application/state/simulation_clock.dart';
import 'package:kidz_planets/data/datasources/solar_system_local_datasource.dart';
import 'package:kidz_planets/domain/entities/mission.dart';

ExplorerController makeController() => ExplorerController(
      clock: SimulationClock(),
      initialMissions: SolarSystemLocalDataSource().getMissions(),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('clueAt', () {
    const mission = MissionState(
      id: 1,
      title: 'Find Earth',
      description: 'our home',
      targetPlanetId: 'earth',
      hints: ['first clue', 'second clue', 'third clue'],
    );

    test('starts at the first clue', () {
      expect(mission.clueAt(0), 'first clue');
    });

    test('each level reveals the next clue', () {
      expect(mission.clueAt(1), 'second clue');
      expect(mission.clueAt(2), 'third clue');
    });

    test('clamps above the last clue instead of throwing', () {
      expect(mission.clueAt(3), 'third clue');
      expect(mission.clueAt(99), 'third clue');
    });

    test('clamps a negative level back to the first clue', () {
      expect(mission.clueAt(-1), 'first clue');
    });

    test('falls back to the description when there are no clues', () {
      const bare = MissionState(
        id: 2,
        title: 'Visit Mars',
        description: 'the red planet',
        targetPlanetId: 'mars',
      );

      expect(bare.clueAt(0), 'the red planet');
      expect(bare.clueAt(5), 'the red planet');
    });
  });

  group('mission content', () {
    final missions = SolarSystemLocalDataSource().getMissions();

    test('every mission has at least two escalating clues', () {
      // One clue is not an escalation, and the dialog only offers the button
      // when there is a further clue to give.
      for (final m in missions) {
        expect(m.hints.length, greaterThanOrEqualTo(2), reason: m.title);
      }
    });

    test('no mission repeats a clue', () {
      // Repeating a clue would make the button look broken.
      for (final m in missions) {
        expect(m.hints.toSet(), hasLength(m.hints.length), reason: m.title);
      }
    });

    test('every clue is a full sentence a child can read aloud', () {
      for (final m in missions) {
        for (final clue in m.hints) {
          expect(clue, isNotEmpty, reason: m.title);
          expect(clue.trim(), endsWith('.'), reason: '${m.title}: $clue');
        }
      }
    });
  });

  group('revealNextHint', () {
    test('starts with no clues given away', () {
      final c = makeController();
      addTearDown(c.dispose);

      expect(c.state.missionHintLevel, 0);
    });

    test('shows the first clue before anything is revealed', () {
      final c = makeController();
      addTearDown(c.dispose);

      expect(c.state.activeMission!.clueAt(c.state.missionHintLevel),
          c.state.activeMission!.hints.first);
    });

    test('advances the level one step at a time', () {
      final c = makeController();
      addTearDown(c.dispose);

      c.revealNextHint();
      expect(c.state.missionHintLevel, 1);

      c.revealNextHint();
      expect(c.state.missionHintLevel, 2);
    });

    test('actually changes the clue that would be read out', () {
      final c = makeController();
      addTearDown(c.dispose);

      final before = c.state.activeMission!.clueAt(c.state.missionHintLevel);
      c.revealNextHint();
      final after = c.state.activeMission!.clueAt(c.state.missionHintLevel);

      expect(after, isNot(before));
    });

    test('saturates at the last clue instead of running off the end', () {
      final c = makeController();
      addTearDown(c.dispose);
      final last = c.state.activeMission!.hints.length - 1;

      for (var i = 0; i < last + 5; i++) {
        c.revealNextHint();
      }

      expect(c.state.missionHintLevel, last);
    });

    test('does nothing once every mission is complete', () {
      final c = makeController();
      addTearDown(c.dispose);
      for (final id in ['earth', 'mars', 'saturn', 'jupiter']) {
        c.selectPlanet(id);
      }
      expect(c.state.activeMissionId, isNull);

      c.revealNextHint();

      expect(c.state.missionHintLevel, 0);
    });

    test('a wrong pick never reveals a clue on its own', () {
      final c = makeController();
      addTearDown(c.dispose);

      c.selectPlanet('saturn');

      expect(c.state.avatarMood, AvatarMood.wrong);
      expect(c.state.missionHintLevel, 0,
          reason: 'the child has to ask, so a miss stays quiet');
    });

    test('the level is held in app state, not in the dialog', () {
      // The dialog reads the level live, so anything that rebuilds or
      // dismisses it must not lose a clue the child already earned.
      final c = makeController();
      addTearDown(c.dispose);

      c.revealNextHint();
      c.revealNextHint();

      c.toggleOrbits();
      c.selectPlanet('saturn');
      c.closeDetail();

      expect(c.state.missionHintLevel, 2);
    });
  });

  group('clues do not carry over to the next mission', () {
    test('a finished mission hands over a fresh clue list', () {
      final c = makeController();
      addTearDown(c.dispose);

      final first = c.state.activeMission!;
      for (var i = 0; i < first.hints.length; i++) {
        c.revealNextHint();
      }
      expect(c.state.missionHintLevel, first.hints.length - 1);

      c.selectPlanet('earth');

      expect(c.state.activeMissionId, 2);
      expect(c.state.missionHintLevel, 0);
      expect(c.state.activeMission!.clueAt(0), c.state.activeMission!.hints.first);
    });

    test('the next mission escalates from its own first clue', () {
      final c = makeController();
      addTearDown(c.dispose);

      c.selectPlanet('earth');
      c.revealNextHint();

      expect(c.state.missionHintLevel, 1);
      expect(c.state.activeMission!.clueAt(1), c.state.activeMission!.hints[1]);
    });
  });

  group('Mission.hints', () {
    test('copyWith carries the clue list through', () {
      const mission = Mission(
        id: 1,
        title: 'Find Earth',
        description: 'd',
        targetPlanetId: 'earth',
        hints: ['a', 'b'],
      );

      expect(mission.copyWith(completed: true).hints, ['a', 'b']);
    });

    test('defaults to no clues', () {
      const mission = Mission(
        id: 1,
        title: 'Find Earth',
        description: 'd',
        targetPlanetId: 'earth',
      );

      expect(mission.hints, isEmpty);
    });
  });
}
