import 'package:flutter_test/flutter_test.dart';

import 'package:mission/state.dart';

import 'helpers/app_messages.dart';

void main() {
  group('copyWith', () {
    const base = MissionProgressState(
      activeMissionId: 2,
      missionHintLevel: 3,
      celebrationTitle: TestMessages.title,
      celebrationDescription: TestMessages.description,
    );

    test('changing nothing returns an equal state', () {
      expect(base.copyWith(), base);
    });

    test('omitting a field preserves it', () {
      final next = base.copyWith(missionHintLevel: 4);

      expect(next.activeMissionId, 2);
      expect(next.missionHintLevel, 4);
    });

    // The nullable fields use a sentinel precisely so that copyWith can tell
    // "leave this alone" apart from "clear this". A plain `?? this.x` would
    // make the second case impossible.
    test('an explicit null clears the celebration', () {
      final next = base.copyWith(
        celebrationTitle: null,
        celebrationDescription: null,
      );

      expect(next.celebrationTitle, isNull);
      expect(next.celebrationDescription, isNull);
    });

    test('an explicit null clears the active mission', () {
      final next = base.copyWith(activeMissionId: null);

      expect(next.activeMissionId, isNull);
      expect(next.activeMission, isNull);
    });

    test('a nullable field can still be set to a value', () {
      final next = base.copyWith(activeMissionId: 1);

      expect(next.activeMissionId, 1);
    });

    test('a repeated clear is stable', () {
      expect(
        base.copyWith(activeMissionId: null).copyWith(activeMissionId: null),
        base.copyWith(activeMissionId: null),
      );
    });
  });

  group('celebrationVisible', () {
    test('needs both halves of the celebration', () {
      expect(
        const MissionProgressState(celebrationTitle: TestMessages.title)
            .celebrationVisible,
        isFalse,
      );
      expect(
        const MissionProgressState(
          celebrationDescription: TestMessages.description,
        ).celebrationVisible,
        isFalse,
      );
      expect(
        const MissionProgressState(
          celebrationTitle: TestMessages.title,
          celebrationDescription: TestMessages.description,
        ).celebrationVisible,
        isTrue,
      );
    });
  });

  group('activeMission', () {
    const missions = [
      MissionState(
        id: 1,
        title: 'Find Earth',
        description: 'd',
        targetPlanetId: 'earth',
        completed: true,
      ),
      MissionState(
        id: 2,
        title: 'Visit Mars',
        description: 'd',
        targetPlanetId: 'mars',
      ),
    ];

    test('finds the pending mission with the active id', () {
      const state = MissionProgressState(
        missions: missions,
        activeMissionId: 2,
      );

      expect(state.activeMission?.title, 'Visit Mars');
    });

    test('is null when the active mission is already complete', () {
      const state = MissionProgressState(
        missions: missions,
        activeMissionId: 1,
      );

      expect(state.activeMission, isNull);
    });

    test('is null when the id does not match any mission', () {
      const state = MissionProgressState(
        missions: missions,
        activeMissionId: 99,
      );

      expect(state.activeMission, isNull);
    });

    test('is null when every mission is done', () {
      const state = MissionProgressState(
        missions: missions,
        activeMissionId: null,
      );

      expect(state.activeMission, isNull);
    });

    test('is null with no missions at all', () {
      expect(
        const MissionProgressState(activeMissionId: 1).activeMission,
        isNull,
      );
    });

    test('skips a completed mission and finds nothing for a stale pointer', () {
      const state = MissionProgressState(
        missions: [
          MissionState(
            id: 1,
            title: 'Find Earth',
            description: 'd',
            targetPlanetId: 'earth',
            completed: true,
          ),
          MissionState(
            id: 2,
            title: 'Visit Mars',
            description: 'd',
            targetPlanetId: 'mars',
          ),
        ],
        activeMissionId: 1,
      );

      // The pointer is stale, so the companion gets nothing to chase.
      expect(state.activeMission, isNull);
    });
  });

  group('hasPendingMission', () {
    test('is true while anything is left', () {
      const state = MissionProgressState(
        missions: [
          MissionState(
            id: 1,
            title: 'a',
            description: 'd',
            targetPlanetId: 'earth',
            completed: true,
          ),
          MissionState(
            id: 2,
            title: 'b',
            description: 'd',
            targetPlanetId: 'mars',
          ),
        ],
      );

      expect(state.hasPendingMission, isTrue);
    });

    test('is false once everything is done', () {
      const state = MissionProgressState(
        missions: [
          MissionState(
            id: 1,
            title: 'a',
            description: 'd',
            targetPlanetId: 'earth',
            completed: true,
          ),
        ],
      );

      expect(state.hasPendingMission, isFalse);
    });
  });

  group('equality', () {
    test('mission equality only tracks id and completion', () {
      const a = MissionState(
        id: 1,
        title: 'Find Earth',
        description: 'd',
        targetPlanetId: 'earth',
      );
      const b = MissionState(
        id: 1,
        title: 'Something else',
        description: 'other',
        targetPlanetId: 'mars',
      );

      expect(a, b);
      expect(a, isNot(a.copyWith(completed: true)));
    });

    test('a wrong pick bumps the key so the reaction fires again', () {
      const state = MissionProgressState();

      expect(
        state.copyWith(wrongSelectionKey: state.wrongSelectionKey + 1),
        isNot(state),
      );
    });

    test('revealing a clue changes the state', () {
      const state = MissionProgressState();

      expect(state.copyWith(missionHintLevel: 1), isNot(state));
    });
  });

  group('defaults', () {
    test('a fresh progress state starts on the first mission', () {
      const state = MissionProgressState();

      expect(state.activeMissionId, 1);
      expect(state.missionHintLevel, 0);
      expect(state.wrongSelectionKey, 0);
      expect(state.missions, isEmpty);
      expect(state.celebrationVisible, isFalse);
    });
  });
}
