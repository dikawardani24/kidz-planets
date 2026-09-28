import 'dart:ui' show Offset;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/avatar_state.dart';

/// Owns the companion's pose and place on screen (SRP: one narrow surface for
/// avatar interaction).
///
/// Position and rotation live here rather than in the mission state on
/// purpose. A mission only decides the companion's expression and animation;
/// this controller decides where the child parked it and which way it is
/// turned. That separation is what makes "move" and "rotate" independent
/// gestures, and it is why neither is reset when the mission changes, a wrong
/// answer comes back, or a celebration starts.
class AvatarController extends StateNotifier<AvatarState> {
  AvatarController() : super(const AvatarState());

  /// Rotates the companion by a drag delta in pixels.
  ///
  /// Yaw accumulates freely so a child can spin it the full 360° and keep
  /// going. Pitch is clamped, because a full vertical flip makes the character
  /// unreadable rather than playful. This never touches [AvatarState
  /// .screenPosition]: turning is not moving.
  void rotateBy({required double dx, required double dy}) {
    const yawPerPixel = 0.012;
    const pitchPerPixel = 0.008;
    state = state.copyWith(
      yaw: state.yaw + dx * yawPerPixel,
      pitch: (state.pitch + dy * pitchPerPixel)
          .clamp(-AvatarState.pitchLimit, AvatarState.pitchLimit),
    );
  }

  /// Moves the companion by a drag delta in pixels, kept inside the viewport.
  ///
  /// Clamping to [maxPosition] is what stops the child pushing the companion
  /// off screen, where they could not grab it again to bring it back. It also
  /// never touches yaw or pitch: moving is not turning.
  void moveBy({
    required Offset delta,
    required Offset maxPosition,
  }) {
    final current = state.screenPosition;
    if (current == null) return;
    state = state.copyWith(
      screenPosition: Offset(
        (current.dx + delta.dx).clamp(0.0, maxPosition.dx),
        (current.dy + delta.dy).clamp(0.0, maxPosition.dy),
      ),
    );
  }

  /// Commits the starting spot, computed once the real viewport is known.
  void placeAt(Offset position) {
    state = state.copyWith(screenPosition: position);
  }

  /// Returns the companion to its starting spot without touching its rotation,
  /// so a "put it back" action does not also undo how the child turned it.
  void resetPositionTo(Offset position) => placeAt(position);
}

final avatarControllerProvider =
    StateNotifierProvider<AvatarController, AvatarState>(
  (ref) => AvatarController(),
);
