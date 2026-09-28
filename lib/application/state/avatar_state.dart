import 'dart:ui' show Offset;

import 'package:equatable/equatable.dart';

/// Where the mission companion sits on screen and which way it faces.
///
/// Deliberately separate from [ExplorerState]: the mission model decides *what*
/// the companion says and does (its expression and animation), while the
/// companion decides *where it is* and *how it is turned*. Keeping the pose
/// here is what lets a child turn the character, move it, and have both
/// survive a mission change, a wrong answer, and a celebration.
class AvatarState extends Equatable {
  const AvatarState({
    this.screenPosition,
    this.yaw = 0.0,
    this.pitch = 0.0,
  });

  /// Top-left corner of the companion box, in logical pixels.
  ///
  /// Null until the overlay has been laid out once, because there is no
  /// meaningful default position before the viewport size is known. The widget
  /// resolves the starting spot from the real constraints and commits it, so
  /// the companion appears in the same place on every screen size.
  final Offset? screenPosition;

  /// Horizontal turn, in radians. Unbounded on purpose: a child is allowed to
  /// spin the character all the way around and keep going.
  final double yaw;

  /// Vertical tilt, in radians, held inside [AvatarState.pitchLimit].
  ///
  /// Tilt is clamped rather than free because a full flip on the vertical axis
  /// makes the character unreadable and looks like a glitch to a child.
  final double pitch;

  /// Clamp applied to [pitch] on every rotation, in radians (about 32°).
  static const double pitchLimit = 0.55;

  double get pitchClamped => pitch.clamp(-pitchLimit, pitchLimit);

  AvatarState copyWith({
    Offset? screenPosition,
    double? yaw,
    double? pitch,
  }) {
    return AvatarState(
      screenPosition: screenPosition ?? this.screenPosition,
      yaw: yaw ?? this.yaw,
      pitch: pitch ?? this.pitch,
    );
  }

  @override
  List<Object?> get props => [screenPosition, yaw, pitch];
}
