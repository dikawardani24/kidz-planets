import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'avatar_type.dart';

/// Where the chosen avatar is remembered across restarts.
///
/// The feature package owns the selection state but not the platform: tests
/// and standalone hosts use the in-memory default, while the app overrides
/// the provider with a controller built on a persisted store.
abstract class AvatarSelectionStore {
  /// The last saved choice, or null when nothing was ever chosen.
  AvatarType? load();

  /// Remembers [type] as the choice to restore next launch.
  Future<void> save(AvatarType type);
}

/// A store that forgets on process death.
///
/// The provider default, so widget tests and feature previews stay hermetic:
/// no platform channels, no async hydration gap, and every test starts on
/// the rocket.
class InMemoryAvatarSelectionStore implements AvatarSelectionStore {
  AvatarType? _saved;

  @override
  AvatarType? load() => _saved;

  @override
  Future<void> save(AvatarType type) async {
    _saved = type;
  }
}

/// The child's chosen companion body.
///
/// A single value rather than part of [AvatarState] on purpose: the pose is
/// per-screen and ephemeral (Explore flies it, the Avatar page rotates it),
/// while the choice is app-wide and persisted. Sharing one pose across both
/// screens would let the preview's drag spin the Explorer's toy.
class AvatarSelectionController extends StateNotifier<AvatarType> {
  AvatarSelectionController({required AvatarSelectionStore store})
    : _store = store,
      super(store.load() ?? AvatarType.rocket);

  final AvatarSelectionStore _store;

  /// Chooses [type] everywhere at once: every watcher (the Explorer
  /// companion, the Avatar page preview) swaps to it on the same state
  /// change, so no restart is needed for the choice to take effect.
  Future<void> select(AvatarType type) async {
    if (type == state) return;
    state = type;
    await _store.save(type);
  }
}

/// The chosen companion body, defaulting to the rocket.
final avatarSelectionProvider =
    StateNotifierProvider<AvatarSelectionController, AvatarType>(
      (ref) => AvatarSelectionController(store: InMemoryAvatarSelectionStore()),
    );
