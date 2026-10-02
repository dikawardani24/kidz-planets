import 'package:equatable/equatable.dart';

import 'package:core/l10n.dart';

import 'mission_state.dart';

/// How far the child has got through the curriculum, and whether a celebration
/// is on screen.
///
/// The mission feature owns this. It never learns what a planet looks like: a
/// mission names its target by id, so deciding whether a tap was correct is a
/// string comparison and nothing more.
class MissionProgressState extends Equatable {
  const MissionProgressState({
    this.missions = const [],
    this.activeMissionId = 1,
    this.missionHintLevel = 0,
    this.wrongSelectionKey = 0,
    this.celebrationTitle,
    this.celebrationDescription,
  });

  final List<MissionState> missions;
  final int? activeMissionId;

  /// How many extra clues the child has asked for on [activeMissionId].
  /// Reset to zero whenever the active mission moves on.
  final int missionHintLevel;

  /// Bumped on every miss so the companion's failure reaction fires again for
  /// a repeated wrong pick instead of only playing once.
  final int wrongSelectionKey;

  /// Non-null while the success dialog is up. Both halves are set and cleared
  /// together.
  final AppMessage? celebrationTitle;
  final AppMessage? celebrationDescription;

  /// The active mission, or null once every mission is complete. The guide
  /// needs the target to render what the child is hunting for, and that must
  /// come from the current mission rather than being hardcoded.
  MissionState? get activeMission {
    final id = activeMissionId;
    if (id == null) return null;
    for (final mission in missions) {
      if (mission.id == id && !mission.completed) return mission;
    }
    return null;
  }

  bool get celebrationVisible =>
      celebrationTitle != null && celebrationDescription != null;

  bool get hasPendingMission => missions.any((m) => !m.completed);

  MissionProgressState copyWith({
    List<MissionState>? missions,
    Object? activeMissionId = _sentinel,
    int? missionHintLevel,
    int? wrongSelectionKey,
    Object? celebrationTitle = _sentinel,
    Object? celebrationDescription = _sentinel,
  }) {
    return MissionProgressState(
      missions: missions ?? this.missions,
      activeMissionId: identical(activeMissionId, _sentinel)
          ? this.activeMissionId
          : activeMissionId as int?,
      missionHintLevel: missionHintLevel ?? this.missionHintLevel,
      wrongSelectionKey: wrongSelectionKey ?? this.wrongSelectionKey,
      celebrationTitle: identical(celebrationTitle, _sentinel)
          ? this.celebrationTitle
          : celebrationTitle as AppMessage?,
      celebrationDescription: identical(celebrationDescription, _sentinel)
          ? this.celebrationDescription
          : celebrationDescription as AppMessage?,
    );
  }

  @override
  List<Object?> get props => [
    missions,
    activeMissionId,
    missionHintLevel,
    wrongSelectionKey,
    celebrationTitle,
    celebrationDescription,
  ];
}

const _sentinel = Object();

/// What answering a tap with the active mission produced.
///
/// Returned instead of being acted on directly, so the caller can play sound
/// and drive haptics. Those belong to the shell and to the platform, and a
/// mission has no business reaching either.
enum MissionOutcome {
  /// The tap did not target the active mission.
  miss,

  /// The active mission's target was tapped.
  complete,

  /// Nothing was active, or the target had already been completed.
  ignored,
}
