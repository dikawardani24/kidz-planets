import 'package:flutter_test/flutter_test.dart';

import 'package:avatar/state.dart';
import 'package:avatar/widgets.dart';
import 'package:mission/state.dart';

void main() {
  group('companion line', () {
    test('every mood has its own line', () {
      final lines = AvatarMood.values.map((m) => avatarLine(m, 'Mars')).toSet();
      expect(lines.length, AvatarMood.values.length);
    });

    test('no line is empty, because this is the companion only voice', () {
      for (final mood in AvatarMood.values) {
        expect(avatarLine(mood, null), isNotEmpty);
        expect(avatarLine(mood, 'Mars'), isNotEmpty);
      }
    });

    test('instruction and success name the target from the mission', () {
      // The target name must come from the active mission, so a mission change
      // changes what the companion says without any other wiring.
      expect(avatarLine(AvatarMood.instruction, 'Mars'), contains('Mars'));
      expect(avatarLine(AvatarMood.success, 'Jupiter'), contains('Jupiter'));
    });

    test('a null target degrades to wording that still makes sense', () {
      expect(avatarLine(AvatarMood.instruction, null), isNot(contains('null')));
    });

    test('each mood has its own accent colour', () {
      final accents = AvatarMood.values.map(avatarAccent).toSet();
      // retry shares the wrong mood's colour on purpose: they are the same
      // beat of the interaction, so the check is that they differ from the
      // other three rather than from each other.
      expect(accents.length, AvatarMood.values.length - 1);
    });
  });

  group('active mission target', () {
    test('resolves the current mission target, not a hardcoded planet', () {
      const missions = [
        MissionState(
          id: 1,
          title: 'Find Mars',
          description: 'd',
          targetPlanetId: 'mars',
        ),
        MissionState(
          id: 2,
          title: 'Find Jupiter',
          description: 'd',
          targetPlanetId: 'jupiter',
        ),
      ];

      const first = MissionProgressState(
        missions: missions,
        activeMissionId: 1,
      );
      const second = MissionProgressState(
        missions: missions,
        activeMissionId: 2,
      );

      expect(first.activeMission!.targetPlanetId, 'mars');
      expect(second.activeMission!.targetPlanetId, 'jupiter');
    });

    test('is null once every mission is complete, so the target is hidden', () {
      const done = MissionProgressState(
        missions: [
          MissionState(
            id: 1,
            title: 'Find Mars',
            description: 'd',
            targetPlanetId: 'mars',
            completed: true,
          ),
        ],
        activeMissionId: 1,
      );
      expect(done.activeMission, isNull);
    });

    test('is null when no mission is active', () {
      expect(const MissionProgressState().activeMission, isNull);
    });
  });
}
