import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:avatar/state.dart';

/// Records saves so selection can be asserted without platform channels.
class _RecordingStore implements AvatarSelectionStore {
  AvatarType? saved;
  int saves = 0;

  @override
  AvatarType? load() => saved;

  @override
  Future<void> save(AvatarType type) async {
    saved = type;
    saves++;
  }
}

void main() {
  group('AvatarType', () {
    test('every type has a stable id and a bundled asset', () {
      for (final type in AvatarType.values) {
        expect(type.id, isNotEmpty);
        expect(type.assetPath, startsWith('assets/models/avatar/'));
        expect(type.assetPath, endsWith('.glb'));
      }
      expect(
        AvatarType.values.map((type) => type.id).toSet(),
        hasLength(AvatarType.values.length),
      );
    });

    test('rocket and astronaut resolve by id', () {
      expect(AvatarType.fromId('rocket'), AvatarType.rocket);
      expect(AvatarType.fromId('astronaut'), AvatarType.astronaut);
    });

    test('unknown and missing ids fall back to the rocket', () {
      // A corrupt preference must never leave the child avatar-less.
      expect(AvatarType.fromId('jetpack'), AvatarType.rocket);
      expect(AvatarType.fromId(null), AvatarType.rocket);
    });
  });

  group('AvatarSelectionController', () {
    test('defaults to the rocket with an empty store', () {
      final controller = AvatarSelectionController(
        store: InMemoryAvatarSelectionStore(),
      );
      addTearDown(controller.dispose);
      expect(controller.state, AvatarType.rocket);
    });

    test('hydrates the saved choice', () async {
      final store = InMemoryAvatarSelectionStore();
      await store.save(AvatarType.astronaut);
      final controller = AvatarSelectionController(store: store);
      addTearDown(controller.dispose);
      expect(controller.state, AvatarType.astronaut);
    });

    test('select updates state and persists', () async {
      final store = _RecordingStore();
      final controller = AvatarSelectionController(store: store);
      addTearDown(controller.dispose);

      await controller.select(AvatarType.astronaut);

      expect(controller.state, AvatarType.astronaut);
      expect(store.saved, AvatarType.astronaut);
      expect(store.saves, 1);

      await controller.select(AvatarType.rocket);

      expect(controller.state, AvatarType.rocket);
      expect(store.saved, AvatarType.rocket);
    });

    test('selecting the current choice writes nothing', () async {
      final store = _RecordingStore();
      final controller = AvatarSelectionController(store: store);
      addTearDown(controller.dispose);

      await controller.select(AvatarType.rocket);

      expect(controller.state, AvatarType.rocket);
      expect(store.saves, 0);
    });
  });

  group('avatarSelectionProvider', () {
    test('defaults to the rocket', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(avatarSelectionProvider), AvatarType.rocket);
    });
  });
}
