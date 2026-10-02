import 'dart:ui' show Offset;

import 'package:equatable/equatable.dart';

enum AvatarIdleAction { none, dancing, thinking, sitting, flying, sendingHeart }

enum FlightStyle { edge, zigzag, circle }

/// Short-lived reactions triggered by direct touch or exploration events.
///
/// Deliberately separate from `AvatarMood` (see `explorer_state.dart`):
/// reactions describe the avatar's visible expression, while moods describe
/// what the mission is asking the companion to communicate.
enum AvatarReaction {
  none,
  happy,
  surprised,
  sad,
  dizzy,
  excited,
  sleepy,
  laughing,
  talking,
  confused,
}

/// Where the mission companion sits on screen and which way it faces.
class AvatarState extends Equatable {
  const AvatarState({
    this.screenPosition,
    this.velocity = Offset.zero,
    this.yaw = 0.0,
    this.pitch = 0.0,
    this.idleAction = AvatarIdleAction.none,
    this.isHeartVisible = false,
    this.isFlightPaused = false,
    this.flightStyle = FlightStyle.circle,
    this.flightTime = 0.0,
    this.reaction = AvatarReaction.none,
    this.reactionUntil = 0,
  });

  /// Top-left corner of the companion box, in logical pixels.
  final Offset? screenPosition;

  /// Current throw / momentum velocity in logical pixels per second.
  final Offset velocity;

  final double yaw;
  final double pitch;
  final AvatarIdleAction idleAction;
  final bool isHeartVisible;

  /// True while the companion hovers exactly where the child let it go.
  ///
  /// A drag is a child choosing where the toy lives, so the automatic flight
  /// loop stands down for a while instead of sliding the companion back into
  /// its own path. The controller ends the pause on a timer and eases flight
  /// back in from the parked spot.
  final bool isFlightPaused;

  final FlightStyle flightStyle;
  final double flightTime;
  final AvatarReaction reaction;
  final int reactionUntil;

  /// True while the toy is carrying momentum from a throw.
  bool get isThrowing => velocity.distanceSquared > 100.0;

  /// How far the rocket may be tipped forwards or backwards, in radians.
  ///
  /// Wide enough (about 86 degrees) that the nose points straight at the child
  /// and the engine points straight away, so the top and the bottom of the
  /// model are both reachable. It stops just short of a full flip because a
  /// continuous 360 degree tumble has no "right way up" to come back to, which
  /// matters when the child has parked it somewhere.
  static const double pitchLimit = 1.5;

  double get pitchClamped => pitch.clamp(-pitchLimit, pitchLimit);

  AvatarState copyWith({
    Offset? screenPosition,
    Offset? velocity,
    double? yaw,
    double? pitch,
    AvatarIdleAction? idleAction,
    bool? isHeartVisible,
    bool? isFlightPaused,
    FlightStyle? flightStyle,
    double? flightTime,
    AvatarReaction? reaction,
    int? reactionUntil,
  }) {
    return AvatarState(
      screenPosition: screenPosition ?? this.screenPosition,
      velocity: velocity ?? this.velocity,
      yaw: yaw ?? this.yaw,
      pitch: pitch ?? this.pitch,
      idleAction: idleAction ?? this.idleAction,
      isHeartVisible: isHeartVisible ?? this.isHeartVisible,
      isFlightPaused: isFlightPaused ?? this.isFlightPaused,
      flightStyle: flightStyle ?? this.flightStyle,
      flightTime: flightTime ?? this.flightTime,
      reaction: reaction ?? this.reaction,
      reactionUntil: reactionUntil ?? this.reactionUntil,
    );
  }

  @override
  List<Object?> get props => [
    screenPosition,
    velocity,
    yaw,
    pitch,
    idleAction,
    isHeartVisible,
    isFlightPaused,
    flightStyle,
    flightTime,
    reaction,
    reactionUntil,
  ];
}
