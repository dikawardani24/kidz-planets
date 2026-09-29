import 'dart:ui' show Offset;

import 'package:equatable/equatable.dart';

enum AvatarIdleAction {
  none,
  dancing,
  thinking,
  sitting,
  flying,
  sendingHeart,
}

enum FlightStyle { edge, zigzag, circle }

/// Short-lived reactions triggered by direct touch or exploration events.
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
}

/// Where the mission companion sits on screen and which way it faces.
class AvatarState extends Equatable {
  const AvatarState({
    this.screenPosition,
    this.yaw = 0.0,
    this.pitch = 0.0,
    this.idleAction = AvatarIdleAction.none,
    this.isHeartVisible = false,
    this.flightStyle = FlightStyle.circle,
    this.flightTime = 0.0,
    this.reaction = AvatarReaction.none,
    this.reactionUntil = 0,
  });

  /// Top-left corner of the companion box, in logical pixels.
  final Offset? screenPosition;

  final double yaw;
  final double pitch;
  final AvatarIdleAction idleAction;
  final bool isHeartVisible;
  final FlightStyle flightStyle;
  final double flightTime;
  final AvatarReaction reaction;
  final int reactionUntil;

  static const double pitchLimit = 0.55;

  double get pitchClamped => pitch.clamp(-pitchLimit, pitchLimit);

  AvatarState copyWith({
    Offset? screenPosition,
    double? yaw,
    double? pitch,
    AvatarIdleAction? idleAction,
    bool? isHeartVisible,
    FlightStyle? flightStyle,
    double? flightTime,
    AvatarReaction? reaction,
    int? reactionUntil,
  }) {
    return AvatarState(
      screenPosition: screenPosition ?? this.screenPosition,
      yaw: yaw ?? this.yaw,
      pitch: pitch ?? this.pitch,
      idleAction: idleAction ?? this.idleAction,
      isHeartVisible: isHeartVisible ?? this.isHeartVisible,
      flightStyle: flightStyle ?? this.flightStyle,
      flightTime: flightTime ?? this.flightTime,
      reaction: reaction ?? this.reaction,
      reactionUntil: reactionUntil ?? this.reactionUntil,
    );
  }

  @override
  List<Object?> get props => [
        screenPosition,
        yaw,
        pitch,
        idleAction,
        isHeartVisible,
        flightStyle,
        flightTime,
        reaction,
        reactionUntil,
      ];
}
