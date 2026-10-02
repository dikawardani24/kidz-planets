import 'package:flutter_test/flutter_test.dart';

import 'package:planets/domain.dart';
import 'package:planets/state.dart';

import 'helpers/app_messages.dart';

void main() {
  group('copyWith', () {
    const base = ExplorerState(
      selectedPlanetId: 'earth',
      focusedPlanetId: 'earth',
      detailZoom: 1.5,
      detailHotspot: HotspotRef(
        planetId: 'saturn',
        hotspot: Hotspot(
          title: 'Icy Rings',
          description: 'Ice and rock',
          icon: '💍',
        ),
      ),
    );

    test('changing nothing returns an equal state', () {
      expect(base.copyWith(), base);
    });

    test('omitting a field preserves it', () {
      final next = base.copyWith(detailZoom: 2);

      expect(next.selectedPlanetId, 'earth');
      expect(next.detailHotspot, base.detailHotspot);
      expect(next.detailZoom, 2);
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
      expect(
        const ExplorerState(selectedPlanetId: 'earth').hasSelection,
        isTrue,
      );
    });

    test('is cleared by an explicit null', () {
      const selected = ExplorerState(selectedPlanetId: 'earth');
      expect(selected.copyWith(selectedPlanetId: null).hasSelection, isFalse);
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

    test('toast equality tracks key and content', () {
      expect(
        const ToastMessage(key: 1, message: TestMessages.any),
        const ToastMessage(key: 1, message: TestMessages.any),
      );
      expect(
        const ToastMessage(key: 1, message: TestMessages.any),
        isNot(const ToastMessage(key: 2, message: TestMessages.any)),
      );
    });

    test('a toast carries either a message or a hotspot, never both', () {
      expect(
        () => ToastMessage(
          key: 1,
          message: TestMessages.any,
          hotspot: const HotspotRef(
            planetId: 'saturn',
            hotspot: Hotspot(
              title: 'Icy Rings',
              description: 'Ice and rock',
              icon: '💍',
            ),
          ),
        ),
        throwsAssertionError,
      );
    });
  });

  group('defaults', () {
    test('a fresh state is calm, labelled and orbiting', () {
      const state = ExplorerState();

      expect(state.running, isTrue);
      expect(state.speed, 1.0);
      expect(state.showOrbits, isTrue);
      expect(state.showLabels, isTrue);
      expect(state.selectedPlanetId, isNull);
      expect(state.detailZoom, 1.0);
      expect(state.spinHintVisible, isFalse);
      expect(state.toasts, isEmpty);
    });
  });
}
