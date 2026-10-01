import 'package:flutter_test/flutter_test.dart';
import 'package:kidz_planets/application/state/explorer_state.dart';
import 'package:kidz_planets/domain/entities/planet.dart';

import 'helpers/app_messages.dart';

void main() {
  group('copyWith', () {
    const base = ExplorerState(
      selectedPlanetId: 'earth',
      focusedPlanetId: 'earth',
      detailHotspot: HotspotRef(
        planetId: 'saturn',
        hotspot: Hotspot(title: 'Icy Rings', description: 'Ice and rock', icon: '💍'),
      ),
      celebrationTitle: TestMessages.title,
      celebrationDescription: TestMessages.description,
      activeMissionId: 2,
      detailZoom: 1.5,
      missionHintLevel: 3,
    );

    test('changing nothing returns an equal state', () {
      expect(base.copyWith(), base);
    });

    test('omitting a field preserves it', () {
      final next = base.copyWith(detailZoom: 2);

      expect(next.selectedPlanetId, 'earth');
      expect(next.detailHotspot, base.detailHotspot);
      expect(next.activeMissionId, 2);
      expect(next.missionHintLevel, 3);
    });

    // The nullable fields use a sentinel precisely so that copyWith can tell
    // "leave this alone" apart from "clear this". A plain `?? this.x` would
    // make the second case impossible.
    test('an explicit null clears the selection', () {
      final next = base.copyWith(selectedPlanetId: null);

      expect(next.selectedPlanetId, isNull);
      expect(next.focusedPlanetId, 'earth', reason: 'not cleared implicitly');
    });

    test('an explicit null clears the focus', () {
      expect(base.copyWith(focusedPlanetId: null).focusedPlanetId, isNull);
    });

    test('an explicit null clears the hotspot override', () {
      final next = base.copyWith(detailHotspot: null);

      expect(next.detailHotspot, isNull);
    });

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
      final next = base.copyWith(selectedPlanetId: 'mars');

      expect(next.selectedPlanetId, 'mars');
    });

    test('a repeated clear is stable', () {
      expect(
        base.copyWith(selectedPlanetId: null).copyWith(selectedPlanetId: null),
        base.copyWith(selectedPlanetId: null),
      );
    });
  });

  group('hasSelection', () {
    test('follows the selected planet', () {
      expect(const ExplorerState().hasSelection, isFalse);
      expect(const ExplorerState(selectedPlanetId: 'earth').hasSelection, isTrue);
    });

    test('is cleared by an explicit null', () {
      const selected = ExplorerState(selectedPlanetId: 'earth');
      expect(selected.copyWith(selectedPlanetId: null).hasSelection, isFalse);
    });
  });

  group('celebrationVisible', () {
    test('needs both halves of the celebration', () {
      expect(
        const ExplorerState(celebrationTitle: TestMessages.title).celebrationVisible,
        isFalse,
      );
      expect(
        const ExplorerState(celebrationDescription: TestMessages.description).celebrationVisible,
        isFalse,
      );
      expect(
        const ExplorerState(
          celebrationTitle: TestMessages.title,
          celebrationDescription: TestMessages.description,
        ).celebrationVisible,
        isTrue,
      );
    });
  });

  group('activeMission', () {
    const missions = [
      MissionState(id: 1, title: 'Find Earth', description: 'd', targetPlanetId: 'earth', completed: true),
      MissionState(id: 2, title: 'Visit Mars', description: 'd', targetPlanetId: 'mars'),
    ];

    test('finds the pending mission with the active id', () {
      const state = ExplorerState(missions: missions, activeMissionId: 2);

      expect(state.activeMission?.title, 'Visit Mars');
    });

    test('is null when the active mission is already complete', () {
      const state = ExplorerState(missions: missions, activeMissionId: 1);

      expect(state.activeMission, isNull);
    });

    test('is null when the id does not match any mission', () {
      const state = ExplorerState(missions: missions, activeMissionId: 99);

      expect(state.activeMission, isNull);
    });

    test('is null when every mission is done', () {
      const state = ExplorerState(missions: missions, activeMissionId: null);

      expect(state.activeMission, isNull);
    });

    test('is null with no missions at all', () {
      expect(const ExplorerState(activeMissionId: 1).activeMission, isNull);
    });

    test('skips a completed mission and finds the next pending one', () {
      const state = ExplorerState(
        missions: [
          MissionState(id: 1, title: 'Find Earth', description: 'd', targetPlanetId: 'earth', completed: true),
          MissionState(id: 2, title: 'Visit Mars', description: 'd', targetPlanetId: 'mars'),
        ],
        activeMissionId: 1,
      );

      // The pointer is stale, so the companion gets nothing to chase.
      expect(state.activeMission, isNull);
    });
  });

  group('equality', () {
    test('states built the same way are equal', () {
      expect(
        const ExplorerState(detailZoom: 2, showOrbits: false),
        const ExplorerState(detailZoom: 2, showOrbits: false),
      );
    });

    test('differing values are not equal', () {
      expect(
        const ExplorerState(detailZoom: 2),
        isNot(const ExplorerState(detailZoom: 2.5)),
      );
    });

    test('a cleared field differs from a preserved one', () {
      const selected = ExplorerState(selectedPlanetId: 'earth');

      expect(selected, isNot(selected.copyWith(selectedPlanetId: null)));
    });

    test('mission equality only tracks id and completion', () {
      const a = MissionState(id: 1, title: 'Find Earth', description: 'd', targetPlanetId: 'earth');
      const b = MissionState(id: 1, title: 'Something else', description: 'other', targetPlanetId: 'mars');

      expect(a, b);
      expect(a, isNot(a.copyWith(completed: true)));
    });

    test('toast equality tracks key and content', () {
      expect(const ToastMessage(key: 1, message: TestMessages.any),
          const ToastMessage(key: 1, message: TestMessages.any));
      expect(const ToastMessage(key: 1, message: TestMessages.any),
          isNot(const ToastMessage(key: 2, message: TestMessages.any)));
    });

    test('a toast carries either a message or a hotspot, never both', () {
      expect(() => ToastMessage(
            key: 1,
            message: TestMessages.any,
            hotspot: const HotspotRef(
              planetId: 'saturn',
              hotspot: Hotspot(title: 'Icy Rings', description: 'Ice and rock', icon: '💍'),
            ),
          ), throwsAssertionError);
    });
  });

  group('defaults', () {
    test('a fresh state is calm, labelled and orbiting', () {
      const state = ExplorerState();

      expect(state.tab, ExplorerTab.explore);
      expect(state.running, isTrue);
      expect(state.speed, 1.0);
      expect(state.showOrbits, isTrue);
      expect(state.showLabels, isTrue);
      expect(state.selectedPlanetId, isNull);
      expect(state.avatarMood, AvatarMood.searching);
      expect(state.activeMissionId, 1);
      expect(state.detailZoom, 1.0);
    });
  });
}
