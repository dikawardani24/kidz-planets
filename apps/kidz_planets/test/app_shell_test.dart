import 'package:flutter_test/flutter_test.dart';

import 'package:avatar/state.dart';
import 'package:core/l10n.dart';
import 'package:core/time.dart';
import 'package:kidz_planets/application/state/app_shell_controller.dart';
import 'package:mission/data.dart';
import 'package:mission/state.dart';
import 'package:planets/state.dart';

import 'helpers/app_messages.dart';

/// A wrong pick is the companion's job alone.
///
/// The user asked for no dialog, no hint overlay, no toast, no failure sound,
/// and no mission narration, because the avatar reacting in place already
/// covers it. These tests pin all five down, because each one is a behaviour
/// that used to exist and would otherwise be quietly reintroduced.
///
/// The wiring under test is the composition itself: a tap lands in the planets
/// controller, the shell reads the new selection, and the shell decides what it
/// means for the mission feature and the companion. Every platform effect is
/// captured rather than performed, so the whole chain runs in a unit test.
void main() {
  late ExplorerController explorer;
  late MissionProgressController missions;
  late AppShellController shell;
  late List<String> effects;

  setUp(() {
    effects = [];
    explorer = ExplorerController(clock: SimulationClock());
    missions = MissionProgressController(MissionCatalog.missions);
    shell = AppShellController(
      missions: missions,
      showToast: explorer.showToast,
      closeDetail: explorer.closeDetail,
      startSuccessCue: () => effects.add('cue:start'),
      stopSuccessCue: () => effects.add('cue:stop'),
      playPlanetSound: (_) {},
      lightHaptic: () => effects.add('haptic:light'),
      mediumHaptic: () => effects.add('haptic:medium'),
    );
    addTearDown(() {
      shell.dispose();
      explorer.dispose();
    });
  });

  /// A tap on [planetId], exactly as the screen produces it: the explorer
  /// records the selection, then the shell is told about it.
  void tap(String planetId) {
    explorer.selectPlanet(planetId);
    shell.handlePlanetSelected(planetId);
  }

  /// A planet that is not the active mission's target.
  String aWrongPlanet({String? not}) {
    const candidates = ['saturn', 'venus', 'neptune', 'earth', 'mars'];
    final target = missions.state.activeMission!.targetPlanetId;
    for (final id in candidates) {
      if (id != target && id != not) return id;
    }
    return target;
  }

  group('a wrong pick is handled by the avatar alone', () {
    test('the avatar reacts', () {
      tap(aWrongPlanet());
      expect(shell.state.avatarMood, AvatarMood.wrong);
    });

    test('a wrong pick does not move the mission along', () {
      // The mission guide pill is the only way into the mission text, and it
      // follows the active mission. A miss must leave the child on the same
      // mission, so nothing reopens the text over the companion.
      final activeBefore = missions.state.activeMissionId;
      tap(aWrongPlanet());
      expect(missions.state.activeMissionId, activeBefore);
      expect(missions.state.activeMission!.completed, isFalse);
    });

    test('no hint is escalated, so there is nothing new to read out', () {
      final levelBefore = missions.state.missionHintLevel;
      tap(aWrongPlanet());
      expect(missions.state.missionHintLevel, levelBefore);
    });

    test('no toast interrupts the child', () {
      tap(aWrongPlanet());
      expect(explorer.state.toasts, isEmpty);
    });

    test('no celebration is shown either', () {
      tap(aWrongPlanet());
      expect(missions.state.celebrationVisible, isFalse);
    });

    test('no success cue and no medium haptic for a miss', () {
      tap(aWrongPlanet());

      // A miss is answered by the face and a light tap. Anything heavier would
      // startle the child, and the cue belongs to a win.
      expect(effects, ['haptic:light']);
    });
  });

  group('the right pick is a win', () {
    test(
      'the mission completes, the cue loops and the companion celebrates',
      () {
        tap('earth');

        expect(missions.state.missions.first.completed, isTrue);
        expect(missions.state.activeMissionId, 2);
        expect(shell.state.avatarMood, AvatarMood.success);
        expect(missions.state.celebrationVisible, isTrue);
        expect(effects, containsAll(['cue:start', 'haptic:medium']));
      },
    );

    test('a toast announces the mission that was just finished', () {
      tap('earth');

      expect(
        explorer.state.toasts.single.message!.id,
        AppMessageId.toastMissionComplete,
      );
      expect(
        explorer.state.toasts.single.message!.args['title'],
        'Find Planet Earth',
      );
    });

    test('the cue stops only when the dialog is dismissed', () {
      tap('earth');
      expect(effects, isNot(contains('cue:stop')));

      shell.closeCelebration();

      expect(effects, contains('cue:stop'));
      expect(missions.state.celebrationVisible, isFalse);
    });
  });

  group('the avatar recovers on its own', () {
    test('dismissing a celebration calms it back down', () {
      tap('earth');
      expect(missions.state.celebrationVisible, isTrue);

      shell.closeCelebration();

      expect(missions.state.celebrationVisible, isFalse);
      expect(shell.state.avatarMood, AvatarMood.instruction);
    });

    test('settles back to searching once every mission is done', () {
      for (final mission in MissionCatalog.missions) {
        tap(mission.targetPlanetId);
      }
      shell.closeCelebration();

      expect(missions.state.missions.every((m) => m.completed), isTrue);
      expect(missions.state.activeMissionId, isNull);
      expect(shell.state.avatarMood, AvatarMood.searching);
    });

    test('tapping after a miss moves it to the encouraging line', () {
      tap(aWrongPlanet());
      expect(shell.state.avatarMood, AvatarMood.wrong);

      shell.retryMission();
      expect(shell.state.avatarMood, AvatarMood.retry);
    });

    test('retry does nothing outside a miss, so it cannot skip a win', () {
      expect(shell.state.avatarMood, AvatarMood.searching);
      shell.retryMission();
      expect(shell.state.avatarMood, AvatarMood.searching);
    });

    test('a second miss returns it to disappointed', () {
      final first = aWrongPlanet();
      tap(first);
      shell.retryMission();
      expect(shell.state.avatarMood, AvatarMood.retry);

      // A different planet, because re-tapping the same one only closes the
      // detail view and never reaches the mission check.
      tap(aWrongPlanet(not: first));
      expect(shell.state.avatarMood, AvatarMood.wrong);
    });

    test('a celebration is never interrupted by a mood change', () {
      tap('earth');
      expect(shell.state.avatarMood, AvatarMood.success);

      shell.setAvatarMood(AvatarMood.instruction);

      expect(shell.state.avatarMood, AvatarMood.success);
    });

    test('a manual celebration can be dismissed again', () {
      missions.showCelebration(TestMessages.title, TestMessages.description);
      expect(missions.state.celebrationVisible, isTrue);

      shell.closeCelebration();

      expect(missions.state.celebrationVisible, isFalse);
    });
  });

  group('the sandbox path', () {
    test(
      'finishing a mission out of band toasts without moving the pointer',
      () {
        shell.completeFirstPendingFor('earth');

        expect(missions.state.missions.first.completed, isTrue);
        expect(
          missions.state.activeMissionId,
          1,
          reason:
              'the child did not find the mission target, so the '
              'curriculum does not advance',
        );
        expect(
          explorer.state.toasts.single.message!.id,
          AppMessageId.toastMissionVerified,
        );
      },
    );

    test('a body with no mission is silent', () {
      shell.completeFirstPendingFor('venus');

      expect(explorer.state.toasts, isEmpty);
      expect(missions.state.celebrationVisible, isFalse);
    });
  });

  group('the tab strip', () {
    test('leaving explore closes the detail view', () {
      tap('mars');
      expect(explorer.state.selectedPlanetId, 'mars');

      shell.setTab(AppTab.missions);

      expect(explorer.state.selectedPlanetId, isNull);
      expect(explorer.state.focusedPlanetId, isNull);
    });

    test('returning to explore does not re-open the detail view', () {
      tap('mars');
      shell.setTab(AppTab.missions);
      expect(explorer.state.focusedPlanetId, isNull);

      shell.setTab(AppTab.explore);

      expect(shell.state.tab, AppTab.explore);
      expect(
        explorer.state.selectedPlanetId,
        isNull,
        reason: 'the sheet stays shut until the child taps a body again',
      );
    });
  });
}
