import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/l10n.dart';
import 'package:mission/domain.dart';

import '../state/mission_progress_state.dart';
import '../state/mission_state.dart';

/// Owns progress through the mission curriculum.
///
/// Answers one question: given a body id, did the child just finish a mission?
/// Everything else about a tap belongs to someone else. Playing the success
/// cue, the haptic bump and the companion's expression are the caller's job,
/// which is why [evaluateSelection] returns a [MissionOutcome] instead of
/// performing the celebration itself.
class MissionProgressController extends StateNotifier<MissionProgressState> {
  MissionProgressController(List<Mission> initialMissions)
    : super(
        MissionProgressState(
          missions: initialMissions.map(MissionState.fromMission).toList(),
        ),
      );

  /// Grades a tap against the active mission and advances the curriculum.
  ///
  /// A miss is recorded as a bump to [MissionProgressState.wrongSelectionKey]
  /// and nothing else: a wrong pick is answered by the companion alone, with no
  /// dialog, no hint overlay, no toast, no failure sound and no narration,
  /// because the avatar reacting in place already says it and a child should
  /// not be interrupted by four things at once. The hint level deliberately does
  /// not advance, so there is no escalated clue to read out.
  MissionOutcome evaluateSelection(String planetId) {
    final activeId = state.activeMissionId;
    if (activeId == null) return MissionOutcome.ignored;

    final idx = state.missions.indexWhere(
      (m) => m.id == activeId && !m.completed,
    );
    if (idx < 0) return MissionOutcome.ignored;

    final mission = state.missions[idx];
    if (mission.targetPlanetId != planetId) {
      state = state.copyWith(wrongSelectionKey: state.wrongSelectionKey + 1);
      return MissionOutcome.miss;
    }

    final updated = List<MissionState>.from(state.missions);
    updated[idx] = mission.copyWith(completed: true);

    final nextIndex = updated.indexWhere((m) => !m.completed);
    state = state.copyWith(
      missions: updated,
      activeMissionId: nextIndex < 0 ? null : updated[nextIndex].id,
      // Clues given away for the finished mission do not carry over: the next
      // mission starts from its own first clue.
      missionHintLevel: 0,
      celebrationTitle: _celebrationTitleFor(mission.id),
      celebrationDescription: _celebrationBodyFor(planetId),
    );
    return MissionOutcome.complete;
  }

  /// Marks the first uncompleted mission for [planetId] as done.
  ///
  /// The sandbox path, where a child can finish a mission for any body rather
  /// than only the active target. It deliberately leaves [activeMissionId] and
  /// the hint level alone: the child did not tap the thing the mission was
  /// asking for, so the curriculum does not move on.
  bool completeFirstPendingFor(String planetId) {
    final idx = state.missions.indexWhere(
      (m) => m.targetPlanetId == planetId && !m.completed,
    );
    if (idx < 0) return false;

    final updated = List<MissionState>.from(state.missions);
    updated[idx] = updated[idx].copyWith(completed: true);
    state = state.copyWith(
      missions: updated,
      celebrationTitle: _celebrationTitleFor(updated[idx].id),
      celebrationDescription: _celebrationBodyFor(planetId),
    );
    return true;
  }

  /// Reveals the next, blunter clue for the active mission.
  ///
  /// Deliberately child-initiated, and saturates at the last clue so asking
  /// past the end repeats the final one instead of throwing.
  void revealNextHint() {
    final mission = state.activeMission;
    if (mission == null) return;
    final last = mission.hints.length - 1;
    if (state.missionHintLevel >= last) return;
    state = state.copyWith(missionHintLevel: state.missionHintLevel + 1);
  }

  void showCelebration(AppMessage title, AppMessage description) {
    state = state.copyWith(
      celebrationTitle: title,
      celebrationDescription: description,
    );
  }

  void closeCelebration() {
    state = state.copyWith(
      celebrationTitle: null,
      celebrationDescription: null,
    );
  }

  static AppMessage _celebrationTitleFor(int missionId) =>
      AppMessage(AppMessageId.celebrationMissionTitle, {'id': missionId});

  /// The planet id, not its name: the name is catalogue copy and this package
  /// has no locale, so the view resolves it.
  static AppMessage _celebrationBodyFor(String planetId) =>
      AppMessage(AppMessageId.celebrationDiscovered, {'planetId': planetId});
}
