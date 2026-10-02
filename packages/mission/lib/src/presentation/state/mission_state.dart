import 'package:equatable/equatable.dart';

import 'package:mission/domain.dart';

/// A mission as the UI sees it: the same fields as [Mission] plus the progress
/// the player has made.
///
/// The mission list is copy and completion, and it changes as the child plays,
/// so it is state rather than a value recomputed from the catalogue. Only
/// [completed] is part of equality because nothing else mutates in place and a
/// widget should not rebuild just because the same mission is re-listed.
class MissionState extends Equatable {
  const MissionState({
    required this.id,
    required this.title,
    required this.description,
    required this.targetPlanetId,
    this.startPoint,
    this.direction,
    this.hints = const [],
    this.completed = false,
  });

  /// Projects a catalogue mission into playable state.
  factory MissionState.fromMission(Mission mission) => MissionState(
    id: mission.id,
    title: mission.title,
    description: mission.description,
    targetPlanetId: mission.targetPlanetId,
    startPoint: mission.startPoint,
    direction: mission.direction,
    hints: mission.hints,
    completed: mission.completed,
  );

  final int id;
  final String title;
  final String description;
  final String targetPlanetId;
  final String? startPoint;
  final String? direction;

  /// Escalating clues, revealed one at a time. See [Mission.hints].
  final List<String> hints;
  final bool completed;

  MissionState copyWith({bool? completed}) => MissionState(
    id: id,
    title: title,
    description: description,
    targetPlanetId: targetPlanetId,
    startPoint: startPoint,
    direction: direction,
    hints: hints,
    completed: completed ?? this.completed,
  );

  /// The clue at [level], clamped to the last one so asking for more clues
  /// past the end repeats the final one rather than throwing.
  String clueAt(int level) {
    if (hints.isEmpty) return description;
    return hints[level.clamp(0, hints.length - 1)];
  }

  @override
  List<Object?> get props => [id, completed];
}
